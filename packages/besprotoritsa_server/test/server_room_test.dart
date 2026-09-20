import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late HttpServer server;
  late GameRoom room;

  setUp(() async {
    final manager = RoomManager();
    room = manager.createRoom(state: _twoHeroState(), started: true);
    server = await shelf_io.serve(
      manager.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
  });

  tearDown(() => server.close(force: true));

  test('reports readiness at GET /healthz', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(
      Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        path: '/healthz',
      ),
    );
    final response = await request.close();

    expect(response.statusCode, HttpStatus.ok);
    expect(await response.transform(utf8.decoder).join(), 'ok\n');
  });

  test(
    'projects each WebSocket state with the other hero cards hidden',
    () async {
      final ada = await _connect(server, room.code, 'ada-participant');
      addTearDown(ada.sink.close);
      final adaInbox = _Inbox(ada);
      addTearDown(adaInbox.close);
      final adaJoined = await adaInbox.next();
      final adaState = await adaInbox.next();

      final boris = await _connect(server, room.code, 'boris-participant');
      addTearDown(boris.sink.close);
      final borisInbox = _Inbox(boris);
      addTearDown(borisInbox.close);
      final borisJoined = await borisInbox.next();
      final borisState = await borisInbox.next();

      expect(room.code, matches(RegExp(r'^[A-Z]{5}$')));
      expect(adaJoined['heroId'], 'ada');
      expect(borisJoined['heroId'], 'boris');
      _expectPrivateCards(
        adaState,
        ownerId: 'ada',
        ownerCard: 'ada-private-card',
        hiddenId: 'boris',
        hiddenCard: 'boris-secret-card',
      );
      _expectPrivateCards(
        borisState,
        ownerId: 'boris',
        ownerCard: 'boris-secret-card',
        hiddenId: 'ada',
        hiddenCard: 'ada-private-card',
      );

      ada.sink.add(
        jsonEncode({
          'type': 'command',
          'commandId': 'heal-ada-1',
          'expectedRevision': 0,
          'command': {'type': 'heal', 'amount': 1},
        }),
      );
      final adaUpdated = await adaInbox.next();
      final borisUpdated = await borisInbox.next();
      expect(adaUpdated['revision'], 1);
      expect(borisUpdated['revision'], 1);
      expect(room.revision, 1);

      // The same id is an idempotent retry: it neither steps rules nor
      // broadcasts.
      ada.sink.add(
        jsonEncode({
          'type': 'command',
          'commandId': 'heal-ada-1',
          'expectedRevision': 1,
          'command': {'type': 'heal', 'amount': 1},
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(room.revision, 1);
    },
  );

  test('never sends the seed, private log, or another hero decision', () async {
    final ada = await _connect(server, room.code, 'ada-participant');
    addTearDown(ada.sink.close);
    final adaInbox = _Inbox(ada);
    addTearDown(adaInbox.close);
    await adaInbox.next();
    await adaInbox.next();

    final boris = await _connect(server, room.code, 'boris-participant');
    addTearDown(boris.sink.close);
    final borisInbox = _Inbox(boris);
    addTearDown(borisInbox.close);
    await borisInbox.next();
    await borisInbox.next();

    ada.sink.add(
      jsonEncode({
        'type': 'command',
        'commandId': 'ada-private-roll',
        'expectedRevision': 0,
        'command': {'type': 'skillCheck', 'stat': 'science'},
      }),
    );
    final adaState = await adaInbox.next();
    final borisState = await borisInbox.next();
    final adaProjection = Map<String, Object?>.from(adaState['state']! as Map);
    final borisProjection = Map<String, Object?>.from(
      borisState['state']! as Map,
    );

    expect(adaProjection.containsKey('seed'), isFalse);
    expect(adaProjection['log'], isEmpty);
    expect(
      Map<String, Object?>.from(
        adaProjection['pendingDecision']! as Map,
      )['type'],
      'reroll',
    );
    expect(
      Map<String, Object?>.from(
        borisProjection['pendingDecision']! as Map,
      )['type'],
      'hidden',
    );
  });
}

Future<IOWebSocketChannel> _connect(
  HttpServer server,
  String roomCode,
  String participantId,
) async {
  final channel = IOWebSocketChannel.connect(
    Uri(
      scheme: 'ws',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/rooms/$roomCode/ws',
      queryParameters: {'participantId': participantId},
    ),
  );
  await channel.ready;
  return channel;
}

final class _Inbox {
  _Inbox(IOWebSocketChannel channel) {
    _subscription = channel.stream.listen((Object? message) {
      final parsed = Map<String, Object?>.from(
        jsonDecode(message! as String) as Map,
      );
      final waiting = _waiting;
      if (waiting != null) {
        _waiting = null;
        waiting.complete(parsed);
      } else {
        _messages.add(parsed);
      }
    });
  }

  final List<Map<String, Object?>> _messages = <Map<String, Object?>>[];
  late final StreamSubscription<Object?> _subscription;
  Completer<Map<String, Object?>>? _waiting;

  Future<Map<String, Object?>> next() {
    if (_messages.isNotEmpty) {
      return Future<Map<String, Object?>>.value(_messages.removeAt(0));
    }
    final waiting = Completer<Map<String, Object?>>();
    _waiting = waiting;
    return waiting.future.timeout(const Duration(seconds: 2));
  }

  Future<void> close() => _subscription.cancel();
}

void _expectPrivateCards(
  Map<String, Object?> envelope, {
  required String ownerId,
  required String ownerCard,
  required String hiddenId,
  required String hiddenCard,
}) {
  expect(envelope['type'], 'state');
  final state = Map<String, Object?>.from(envelope['state']! as Map);
  final players = (state['players']! as List<Object?>)
      .map((player) => Map<String, Object?>.from(player! as Map))
      .toList();
  final owner = players.singleWhere((player) => player['id'] == ownerId);
  final hidden = players.singleWhere((player) => player['id'] == hiddenId);

  expect(owner['backpack'], [ownerCard]);
  expect(hidden['backpack'], isEmpty);
  expect(hidden['conditions'], isEmpty);
  expect(hidden['hiddenCardCount'], 2);
  expect(jsonEncode(envelope), isNot(contains(hiddenCard)));
}

GameState _twoHeroState() => GameState(
  seed: 8,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    HexTile(
      id: 'anabiosis',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const {},
      hasTerminal: false,
      ventColor: VentColor.none,
    ),
  ],
  players: [
    _player('ada', damage: 1, card: 'ada-private-card'),
    _player('boris', card: 'boris-secret-card'),
  ],
  monsters: const [],
  decks: const {},
  quests: QuestState(),
);

PlayerState _player(String id, {required String card, int damage = 0}) =>
    PlayerState(
      id: id,
      characterId: '$id-hero',
      coord: const HexCoord(0, 0),
      damage: damage,
      credits: 0,
      backpack: [card],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const ['private-condition'],
      alive: true,
    );
