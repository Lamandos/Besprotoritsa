import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('co-located monster cards remain individually reachable', (
    tester,
  ) async {
    final source = createMvpGameState();
    final coord = source.players.first.coord;
    MonsterInstance monster(String id) => MonsterInstance(
      instanceId: id,
      monsterId: id,
      coord: coord,
      damage: 0,
      health: 2,
      defense: 0,
      attack: 1,
      movement: 1,
    );
    final state = GameState(
      seed: source.seed,
      difficulty: source.difficulty,
      round: source.round,
      phase: source.phase,
      activePlayerId: source.activePlayerId,
      actionsLeft: source.actionsLeft,
      board: source.board,
      players: source.players,
      monsters: [monster('underlying-monster'), monster('top-monster')],
      decks: source.decks,
      quests: source.quests,
      conditionCards: source.conditionCards,
      cardDefinitions: source.cardDefinitions,
      log: source.log,
    );
    final queue = EventQueue(eventDuration: Duration.zero);
    final container = ProviderContainer(
      overrides: [
        eventQueueProvider.overrideWithValue(queue),
        gameControllerProvider.overrideWith(
          () => GameController(initialState: state),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(queue.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byTooltip('Карточка монстра: top-monster'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('top-monster'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(
      find.byTooltip('Карточка монстра: underlying-monster'),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('underlying-monster'), findsOneWidget);
  });

  testWidgets('monster placement decision shows a board projection', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 41,
    );
    final hero = source.players.first;
    final start = source.tileAt(hero.coord)!;
    final targetTile = source.board.firstWhere((tile) {
      if (hero.coord.distanceTo(tile.coord) != 1) return false;
      final edge = hero.coord.edgeToward(tile.coord);
      return start.hasExit(edge);
    });
    final target = targetTile.coord;
    final board = source.board
        .map(
          (tile) => tile.id != targetTile.id
              ? tile
              : HexTile(
                  id: tile.id,
                  coord: tile.coord,
                  type: tile.type,
                  opened: true,
                  exits: tile.exits,
                  locationId: tile.locationId,
                  hasTerminal: tile.hasTerminal,
                  ventColor: tile.ventColor,
                  isBlocked: tile.isBlocked,
                  monsterAccessBlocked: tile.monsterAccessBlocked,
                ),
        )
        .toList(growable: false);
    final monsterId = source.decks['monsters']!.drawPile.first;
    final monsterDefinition = source.monsterDefinitions[monsterId]!;
    final monster = MonsterInstance(
      instanceId: 'monster-target',
      monsterId: monsterId,
      coord: hero.coord,
      damage: 0,
      health: monsterDefinition['health']! as int,
      defense: monsterDefinition['defense']! as int,
      attack: monsterDefinition['attack']! as int,
      movement: monsterDefinition['movement']! as int,
    );
    final initialState = GameState(
      seed: source.seed,
      contentSetId: source.contentSetId,
      contentSetVersion: source.contentSetVersion,
      difficulty: source.difficulty,
      round: source.round,
      phase: source.phase,
      activePlayerId: source.activePlayerId,
      actionsLeft: source.actionsLeft,
      board: board,
      players: source.players,
      monsters: [monster],
      decks: source.decks,
      quests: source.quests,
      cardDefinitions: source.cardDefinitions,
      eventDefinitions: source.eventDefinitions,
      questDefinitions: source.questDefinitions,
      taskDefinitions: source.taskDefinitions,
      monsterDefinitions: source.monsterDefinitions,
      contentTranslations: source.contentTranslations,
      pendingDecision: AwaitingEventOption(
        options: ['place:${monster.instanceId}:${target.q}:${target.r}'],
        playerId: source.activePlayerId,
        eventId: source.eventDefinitions.keys.first,
      ),
    );
    final queue = EventQueue(eventDuration: Duration.zero);
    final container = ProviderContainer(
      overrides: [
        eventQueueProvider.overrideWithValue(queue),
        gameControllerProvider.overrideWith(
          () => GameController(initialState: initialState),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(queue.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('event-target-board-map')),
      findsOneWidget,
    );
    final boardProjection = find.byKey(
      const ValueKey<String>('event-target-board-widget'),
    );
    expect(
      find.descendant(
        of: boardProjection,
        matching: find.byKey(
          ValueKey<String>(
            'hero-${hero.id}-at-${hero.coord.q}-${hero.coord.r}',
          ),
        ),
      ),
      findsOneWidget,
    );
    final monsterNameKey = monsterDefinition['nameKey']! as String;
    final monsterName = source.contentTranslations[monsterNameKey]!;
    expect(
      find.descendant(
        of: boardProjection,
        matching: find.byTooltip('Карточка монстра: $monsterName'),
      ),
      findsOneWidget,
    );
    final targetTileInDialog = find.descendant(
      of: boardProjection,
      matching: find.byKey(
        ValueKey<String>('hex-${target.q}-${target.r}'),
      ),
    );
    expect(targetTileInDialog, findsOneWidget);
    await tester.tap(targetTileInDialog);
    await tester.pump(const Duration(milliseconds: 300));

    final resolved = container.read(gameControllerProvider);
    expect(resolved.pendingDecision, isNull);
    expect(resolved.monsters.single.coord, target);
  });

  testWidgets('shared journal does not reveal personal task cards', (
    tester,
  ) async {
    final initialState = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 31,
    );
    final privateTaskId =
        initialState.quests.personalTasksByPlayer.values.first.first;
    final privateTaskNameKey =
        initialState.taskDefinitions[privateTaskId]!['nameKey']! as String;
    final privateTaskName =
        initialState.contentTranslations[privateTaskNameKey]!;
    final queue = EventQueue(eventDuration: const Duration(seconds: 1));
    final container = ProviderContainer(
      overrides: [
        eventQueueProvider.overrideWithValue(queue),
        gameControllerProvider.overrideWith(
          () => GameController(initialState: initialState),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(queue.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wide-turn-log-button-bottom')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Текущая цель кампании'), findsOneWidget);
    expect(find.text('Пробуждение'), findsWidgets);
    expect(find.textContaining('0/1'), findsWidgets);
    expect(find.text(privateTaskName), findsNothing);
    await tester.tap(find.text('Личные задачи активного героя'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(privateTaskName), findsOneWidget);
  });

  testWidgets(
    'moving queues animation events and updates the hero position',
    (tester) async {
      final queue = EventQueue(eventDuration: const Duration(seconds: 1));
      final initialState = _stateWithoutMonsters();
      final container = ProviderContainer(
        overrides: [
          eventQueueProvider.overrideWithValue(queue),
          gameControllerProvider.overrideWith(
            () => GameController(initialState: initialState),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );

      expect(find.text('СЮЖЕТ'), findsOneWidget);
      expect(
        find.textContaining('Доберитесь до КАЮТ-КОМПАНИИ'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsOneWidget,
      );
      expect(queue.isPlaying, isFalse);
      expect(
        find.byKey(mvpMoveConfirmButtonKey),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('hero-ada-at-0-0')));
      await tester.tap(find.byKey(const ValueKey<String>('hex-0-1')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(mvpMoveConfirmButtonKey))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(mvpMoveConfirmButtonKey));
      await tester.pump();

      expect(queue.current, isNull);
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hex-0-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('hex-0-1')));
      await tester.pump();
      await tester.tap(find.byKey(mvpMoveConfirmButtonKey));
      await tester.pump();

      expect(queue.current, isA<HexEntered>());
      expect(queue.pendingCount, 1);
      expect(
        find.byKey(const ValueKey<String>('animation-status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-1')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

GameState _stateWithoutMonsters() {
  final state = createMvpGameState();
  return GameState(
    seed: state.seed,
    difficulty: state.difficulty,
    round: state.round,
    phase: state.phase,
    activePlayerId: state.activePlayerId,
    actionsLeft: state.actionsLeft,
    board: state.board,
    players: state.players,
    monsters: const [],
    decks: state.decks,
    quests: state.quests,
    conditionCards: state.conditionCards,
    cardDefinitions: state.cardDefinitions,
    log: state.log,
  );
}
