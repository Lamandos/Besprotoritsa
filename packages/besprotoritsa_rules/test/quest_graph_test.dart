import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  late QuestGraph graph;
  late QuestEngine engine;

  setUpAll(() {
    final json = jsonDecode(File('content/quests.json').readAsStringSync());
    graph = QuestGraph.fromJson(Map<String, Object?>.from(json as Map));
    engine = QuestEngine(graph);
  });

  test('loads all 29 quests and keeps several branches active', () {
    expect(graph.quests, hasLength(29));
    var progress = engine.initialProgress();

    progress = _apply(
      engine,
      progress,
      const QuestArrived('crew-quarters'),
    );
    expect(progress.isCompleted('quest-01'), isFalse);
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.science,
        locationId: 'crew-quarters',
        success: true,
      ),
    );

    expect(progress.isCompleted('quest-01'), isTrue);
    expect(
      progress.activeQuestIds,
      containsAll(<String>['quest-02']),
    );

    progress = _apply(
      engine,
      progress,
      const QuestArrived('engineering-control-post'),
    );
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.repair,
        locationId: 'engineering-control-post',
        success: true,
      ),
    );
    expect(
      progress.activeQuestIds,
      containsAll(<String>['quest-03', 'quest-13', 'quest-21']),
    );
  });

  test('does not unlock synchronized branches after only one prerequisite', () {
    var progress = _progressAfter(engine, const [
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
    ]);

    progress = _apply(engine, progress, const QuestArrived('laboratory'));
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.science,
        locationId: 'laboratory',
        success: true,
      ),
    );
    expect(progress.isCompleted('quest-05'), isTrue);
    expect(progress.isActive('quest-07'), isFalse);

    progress = _apply(engine, progress, const QuestArrived('main-computer'));
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.repair,
        locationId: 'main-computer',
        success: true,
      ),
    );
    expect(progress.isCompleted('quest-06'), isTrue);
    expect(progress.isActive('quest-07'), isTrue);
  });

  test('main victory cannot be completed by a false or side-branch event', () {
    var progress = _progressAfter(engine, const [
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
    ]);
    expect(progress.isActive('quest-07'), isTrue);

    progress = _apply(engine, progress, const QuestArrived('escape-pods'));
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.science,
        locationId: 'escape-pods',
        success: false,
      ),
    );
    expect(progress.isCompleted('quest-07'), isFalse);
    expect(progress.isCompleted('quest-12'), isFalse);

    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.science,
        locationId: 'escape-pods',
        success: true,
      ),
    );
    progress = _apply(engine, progress, const QuestArrived('storage'));
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.repair,
        locationId: 'storage',
        success: true,
      ),
    );
    expect(progress.isActive('quest-09'), isTrue);
    expect(progress.isActive('quest-10'), isTrue);

    progress = _apply(engine, progress, const QuestArrived('flight-control'));
    progress = _apply(
      engine,
      progress,
      const QuestMonsterKilled(monsterId: 'ghoul'),
    );
    expect(progress.isCompleted('quest-09'), isFalse);
    expect(progress.isCompleted('quest-12'), isFalse);

    progress = _apply(
      engine,
      progress,
      const QuestMonsterKilled(monsterId: 'viy'),
    );
    progress = _apply(engine, progress, const QuestArrived('escape-pods'));
    progress = _apply(
      engine,
      progress,
      const QuestSkillChecked(
        skill: StatType.repair,
        locationId: 'escape-pods',
        success: true,
      ),
    );
    progress = _apply(engine, progress, const QuestArrived('escape-pods'));
    expect(progress.isCompleted('quest-10'), isTrue);
    expect(progress.isActive('quest-11'), isTrue);
    expect(progress.isCompleted('quest-12'), isFalse);

    progress = _apply(
      engine,
      progress,
      const QuestMonsterKilled(monsterId: 'mother'),
    );
    expect(progress.isCompleted('quest-11'), isTrue);
    expect(progress.isCompleted('quest-12'), isTrue);
    expect(
      engine
          .apply(progress, const QuestCounterIncremented(metric: 'anything'))
          .gameWon,
      isFalse,
    );
  });
}

QuestProgress _progressAfter(QuestEngine engine, Iterable<QuestEvent> events) {
  var progress = engine.initialProgress();
  for (final event in events) {
    progress = _apply(engine, progress, event);
  }
  return progress;
}

QuestProgress _apply(
  QuestEngine engine,
  QuestProgress progress,
  QuestEvent event,
) => engine.apply(progress, event).progress;
