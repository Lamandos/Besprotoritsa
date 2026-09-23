import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late HttpServer server;
  late RoomManager manager;
  late GameRoom room;

  setUp(() async {
    manager = RoomManager();
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

  test('creates a room only from trusted content parameters', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final endpoint = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/rooms',
    );
    final request = await client.postUrl(endpoint);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, Object?>{
        'contentSetId': 'mvp',
        'partySize': 2,
        'mode': <String, Object?>{'difficulty': 'normal'},
      }),
    );
    final response = await request.close();

    expect(response.statusCode, HttpStatus.ok);
    final created = Map<String, Object?>.from(
      jsonDecode(await response.transform(utf8.decoder).join()) as Map,
    );
    final code = created['roomCode']! as String;
    final authoritative = manager.room(code);
    expect(authoritative, isNotNull);
    expect(authoritative!.state.players, hasLength(2));
    expect(authoritative.state.seed, isNot(0));
  });

  test('rejects an invalid posted card definition with bad request', () async {
    final document = GameStateJsonCodec().toJson(_twoHeroState())
      ..['card_definitions'] = <String, Object?>{
        'invalid-card': <String, Object?>{
          'id': 'invalid-card',
          'category': 'unknown',
          'slots': <String>[],
          'cost': 0,
          'stats': <String, int>{},
          'behaviorIds': <String>[],
        },
      };
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.postUrl(
      Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        path: '/rooms',
      ),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(document));
    final response = await request.close();

    expect(response.statusCode, HttpStatus.badRequest);
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

      expect(room.code, matches(RegExp(r'^[A-F0-9]{32}$')));
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
          'commandId': 'end-turn-ada-1',
          'expectedRevision': 0,
          'command': {'type': 'endTurn'},
        }),
      );
      final adaUpdated = await adaInbox.next();
      final borisUpdated = await borisInbox.next();
      expect(adaUpdated['revision'], 1);
      expect(borisUpdated['revision'], 1);
      expect(room.revision, 1);

      // The same id is an idempotent retry. A stale retry replays the
      // authoritative outcome to the original participant without stepping
      // rules or broadcasting to other players.
      ada.sink.add(
        jsonEncode({
          'type': 'command',
          'commandId': 'end-turn-ada-1',
          'expectedRevision': 0,
          'command': {'type': 'endTurn'},
        }),
      );
      final retried = await adaInbox.next();
      expect(retried['type'], 'state');
      expect(retried['revision'], 1);
      expect(room.revision, 1);

      ada.sink.add(
        jsonEncode({
          'type': 'command',
          'commandId': 'end-turn-ada-1',
          'expectedRevision': 1,
          'command': {'type': 'skillCheck', 'stat': 'science'},
        }),
      );
      final reused = await adaInbox.next();
      expect(reused['type'], 'error');
      expect(
        reused['reason'],
        'Command ID was already used for a different command.',
      );
      expect(room.revision, 1);
    },
  );

  test(
    'does not send monsters in fog or carried gear on visible monsters',
    () async {
      final privateRoom = manager.createRoom(
        state: _twoHeroState(
          board: [
            HexTile(
              id: 'anabiosis',
              coord: const HexCoord(0, 0),
              type: HexTileType.start,
              opened: true,
              exits: const {HexEdge.south},
              hasTerminal: false,
              ventColor: VentColor.none,
            ),
            HexTile(
              id: 'fog',
              coord: const HexCoord(0, 1),
              type: HexTileType.corridor,
              opened: false,
              exits: const {HexEdge.north},
              hasTerminal: false,
              ventColor: VentColor.none,
            ),
          ],
          monsters: [
            MonsterInstance(
              instanceId: 'visible',
              monsterId: 'restless',
              coord: const HexCoord(0, 0),
              damage: 0,
              carriedGear: const ['private-gear'],
            ),
            MonsterInstance(
              instanceId: 'hidden',
              monsterId: 'ghoul',
              coord: const HexCoord(0, 1),
              damage: 0,
            ),
          ],
        ),
        started: true,
      );
      final ada = await _connect(server, privateRoom.code, 'ada-participant');
      addTearDown(ada.sink.close);
      final inbox = _Inbox(ada);
      addTearDown(inbox.close);
      await inbox.next();
      final envelope = await inbox.next();
      final state = Map<String, Object?>.from(envelope['state']! as Map);
      final monsters = (state['monsters']! as List<Object?>)
          .map((monster) => Map<String, Object?>.from(monster! as Map))
          .toList();

      expect(monsters.map((monster) => monster['instanceId']), ['visible']);
      expect(monsters.single.containsKey('carriedGear'), isFalse);
      expect(jsonEncode(envelope), isNot(contains('private-gear')));
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

  test('hides an active hero decision with an implicit owner', () async {
    final manager = RoomManager();
    final implicitOwnerRoom = manager.createRoom(
      state: _twoHeroState(
        pendingDecision: AwaitingEventOption(options: const ['A', 'B']),
      ),
      started: true,
    );
    final implicitOwnerServer = await shelf_io.serve(
      manager.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => implicitOwnerServer.close(force: true));

    final ada = await _connect(
      implicitOwnerServer,
      implicitOwnerRoom.code,
      'ada-participant',
    );
    addTearDown(ada.sink.close);
    final adaInbox = _Inbox(ada);
    addTearDown(adaInbox.close);
    await adaInbox.next();
    final adaState = await adaInbox.next();

    final boris = await _connect(
      implicitOwnerServer,
      implicitOwnerRoom.code,
      'boris-participant',
    );
    addTearDown(boris.sink.close);
    final borisInbox = _Inbox(boris);
    addTearDown(borisInbox.close);
    await borisInbox.next();
    final borisState = await borisInbox.next();

    final adaDecision = Map<String, Object?>.from(
      (adaState['state']! as Map<Object?, Object?>)['pendingDecision']!
          as Map<Object?, Object?>,
    );
    final borisDecision = Map<String, Object?>.from(
      (borisState['state']! as Map<Object?, Object?>)['pendingDecision']!
          as Map<Object?, Object?>,
    );
    expect(adaDecision['type'], 'eventOption');
    expect(borisDecision, <String, Object?>{
      'type': 'hidden',
      'awaitingPlayerId': 'ada',
    });
  });

  test('only the pending-decision owner can resolve a dodge', () async {
    final manager = RoomManager();
    final decisionRoom = manager.createRoom(
      state: _twoHeroState(
        pendingDecision: const AwaitingDodge(
          monsterDamage: 1,
          requiredAgilitySuccesses: 1,
          targetPlayerId: 'boris',
        ),
      ),
      started: true,
    );
    final decisionServer = await shelf_io.serve(
      manager.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => decisionServer.close(force: true));

    final ada = await _connect(
      decisionServer,
      decisionRoom.code,
      'owner-ada',
    );
    addTearDown(ada.sink.close);
    final adaInbox = _Inbox(ada);
    addTearDown(adaInbox.close);
    await adaInbox.next();
    await adaInbox.next();
    final boris = await _connect(
      decisionServer,
      decisionRoom.code,
      'owner-boris',
    );
    addTearDown(boris.sink.close);
    final borisInbox = _Inbox(boris);
    addTearDown(borisInbox.close);
    await borisInbox.next();
    await borisInbox.next();

    ada.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'ada-cannot-dodge-for-boris',
        'expectedRevision': 0,
        'command': <String, Object?>{
          'type': 'resolveDecision',
          'choice': <String, Object?>{'type': 'dodge'},
        },
      }),
    );
    final rejected = await adaInbox.next();
    expect(
      rejected['reason'],
      'Only the hero awaiting this decision may resolve it.',
    );
    expect(decisionRoom.revision, 0);

    boris.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': 'boris-dodges',
        'expectedRevision': 0,
        'command': <String, Object?>{
          'type': 'resolveDecision',
          'choice': <String, Object?>{'type': 'dodge'},
        },
      }),
    );
    expect((await adaInbox.next())['revision'], 1);
    expect((await borisInbox.next())['revision'], 1);
    expect(decisionRoom.revision, 1);
  });

  test('rejects privileged state-mutating messages from a client', () async {
    final ada = await _connect(server, room.code, 'privileged-ada');
    addTearDown(ada.sink.close);
    final inbox = _Inbox(ada);
    addTearDown(inbox.close);
    await inbox.next();
    await inbox.next();

    for (final command in <Map<String, Object?>>[
      <String, Object?>{'type': 'heal', 'amount': 99},
      <String, Object?>{
        'type': 'receiveCard',
        'cardId': 'ada-private-card',
      },
      <String, Object?>{
        'type': 'equip',
        'cardId': 'ada-private-card',
        'weaponSlot': 'not-an-integer',
      },
    ]) {
      ada.sink.add(
        jsonEncode(<String, Object?>{
          'type': 'command',
          'commandId': 'forbidden-${command['type']}',
          'expectedRevision': 0,
          'command': command,
        }),
      );
      expect((await inbox.next())['type'], 'error');
      expect(room.revision, 0);
    }
  });

  test(
    'does not reveal another hero condition through transition events',
    () async {
      final manager = RoomManager();
      final conditionServer = await shelf_io.serve(
        manager.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => conditionServer.close(force: true));

      // A dodge failure applies the condition to Ada, who owns the decision.
      final base = _twoHeroState();
      final withDodge = GameState(
        seed: base.seed,
        round: base.round,
        phase: base.phase,
        activePlayerId: 'ada',
        actionsLeft: base.actionsLeft,
        board: base.board,
        players: base.players,
        monsters: base.monsters,
        decks: <String, DeckState>{
          'conditions': DeckState(drawPile: const <String>['malaise']),
        },
        conditionCards: <String, ConditionCard>{
          'malaise': ConditionCard(
            id: 'malaise',
            statModifiers: const <StatType, int>{StatType.strength: -1},
          ),
        },
        quests: base.quests,
        pendingDecision: const AwaitingDodge(
          monsterDamage: 1,
          requiredAgilitySuccesses: 1,
          targetPlayerId: 'ada',
        ),
      );
      // This separate room keeps the test focused on the recipient-specific
      // broadcast generated by one accepted decision.
      final eventRoom = manager.createRoom(state: withDodge, started: true);
      final eventAda = await _connect(
        conditionServer,
        eventRoom.code,
        'event-ada',
      );
      addTearDown(eventAda.sink.close);
      final eventAdaInbox = _Inbox(eventAda);
      addTearDown(eventAdaInbox.close);
      await eventAdaInbox.next();
      await eventAdaInbox.next();
      final eventBoris = await _connect(
        conditionServer,
        eventRoom.code,
        'event-boris',
      );
      addTearDown(eventBoris.sink.close);
      final eventBorisInbox = _Inbox(eventBoris);
      addTearDown(eventBorisInbox.close);
      await eventBorisInbox.next();
      await eventBorisInbox.next();

      eventAda.sink.add(
        jsonEncode(<String, Object?>{
          'type': 'command',
          'commandId': 'dodge-fails',
          'expectedRevision': 0,
          'command': <String, Object?>{
            'type': 'resolveDecision',
            'choice': <String, Object?>{'type': 'dodge'},
          },
        }),
      );
      final ownState = await eventAdaInbox.next();
      final otherState = await eventBorisInbox.next();
      expect(jsonEncode(ownState), contains('condition_drawn'));
      expect(jsonEncode(otherState), isNot(contains('condition_drawn')));
    },
  );

  test('waits for every roster hero to be claimed before starting', () async {
    final manager = RoomManager();
    final waitingRoom = manager.createRoom(state: _threeHeroState());
    final waitingServer = await shelf_io.serve(
      manager.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => waitingServer.close(force: true));

    final ada = await _connectLobby(
      waitingServer,
      waitingRoom.code,
      'ada-participant',
    );
    addTearDown(ada.sink.close);
    final adaInbox = _Inbox(ada);
    addTearDown(adaInbox.close);
    await adaInbox.next();
    await adaInbox.next();

    final boris = await _connectLobby(
      waitingServer,
      waitingRoom.code,
      'boris-participant',
    );
    addTearDown(boris.sink.close);
    final borisInbox = _Inbox(boris);
    addTearDown(borisInbox.close);
    await borisInbox.next();
    await borisInbox.next();
    await adaInbox.next();

    ada.sink.add(jsonEncode(<String, Object?>{'type': 'ready', 'ready': true}));
    await adaInbox.next();
    await borisInbox.next();
    boris.sink.add(
      jsonEncode(<String, Object?>{'type': 'ready', 'ready': true}),
    );

    expect((await adaInbox.next())['type'], 'lobby');
    expect((await borisInbox.next())['type'], 'lobby');
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

Future<IOWebSocketChannel> _connectLobby(
  HttpServer server,
  String roomCode,
  String participantId,
) async {
  final channel = IOWebSocketChannel.connect(
    Uri(
      scheme: 'ws',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/rooms/$roomCode/lobby/ws',
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

GameState _twoHeroState({
  PendingDecision? pendingDecision,
  Iterable<PlayerState>? players,
  Iterable<HexTile>? board,
  Iterable<MonsterInstance> monsters = const [],
}) => GameState(
  seed: 8,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board:
      board ??
      [
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
  players:
      players ??
      [
        _player('ada', damage: 1, card: 'ada-private-card'),
        _player('boris', card: 'boris-secret-card'),
      ],
  monsters: monsters,
  decks: const {},
  quests: QuestState(),
  pendingDecision: pendingDecision,
);

GameState _threeHeroState() {
  final base = _twoHeroState();
  return GameState(
    seed: base.seed,
    round: base.round,
    phase: base.phase,
    activePlayerId: base.activePlayerId,
    actionsLeft: base.actionsLeft,
    board: base.board,
    players: <PlayerState>[
      ...base.players,
      _player('clara', card: 'clara-private-card'),
    ],
    monsters: base.monsters,
    decks: base.decks,
    quests: base.quests,
  );
}

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
