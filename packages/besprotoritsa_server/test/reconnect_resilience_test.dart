import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  test('restores a persisted room and protects reconnect identities', () async {
    final directory = await Directory.systemTemp.createTemp('besprotoritsa-');
    addTearDown(() => directory.delete(recursive: true));

    final firstManager = RoomManager(persistenceDirectory: directory);
    final created = firstManager.createRoom(
      state: _twoHeroState(),
      started: true,
    );
    var server = await _serve(firstManager);
    addTearDown(() => server.close(force: true));

    final ada = await _connect(server, created.code, 'ada-participant');
    addTearDown(ada.sink.close);
    final adaInbox = _Inbox(ada);
    addTearDown(adaInbox.close);
    final adaJoined = await adaInbox.next();
    await adaInbox.next();
    final adaToken = adaJoined['reconnectToken']! as String;

    final boris = await _connect(server, created.code, 'boris-participant');
    addTearDown(boris.sink.close);
    final borisInbox = _Inbox(boris);
    addTearDown(borisInbox.close);
    final borisJoined = await borisInbox.next();
    await borisInbox.next();
    final borisToken = borisJoined['reconnectToken']! as String;

    ada.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'heal-before-crash',
        'expectedRevision': 0,
        'command': <String, Object?>{'type': 'heal', 'amount': 1},
      }),
    );
    final updated = await adaInbox.next();
    expect(updated['revision'], 1);
    expect(
      File(
        '${directory.path}/${created.code}.commands.json',
      ).readAsStringSync(),
      contains('heal-before-crash'),
    );
    // Snapshots from before participant-scoped command ids stored bare ids.
    // Preserve that legacy shape to verify restoration migrates it.
    final snapshotFile = File('${directory.path}/${created.code}.room.json');
    final legacySnapshot = Map<String, Object?>.from(
      jsonDecode(snapshotFile.readAsStringSync()) as Map<Object?, Object?>,
    )..['processedCommandIds'] = <String>['heal-before-crash'];
    snapshotFile.writeAsStringSync(jsonEncode(legacySnapshot));

    // Simulate a process crash: a fresh manager knows only what reached disk.
    await server.close(force: true);
    final restoredManager = RoomManager(persistenceDirectory: directory);
    final restored = restoredManager.room(created.code);
    expect(restored, isNotNull);
    expect(restored!.revision, 1);
    expect(restored.state.seed, 8);
    expect(
      restored.state.players.singleWhere((player) => player.id == 'ada').damage,
      0,
    );

    server = await _serve(restoredManager);
    final reconnected = await _connect(
      server,
      created.code,
      'ada-participant',
      reconnectToken: adaToken,
    );
    addTearDown(reconnected.sink.close);
    final reconnectedInbox = _Inbox(reconnected);
    addTearDown(reconnectedInbox.close);
    final joined = await reconnectedInbox.next();
    final state = await reconnectedInbox.next();
    expect(joined['heroId'], 'ada');
    expect(joined['reconnectToken'], adaToken);
    expect(state['type'], 'state');
    expect(state['revision'], 1);
    expect(
      (state['state']! as Map<Object?, Object?>).containsKey('seed'),
      isFalse,
    );

    // The retry retains its original revision, so it proves the bare legacy
    // id was migrated before the stale-revision check.
    reconnected.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'heal-before-crash',
        'expectedRevision': 0,
        'command': <String, Object?>{'type': 'heal', 'amount': 1},
      }),
    );
    final retried = await reconnectedInbox.next();
    expect(retried['type'], 'state');
    expect(retried['revision'], 1);
    expect(restored.revision, 1);

    // Boris has a valid session, but not Ada's active hero. His command is
    // rejected rather than being applied to the active player.
    final borisReconnected = await _connect(
      server,
      created.code,
      'boris-participant',
      reconnectToken: borisToken,
    );
    addTearDown(borisReconnected.sink.close);
    final borisReconnectInbox = _Inbox(borisReconnected);
    addTearDown(borisReconnectInbox.close);
    await borisReconnectInbox.next();
    await borisReconnectInbox.next();
    borisReconnected.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'boris-cannot-control-ada',
        'expectedRevision': 1,
        'command': <String, Object?>{'type': 'heal', 'amount': 1},
      }),
    );
    final rejected = await borisReconnectInbox.next();
    expect(rejected['type'], 'error');
    expect(rejected['reason'], 'Only the active hero may issue commands.');
    expect(restored.revision, 1);

    // The restarted room derives its roller from the persisted revision, so
    // the next outcome cannot restart the initial pseudo-random sequence.
    reconnected.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'roll-after-restart',
        'expectedRevision': 1,
        'command': <String, Object?>{'type': 'skillCheck', 'stat': 'science'},
      }),
    );
    final rolled = await reconnectedInbox.next();
    final pending = Map<String, Object?>.from(
      (rolled['state']! as Map<Object?, Object?>)['pendingDecision']!
          as Map<Object?, Object?>,
    );
    expect(pending['dice'], SeededDiceRoller(8 ^ 1).rollDice(1));
    expect(restored.revision, 2);
  });
}

Future<HttpServer> _serve(RoomManager manager) => shelf_io.serve(
  manager.handler,
  InternetAddress.loopbackIPv4,
  0,
);

Future<IOWebSocketChannel> _connect(
  HttpServer server,
  String roomCode,
  String participantId, {
  String? reconnectToken,
}) async {
  final channel = IOWebSocketChannel.connect(
    Uri(
      scheme: 'ws',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/rooms/$roomCode/ws',
      queryParameters: <String, String>{
        'participantId': participantId,
        if (reconnectToken != null) 'reconnectToken': reconnectToken,
      },
    ),
  );
  await channel.ready;
  return channel;
}

final class _Inbox {
  _Inbox(IOWebSocketChannel channel) {
    _subscription = channel.stream.listen((Object? message) {
      final parsed = Map<String, Object?>.from(
        jsonDecode(message! as String) as Map<Object?, Object?>,
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
    if (_messages.isNotEmpty) return Future.value(_messages.removeAt(0));
    final waiting = Completer<Map<String, Object?>>();
    _waiting = waiting;
    return waiting.future.timeout(const Duration(seconds: 2));
  }

  Future<void> close() => _subscription.cancel();
}

GameState _twoHeroState() => GameState(
  seed: 8,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: <HexTile>[
    HexTile(
      id: 'anabiosis',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const <HexEdge>{},
      hasTerminal: false,
      ventColor: VentColor.none,
    ),
  ],
  players: <PlayerState>[
    _player('ada', damage: 1),
    _player('boris'),
  ],
  monsters: const <MonsterInstance>[],
  decks: const <String, DeckState>{},
  quests: QuestState(),
);

PlayerState _player(String id, {int damage = 0}) => PlayerState(
  id: id,
  characterId: '$id-hero',
  coord: const HexCoord(0, 0),
  damage: damage,
  credits: 0,
  backpack: const <String>[],
  equipped: const EquippedGear(),
  carriedMods: const <String>[],
  implanted: const <String>[],
  conditions: const <String>[],
  alive: true,
);
