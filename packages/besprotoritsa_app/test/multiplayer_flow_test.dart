import 'dart:async';
import 'dart:io';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  test('multiplayer commands are validated by the authoritative server', () {
    final controller = MultiplayerGameController(
      serverUri: Uri.parse('ws://127.0.0.1:1'),
      roomCode: 'room',
      participantId: 'ada-client',
    );

    expect(controller.validatesCommandsLocally, isFalse);
  });

  test(
    'two multiplayer clients receive the confirmed authoritative transition',
    () async {
      final manager = RoomManager();
      final room = manager.createRoom(
        state: createMvpGameState(),
        started: true,
      );
      final server = await shelf_io.serve(
        manager.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final endpoint = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      final ada = _container(endpoint, room.code, 'ada-client');
      final boris = _container(endpoint, room.code, 'boris-client');
      addTearDown(ada.dispose);
      addTearDown(boris.dispose);

      ada.read(gameControllerProvider);
      boris.read(gameControllerProvider);
      final adaController =
          ada.read(gameControllerProvider.notifier)
              as MultiplayerGameController;
      final borisController =
          boris.read(gameControllerProvider.notifier)
              as MultiplayerGameController;
      await Future.wait([
        adaController.connected,
        borisController.connected,
      ]).timeout(const Duration(seconds: 3));

      expect(ada.read(gameControllerProvider).activePlayerId, 'ada');
      expect(boris.read(gameControllerProvider).players, hasLength(2));

      expect(
        adaController.dispatch(const RevealTileCommand(HexCoord(0, 1))),
        isTrue,
      );
      expect(adaController.isWaitingForConfirmation, isTrue);

      await _until(() => ada.read(gameControllerProvider).actionsLeft == 1);
      expect(
        ada.read(gameControllerProvider).players.first.coord,
        const HexCoord(0, 0),
      );
      expect(
        adaController.dispatch(const MoveCommand(HexCoord(0, 1))),
        isTrue,
      );
      await _until(() => ada.read(gameControllerProvider).actionsLeft == 0);
      await _until(() => boris.read(gameControllerProvider).actionsLeft == 0);

      expect(room.revision, 2);
      expect(
        ada.read(gameControllerProvider).players.first.coord,
        const HexCoord(0, 1),
      );
      expect(
        boris.read(gameControllerProvider).players.first.coord,
        const HexCoord(0, 1),
      );
      expect(adaController.isWaitingForConfirmation, isFalse);
      await _until(
        () => ada.read(eventQueueProvider).history.length == 2,
      );
      await _until(
        () => boris.read(eventQueueProvider).history.length == 2,
      );
      expect(ada.read(eventQueueProvider).history, hasLength(2));
      expect(boris.read(eventQueueProvider).history, hasLength(2));
    },
  );

  test(
    'BUG085 multiplayer reroll preserves the selected source card',
    () async {
      final manager = RoomManager();
      final room = manager.createRoom(
        state: _stateWithPendingReroll(),
        started: true,
      );
      final server = await shelf_io.serve(
        manager.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final endpoint = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      final ada = _container(endpoint, room.code, 'ada-client');
      addTearDown(ada.dispose);
      ada.read(gameControllerProvider);
      final controller =
          ada.read(gameControllerProvider.notifier)
              as MultiplayerGameController;
      await controller.connected.timeout(const Duration(seconds: 3));

      expect(
        controller.dispatch(
          ResolvePendingDecisionCommand(
            RerollChoice(
              diceIndexes: const [0],
              sourceCardId: 'science-stimulant',
            ),
          ),
        ),
        isTrue,
      );
      await _until(() => room.revision == 1);

      final player = room.state.players.firstWhere(
        (player) => player.id == 'hero-1',
      );
      expect(player.backpack, contains('defibrillator'));
      expect(player.backpack, isNot(contains('science-stimulant')));
      expect(
        (room.state.pendingDecision! as AwaitingRerollChoice).rerollSources,
        ['defibrillator'],
      );
    },
  );
}

ProviderContainer _container(
  Uri endpoint,
  String roomCode,
  String participantId,
) => ProviderContainer(
  overrides: [
    eventQueueProvider.overrideWith(
      (ref) => EventQueue(eventDuration: Duration.zero),
    ),
    gameControllerProvider.overrideWith(
      () => MultiplayerGameController(
        serverUri: endpoint,
        roomCode: roomCode,
        participantId: participantId,
      ),
    ),
  ],
);

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for multiplayer state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

GameState _stateWithPendingReroll() {
  final source = createFullGameState(characterIds: const ['engineer', 'guard']);
  final player = source.players.first;
  final rerollPlayer = PlayerState(
    id: player.id,
    characterId: player.characterId,
    coord: player.coord,
    damage: player.damage,
    health: player.health,
    credits: player.credits,
    backpack: const ['defibrillator', 'science-stimulant'],
    equipped: player.equipped,
    carriedMods: player.carriedMods,
    implanted: player.implanted,
    conditions: player.conditions,
    retainedEventCards: player.retainedEventCards,
    alive: player.alive,
    stats: player.stats,
    weaponModifier: player.weaponModifier,
    actionPoints: player.actionPoints,
    nextTurnActionDelta: player.nextTurnActionDelta,
    monsterDamageImmuneThroughRound: player.monsterDamageImmuneThroughRound,
    monsterDefenseBonusRound: player.monsterDefenseBonusRound,
    monsterDefenseBonus: player.monsterDefenseBonus,
    damageImmuneThroughRound: player.damageImmuneThroughRound,
    enemyFeaturesIgnoredThroughRound: player.enemyFeaturesIgnoredThroughRound,
    nextAttackBonusHits: player.nextAttackBonusHits,
    exhaustedRobots: player.exhaustedRobots,
  );
  return GameState(
    schemaVersion: source.schemaVersion,
    seed: source.seed,
    prngState: source.prngState,
    contentSetId: source.contentSetId,
    contentSetVersion: source.contentSetVersion,
    difficulty: source.difficulty,
    round: source.round,
    phase: source.phase,
    activePlayerId: source.activePlayerId,
    actionsLeft: source.actionsLeft,
    board: source.board,
    players: [rerollPlayer, ...source.players.skip(1)],
    monsters: source.monsters,
    decks: source.decks,
    quests: source.quests,
    chestCards: source.chestCards,
    exhaustedChestRobots: source.exhaustedChestRobots,
    boils: source.boils,
    tripwires: source.tripwires,
    reserveHeroes: source.reserveHeroes,
    queuedReplacements: source.queuedReplacements,
    conditionCards: source.conditionCards,
    cardDefinitions: source.cardDefinitions,
    eventDefinitions: source.eventDefinitions,
    questDefinitions: source.questDefinitions,
    taskDefinitions: source.taskDefinitions,
    monsterDefinitions: source.monsterDefinitions,
    contentTranslations: source.contentTranslations,
    pendingDamage: source.pendingDamage,
    log: source.log,
    gameEvents: source.gameEvents,
    isComplete: source.isComplete,
    monsterTurnIndex: source.monsterTurnIndex,
    monsterStepsRemaining: source.monsterStepsRemaining,
    eventTurnIndex: source.eventTurnIndex,
    actionsTakenThisTurn: source.actionsTakenThisTurn,
    pendingDecision: AwaitingRerollChoice(
      dice: const [1, 2, 3],
      availableRerolls: 2,
      window: const DecisionWindow(remainingTicks: 1),
      context: SkillCheckContext(
        playerId: player.id,
        stat: StatType.science,
      ),
      rerollSources: const ['defibrillator', 'science-stimulant'],
    ),
    pendingEventMonsterSpawn: source.pendingEventMonsterSpawn,
  );
}
