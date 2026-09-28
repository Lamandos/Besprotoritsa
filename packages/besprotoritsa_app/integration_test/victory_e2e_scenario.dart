import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the shipped quest graph reaches its terminal transition', () async {
    final questDocument =
        jsonDecode(
              await File('../../content/quests.json').readAsString(),
            )
            as Map<String, dynamic>;
    final graph = QuestGraph.fromJson(Map<String, Object?>.from(questDocument));
    final engine = QuestEngine(graph);
    var progress = engine.initialProgress();
    QuestTransition? terminalTransition;

    for (final event in _victoryRoute) {
      final transition = engine.apply(progress, event);
      progress = transition.progress;
      terminalTransition = transition;
    }

    expect(terminalTransition, isNotNull);
    final victoryTransition = terminalTransition!;
    expect(victoryTransition.gameWon, isTrue);
    expect(
      progress.completedQuestIds,
      containsAll(<String>[
        for (var number = 1; number <= 12; number++)
          'quest-${number.toString().padLeft(2, '0')}',
      ]),
    );
  });

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

const _victoryRoute = <QuestEvent>[
  QuestArrived('crew-quarters'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'crew-quarters',
    success: true,
  ),
  QuestArrived('engineering-control-post'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'engineering-control-post',
    success: true,
  ),
  QuestArrived('reactor'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'reactor',
    success: true,
  ),
  QuestArrived('medical-bay'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'medical-bay',
    success: true,
  ),
  QuestArrived('laboratory'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'laboratory',
    success: true,
  ),
  QuestArrived('main-computer'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'main-computer',
    success: true,
  ),
  QuestArrived('escape-pods'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'escape-pods',
    success: true,
  ),
  QuestArrived('storage'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'storage',
    success: true,
  ),
  QuestArrived('flight-control'),
  QuestMonsterKilled(monsterId: 'viy'),
  QuestArrived('escape-pods'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'escape-pods',
    success: true,
  ),
  QuestArrived('escape-pods'),
  QuestMonsterKilled(monsterId: 'mother'),
];
