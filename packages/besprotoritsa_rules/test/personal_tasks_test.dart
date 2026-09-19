import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  late PersonalTaskCatalog catalog;
  late PersonalTaskEngine engine;

  setUpAll(() {
    final json = jsonDecode(File('content/tasks.json').readAsStringSync());
    catalog = PersonalTaskCatalog.fromJson(
      Map<String, Object?>.from(json as Map),
    );
    engine = PersonalTaskEngine(catalog);
  });

  test(
    'loads all private task cards and assigns them without revealing others',
    () {
      expect(catalog.tasks, hasLength(16));
      var progress = PersonalTaskProgress();
      progress = engine.assignTwo(progress, 'ada', 'hunter', 'lucky');
      progress = engine.assignTwo(progress, 'boris', 'agile', 'wealthy');

      expect(progress.assignedTasksByPlayer['ada'], ['hunter', 'lucky']);
      expect(progress.assignedTasksByPlayer['boris'], ['agile', 'wealthy']);
      expect(progress.assignedTasksByPlayer['ada'], isNot(contains('wealthy')));
    },
  );

  test(
    'per-turn and simultaneous counters reset or complete in the right window',
    () {
      var progress = PersonalTaskProgress();
      progress = engine.assignTwo(progress, 'ada', 'hunter', 'abscessive');

      var transition = engine.record(
        progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'enemies_killed',
          turn: 1,
        ),
      );
      progress = transition.progress;
      expect(transition.completed, isEmpty);

      transition = engine.record(
        progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'enemies_killed',
          turn: 1,
        ),
      );
      progress = transition.progress;
      expect(transition.completed.single.taskId, 'hunter');
      expect(transition.completed.single.rewardCredits, 5);

      transition = engine.record(
        progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'enemies_killed',
          turn: 2,
        ),
      );
      expect(transition.completed, isEmpty);

      transition = engine.record(
        progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'boils_popped',
          simultaneousValue: 5,
        ),
      );
      expect(transition.completed, isEmpty);
      transition = engine.record(
        transition.progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'boils_popped',
          simultaneousValue: 6,
        ),
      );
      expect(transition.completed.single.taskId, 'abscessive');

      // A completed card cannot pay its reward a second time.
      transition = engine.record(
        transition.progress,
        const PersonalTaskEvent(
          playerId: 'ada',
          metric: 'boils_popped',
          simultaneousValue: 8,
        ),
      );
      expect(transition.completed, isEmpty);
    },
  );
}
