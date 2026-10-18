import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('team event window gathers every hero selection before confirm', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 55,
    );
    final eventDefinitions = Map<String, Map<String, Object?>>.of(
      source.eventDefinitions,
    );
    final fireDefinition = Map<String, Object?>.of(eventDefinitions['fire']!);
    final fireOptions = (fireDefinition['options']! as List<Object?>)
        .map(
          (option) => Map<String, Object?>.from(
            option! as Map<Object?, Object?>,
          ),
        )
        .toList();
    fireOptions[0] = {
      ...fireOptions[0],
      'skillCheck': {'skill': 'science', 'difficulty': 2},
    };
    fireDefinition['options'] = fireOptions;
    eventDefinitions['fire'] = fireDefinition;
    final playerIds = source.players.map((player) => player.id).toList();
    final state = GameState(
      seed: source.seed,
      difficulty: source.difficulty,
      round: source.round,
      phase: source.phase,
      activePlayerId: source.activePlayerId,
      actionsLeft: source.actionsLeft,
      board: source.board,
      players: source.players,
      monsters: source.monsters,
      decks: source.decks,
      quests: source.quests,
      conditionCards: source.conditionCards,
      cardDefinitions: source.cardDefinitions,
      questDefinitions: source.questDefinitions,
      taskDefinitions: source.taskDefinitions,
      monsterDefinitions: source.monsterDefinitions,
      eventDefinitions: eventDefinitions,
      contentTranslations: source.contentTranslations,
      pendingDecision: AwaitingEventOption(
        options: const ['option-1', 'option-2'],
        eventId: 'fire',
        teamPlayerIds: playerIds,
        teamOptionsByPlayer: {
          for (final playerId in playerIds)
            playerId: const ['option-1', 'option-2'],
        },
      ),
    );
    final queue = EventQueue(eventDuration: Duration.zero);
    final container = ProviderContainer(
      overrides: [
        eventQueueProvider.overrideWithValue(queue),
        gameControllerProvider.overrideWith(
          () => GameController(
            initialState: state,
            dice: FixedDiceRoller([]),
          ),
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

    final confirmFinder = find.byKey(
      const ValueKey<String>('confirm-team-event-choices'),
    );
    expect(confirmFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);
    expect(
      find.byKey(const ValueKey<String>('team-event-hero-1-option-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('team-event-hero-2-option-2')),
      findsOneWidget,
    );
    expect(find.text('Успех'), findsNothing);
    expect(find.text('Провал'), findsNothing);
    for (final playerId in playerIds) {
      expect(
        find.byKey(ValueKey<String>('team-event-check-$playerId-option-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('team-event-stat-$playerId-option-1')),
        findsOneWidget,
      );
    }

    final firstChoiceFinder = find.byKey(
      const ValueKey<String>('team-event-hero-1-option-1'),
    );
    await tester.ensureVisible(firstChoiceFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(firstChoiceFinder);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    final secondChoiceFinder = find.byKey(
      const ValueKey<String>('team-event-hero-2-option-2'),
    );
    await tester.ensureVisible(secondChoiceFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(secondChoiceFinder);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
  });

  testWidgets('BUG118 condition chips follow the selected hero', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 57,
    );
    final conditionIds = source.conditionCards.keys.take(2).toList();
    final players = [
      _playerWithConditions(source.players[0], [conditionIds[0]]),
      _playerWithConditions(source.players[1], [conditionIds[1]]),
    ];
    final state = GameState(
      seed: source.seed,
      difficulty: source.difficulty,
      round: source.round,
      phase: source.phase,
      activePlayerId: source.activePlayerId,
      actionsLeft: source.actionsLeft,
      board: source.board,
      players: players,
      monsters: source.monsters,
      decks: source.decks,
      quests: source.quests,
      conditionCards: source.conditionCards,
      cardDefinitions: source.cardDefinitions,
      eventDefinitions: source.eventDefinitions,
      questDefinitions: source.questDefinitions,
      taskDefinitions: source.taskDefinitions,
      monsterDefinitions: source.monsterDefinitions,
      contentTranslations: source.contentTranslations,
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

    expect(
      find.byKey(ValueKey<String>('active-condition-${conditionIds[0]}-0')),
      findsOneWidget,
    );
    await tester.tap(find.text('Охранник').first);
    await tester.pump();

    expect(
      find.byKey(ValueKey<String>('active-condition-${conditionIds[1]}-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('active-condition-${conditionIds[0]}-0')),
      findsNothing,
    );
  });

  testWidgets('BUG119 selected inactive hero can use an anytime card', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 58,
    );
    final players = [
      source.players[0],
      _playerWithConditions(
        source.players[1],
        source.players[1].conditions,
        backpack: const ['nanobots'],
      ),
    ];
    final state = _gameStateWithPlayers(source, players);
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
    await tester.tap(find.text('Охранник').first);
    await tester.pump();
    await tester.tap(find.byKey(mvpInventoryButtonKey));
    await tester.pump(const Duration(milliseconds: 300));
    final inventoryScroll = find
        .ancestor(
          of: find.text('Наноботы'),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Наноботы'),
      180,
      scrollable: inventoryScroll,
    );

    final useButton = find.widgetWithText(FilledButton, 'Использовать');
    expect(useButton, findsOneWidget);
    expect(tester.widget<FilledButton>(useButton).onPressed, isNotNull);
    expect(
      container.read(gameControllerProvider.notifier).dispatch(
        UseCardAbilityCommand(
          'nanobots',
          playerId: state.players[1].id,
        ),
      ),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final resolved = container.read(gameControllerProvider);
    final inactiveHero = resolved.players[1];
    expect(inactiveHero.backpack, isEmpty);
    expect(inactiveHero.monsterDefenseBonusRound, resolved.round);
    expect(resolved.activePlayerId, state.activePlayerId);
    expect(resolved.actionsLeft, state.actionsLeft);
  });

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
      attack: 1,
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
      final targetTile = initialState.tileAt(const HexCoord(0, 1))!;
      final actionLabel = !targetTile.opened || targetTile.isBlocked
          ? 'ОТКРЫТЬ'
          : 'ДВИЖЕНИЕ';
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
      expect(find.textContaining('ДВИЖЕНИЕ'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('hero-ada-at-0-0')));
      await tester.tap(find.byKey(const ValueKey<String>('hex-0-1')));
      await tester.pump();
      expect(find.textContaining(actionLabel), findsOneWidget);
      await tester.tap(find.textContaining(actionLabel));
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
      await tester.tap(find.textContaining('ДВИЖЕНИЕ'));
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

PlayerState _playerWithConditions(
  PlayerState player,
  Iterable<String> conditions, {
  Iterable<String>? backpack,
}) => PlayerState(
  id: player.id,
  characterId: player.characterId,
  coord: player.coord,
  damage: player.damage,
  health: player.health,
  credits: player.credits,
  backpack: backpack ?? player.backpack,
  equipped: player.equipped,
  carriedMods: player.carriedMods,
  implanted: player.implanted,
  conditions: conditions,
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

GameState _gameStateWithPlayers(
  GameState source,
  Iterable<PlayerState> players,
) => GameState(
  seed: source.seed,
  difficulty: source.difficulty,
  round: source.round,
  phase: source.phase,
  activePlayerId: source.activePlayerId,
  actionsLeft: source.actionsLeft,
  board: source.board,
  players: players,
  monsters: source.monsters,
  decks: source.decks,
  quests: source.quests,
  conditionCards: source.conditionCards,
  cardDefinitions: source.cardDefinitions,
  eventDefinitions: source.eventDefinitions,
  questDefinitions: source.questDefinitions,
  taskDefinitions: source.taskDefinitions,
  monsterDefinitions: source.monsterDefinitions,
  contentTranslations: source.contentTranslations,
);

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
