import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the production game command opens the victory screen', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(
            initialState: _victoryReadyState(),
            dice: FixedDiceRoller([6, 1]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    expect(
      controller.dispatch(const SkillCheckCommand(StatType.science)),
      isTrue,
    );
    expect(
      container.read(gameControllerProvider).pendingDecision,
      isA<AwaitingRerollChoice>(),
    );
    expect(
      controller.dispatch(
        const ResolvePendingDecisionCommand(KeepRollChoice()),
      ),
      isTrue,
    );

    final completed = container.read(gameControllerProvider);
    expect(
      completed.quests.statusOf('chapter-1-awakening'),
      QuestStatus.completed,
    );
    expect(completed.isComplete, isTrue);
    expect(completed.gameEvents.single, isA<MvpDemonstrationCompleted>());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('victory-screen')),
      findsOneWidget,
    );
    expect(find.text('Победа выживших'), findsOneWidget);
  });
}

GameState _victoryReadyState() {
  final source = createMvpGameState();
  final crewMess = source.board.singleWhere(
    (tile) => tile.locationId == 'crew-mess',
  );
  return GameState(
    seed: source.seed,
    difficulty: source.difficulty,
    round: source.round,
    phase: source.phase,
    activePlayerId: source.activePlayerId,
    actionsLeft: source.actionsLeft,
    board: [
      for (final tile in source.board)
        if (tile.id == crewMess.id)
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
    players: [
      for (var index = 0; index < source.players.length; index++)
        _copyPlayer(
          source.players[index],
          coord: index == 0 ? crewMess.coord : source.players[index].coord,
        ),
    ],
    monsters: const [],
    decks: source.decks,
    conditionCards: source.conditionCards,
    cardDefinitions: source.cardDefinitions,
    quests: source.quests,
  );
}

PlayerState _copyPlayer(PlayerState player, {required HexCoord coord}) =>
    PlayerState(
      id: player.id,
      characterId: player.characterId,
      coord: coord,
      damage: player.damage,
      health: player.health,
      credits: player.credits,
      backpack: player.backpack,
      equipped: player.equipped,
      carriedMods: player.carriedMods,
      implanted: player.implanted,
      conditions: player.conditions,
      alive: player.alive,
      stats: player.stats,
      actionPoints: player.actionPoints,
      weaponModifier: player.weaponModifier,
    );
