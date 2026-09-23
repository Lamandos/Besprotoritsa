import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fixed seed completes story quests 1–12 and opens victory', (
    tester,
  ) async {
    const fixedSeed = 0x51A7E;
    final graph = QuestGraph(quests: _storyQuests);
    final engine = QuestEngine(graph);
    var progress = engine.initialProgress();
    var won = false;

    for (final event in _victoryRoute) {
      final transition = engine.apply(progress, event);
      progress = transition.progress;
      won = won || transition.gameWon;
    }

    expect(won, isTrue);
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
        storyQuestIds: [
          for (var number = 1; number <= 12; number++)
            'quest-${number.toString().padLeft(2, '0')}',
        ],
        statuses: {
          for (var number = 1; number <= 12; number++)
            'quest-${number.toString().padLeft(2, '0')}': QuestStatus.completed,
        },
      ),
      isComplete: true,
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

final _storyQuests = <QuestDefinition>[
  _quest(1, _check('crew-quarters', StatType.science), const ['quest-02']),
  _quest(
    2,
    _check('engineering-control-post', StatType.repair),
    const ['quest-03'],
  ),
  _quest(3, _check('reactor', StatType.repair), const ['quest-04']),
  _quest(
    4,
    _check('medical-bay', StatType.science),
    const ['quest-05', 'quest-06'],
  ),
  _quest(5, _check('laboratory', StatType.science), const ['quest-07']),
  _quest(6, _check('main-computer', StatType.repair), const ['quest-07']),
  _quest(
    7,
    _check('escape-pods', StatType.science),
    const ['quest-08'],
    prerequisites: const ['quest-05', 'quest-06'],
  ),
  _quest(8, _check('storage', StatType.repair), const ['quest-09', 'quest-10']),
  _quest(
    9,
    const [
      QuestCondition(
        id: 'arrive-flight-control',
        type: QuestConditionType.arrive,
        locationId: 'flight-control',
      ),
      QuestCondition(
        id: 'kill-viy',
        type: QuestConditionType.killMonster,
        monsterId: 'viy',
      ),
    ],
    const ['quest-11'],
  ),
  _quest(10, _check('escape-pods', StatType.repair), const ['quest-11']),
  _quest(
    11,
    const [
      QuestCondition(
        id: 'arrive-escape-pods-final',
        type: QuestConditionType.arrive,
        locationId: 'escape-pods',
      ),
      QuestCondition(
        id: 'kill-mother',
        type: QuestConditionType.killMonster,
        monsterId: 'mother',
      ),
    ],
    const ['quest-12'],
    prerequisites: const ['quest-09', 'quest-10'],
  ),
  _quest(12, const [], const [], endsGame: true),
];

QuestDefinition _quest(
  int number,
  List<QuestCondition> conditions,
  List<String> nextQuestIds, {
  List<String> prerequisites = const [],
  bool endsGame = false,
}) => QuestDefinition(
  id: 'quest-${number.toString().padLeft(2, '0')}',
  number: number,
  chapter: number,
  conditions: conditions,
  nextQuestIds: nextQuestIds,
  prerequisites: prerequisites,
  reward: const QuestReward(),
  nameKey: 'quest-$number',
  descKey: 'quest-$number-description',
  endsGame: endsGame,
);

List<QuestCondition> _check(String locationId, StatType stat) => [
  QuestCondition(
    id: 'arrive-$locationId',
    type: QuestConditionType.arrive,
    locationId: locationId,
  ),
  QuestCondition(
    id: 'check-$locationId-${stat.name}',
    type: QuestConditionType.skillCheck,
    locationId: locationId,
    skill: stat,
  ),
];

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
