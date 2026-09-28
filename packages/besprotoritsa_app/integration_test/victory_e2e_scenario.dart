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

  testWidgets('fixed seed completes story quests 1–12 and opens victory', (
    tester,
  ) async {
    const fixedSeed = 0x51A7E;
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

    final source = createMvpGameState();
    final completed = GameState(
      seed: fixedSeed,
      round: source.round,
      phase: source.phase,
      activePlayerId: source.activePlayerId,
      actionsLeft: 0,
      board: source.board,
      players: source.players,
      monsters: source.monsters,
      decks: source.decks,
      quests: QuestState(
        storyQuestIds: graph.quests.map((quest) => quest.id),
        statuses: {
          for (final quest in graph.quests)
            quest.id: progress.isCompleted(quest.id)
                ? QuestStatus.completed
                : QuestStatus.active,
        },
      ),
      isComplete: victoryTransition.gameWon,
    );
    expect(completed.seed, fixedSeed);
    expect(completed.players.every((hero) => hero.alive), isTrue);

    final container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(initialState: completed),
        ),
      ],
    );
    addTearDown(container.dispose);
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
