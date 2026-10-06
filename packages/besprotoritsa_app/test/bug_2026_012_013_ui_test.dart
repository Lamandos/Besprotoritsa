import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reclosed corridor selection offers opening action', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 12,
    );
    final hero = source.players.first;
    final corridor = source.board.firstWhere((tile) {
      if (tile.type != HexTileType.corridor ||
          hero.coord.distanceTo(tile.coord) != 1) {
        return false;
      }
      return source
          .tileAt(hero.coord)!
          .hasExit(hero.coord.edgeToward(tile.coord));
    });
    final state = _copyState(
      source,
      board: [
        for (final tile in source.board)
          if (tile.id == corridor.id)
            HexTile(
              id: tile.id,
              coord: tile.coord,
              type: tile.type,
              opened: true,
              exits: tile.exits,
              locationId: tile.locationId,
              hasTerminal: tile.hasTerminal,
              ventColor: tile.ventColor,
              isBlocked: true,
              monsterAccessBlocked: tile.monsterAccessBlocked,
            )
          else
            tile,
      ],
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
    _setWideViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ОТКРЫТЬ КОРИДОР'), findsNothing);
    await tester.tap(
      find.byKey(
        ValueKey<String>('hex-${corridor.coord.q}-${corridor.coord.r}'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('ОТКРЫТЬ КОРИДОР'), findsOneWidget);
    expect(find.textContaining('ДВИЖЕНИЕ'), findsNothing);
    expect(find.textContaining('ЗАКРЫТЬ КОРИДОР'), findsNothing);
  });

  testWidgets('corridor art fills its rectangular tile without rounded frame', (
    tester,
  ) async {
    final source = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 14,
    );
    final state = _copyState(
      source,
      board: [
        for (final tile in source.board)
          if (tile.type == HexTileType.corridor)
            HexTile(
              id: tile.id,
              coord: tile.coord,
              type: tile.type,
              opened: true,
              exits: tile.exits,
              locationId: tile.locationId,
              hasTerminal: tile.hasTerminal,
              ventColor: tile.ventColor,
            )
          else
            tile,
      ],
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
    _setWideViewport(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final corridorArt = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.endsWith('/corridor.webp'),
    );
    expect(corridorArt, findsWidgets);
    expect(tester.widget<Image>(corridorArt.first).fit, BoxFit.cover);
    final size = tester.getSize(corridorArt.first);
    expect(size.width / size.height, closeTo(4 / 3, .01));
  });

  testWidgets(
    'field action buttons appear only for a selected target and valid actions',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 15,
      );
      final hero = source.players.first;
      final corridor = source.board.firstWhere((tile) {
        if (tile.type != HexTileType.corridor ||
            hero.coord.distanceTo(tile.coord) != 1) {
          return false;
        }
        return source
            .tileAt(hero.coord)!
            .hasExit(hero.coord.edgeToward(tile.coord));
      });
      final state = _copyState(
        source,
        board: [
          for (final tile in source.board)
            if (tile.id == corridor.id)
              HexTile(
                id: tile.id,
                coord: tile.coord,
                type: tile.type,
                opened: true,
                exits: tile.exits,
                locationId: tile.locationId,
                hasTerminal: tile.hasTerminal,
                ventColor: tile.ventColor,
                isBlocked: true,
                monsterAccessBlocked: tile.monsterAccessBlocked,
              )
            else
              tile,
        ],
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
      _setWideViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('ОТКРЫТЬ КОРИДОР'), findsNothing);
      expect(find.textContaining('ЗАКРЫТЬ КОРИДОР'), findsNothing);
      expect(find.textContaining('ДВИЖЕНИЕ'), findsNothing);

      await tester.tap(
        find.byKey(
          ValueKey<String>('hex-${corridor.coord.q}-${corridor.coord.r}'),
        ),
      );
      await tester.pump();
      expect(find.textContaining('ОТКРЫТЬ КОРИДОР'), findsOneWidget);
      expect(find.textContaining('ЗАКРЫТЬ КОРИДОР'), findsNothing);
      expect(find.textContaining('ДВИЖЕНИЕ'), findsNothing);
    },
  );

  testWidgets(
    'selected open corridor exposes only its valid move and close actions',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 16,
      );
      final hero = source.players.first;
      final corridor = source.board.firstWhere((tile) {
        if (tile.type != HexTileType.corridor ||
            hero.coord.distanceTo(tile.coord) != 1) {
          return false;
        }
        return source
            .tileAt(hero.coord)!
            .hasExit(hero.coord.edgeToward(tile.coord));
      });
      final state = _copyState(
        source,
        board: [
          for (final tile in source.board)
            if (tile.id == corridor.id)
              HexTile(
                id: tile.id,
                coord: tile.coord,
                type: tile.type,
                opened: true,
                exits: tile.exits,
                locationId: tile.locationId,
                hasTerminal: tile.hasTerminal,
                ventColor: tile.ventColor,
                monsterAccessBlocked: tile.monsterAccessBlocked,
              )
            else
              tile,
        ],
      );
      final canMove = validate(state, MoveCommand(corridor.coord)) == null;
      final canClose =
          validate(state, CloseCorridorCommand(corridor.coord)) == null;
      expect(canMove || canClose, isTrue);

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
      _setWideViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('ДВИЖЕНИЕ'), findsNothing);
      expect(find.textContaining('ЗАКРЫТЬ КОРИДОР'), findsNothing);

      await tester.tap(
        find.byKey(
          ValueKey<String>('hex-${corridor.coord.q}-${corridor.coord.r}'),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('ДВИЖЕНИЕ'),
        canMove ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('ЗАКРЫТЬ КОРИДОР'),
        canClose ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('ОТКРЫТЬ КОРИДОР'), findsNothing);
    },
  );

  testWidgets(
    'compact action dock also waits for a selected corridor',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 17,
      );
      final hero = source.players.first;
      final corridor = source.board.firstWhere((tile) {
        if (tile.type != HexTileType.corridor ||
            hero.coord.distanceTo(tile.coord) != 1) {
          return false;
        }
        return source
            .tileAt(hero.coord)!
            .hasExit(hero.coord.edgeToward(tile.coord));
      });
      final state = _copyState(
        source,
        board: [
          for (final tile in source.board)
            if (tile.id == corridor.id)
              HexTile(
                id: tile.id,
                coord: tile.coord,
                type: tile.type,
                opened: true,
                exits: tile.exits,
                locationId: tile.locationId,
                hasTerminal: tile.hasTerminal,
                ventColor: tile.ventColor,
                isBlocked: true,
                monsterAccessBlocked: tile.monsterAccessBlocked,
              )
            else
              tile,
        ],
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
      tester.view.physicalSize = const Size(390, 844);
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

      expect(find.textContaining('Открыть коридор'), findsNothing);
      await tester.tap(
        find.byKey(
          ValueKey<String>('hex-${corridor.coord.q}-${corridor.coord.r}'),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Открыть коридор'), findsOneWidget);
      expect(find.textContaining('Закрыть коридор'), findsNothing);
    },
  );

  testWidgets(
    'monster card shows active hero combat strength and attack action',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 13,
      );
      final hero = source.players.first;
      final monsterId = source.decks['monsters']!.drawPile.first;
      final definition = source.monsterDefinitions[monsterId]!;
      final monster = MonsterInstance(
        instanceId: 'monster-card-target',
        monsterId: monsterId,
        coord: hero.coord,
        damage: 0,
        health: definition['health']! as int,
        defense: definition['defense']! as int,
        attack: definition['attack']! as int,
        movement: definition['movement']! as int,
      );
      final state = _copyState(source, monsters: [monster]);
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
      _setWideViewport(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final name = state.contentTranslations[definition['nameKey']! as String]!;
      await tester.tap(find.byTooltip('Карточка монстра: $name'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Сила боя'), findsOneWidget);
      expect(find.text('Атаковать'), findsOneWidget);
      await tester.tap(find.text('Атаковать'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        container.read(gameControllerProvider).actionsLeft,
        lessThan(state.actionsLeft),
      );
    },
  );
}

GameState _copyState(
  GameState source, {
  Iterable<HexTile>? board,
  Iterable<MonsterInstance>? monsters,
}) => GameState(
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
  actionsTakenThisTurn: source.actionsTakenThisTurn,
  board: board ?? source.board,
  players: source.players,
  monsters: monsters ?? source.monsters,
  decks: source.decks,
  quests: source.quests,
  chestCards: source.chestCards,
  boils: source.boils,
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
  pendingDecision: source.pendingDecision,
  pendingEventMonsterSpawn: source.pendingEventMonsterSpawn,
);

void _setWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
