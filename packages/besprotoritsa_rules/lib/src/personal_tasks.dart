import 'dart:collection';

// Personal task cards are intentionally exposed as a small public data API.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

enum PersonalTaskWindow { perTurn, simultaneously, game }

enum PersonalTaskAggregation { sum, maximum }

final class PersonalTaskDefinition {
  const PersonalTaskDefinition({
    required this.id,
    required this.metric,
    required this.targetValue,
    required this.window,
    required this.aggregation,
    required this.rewardCredits,
    required this.nameKey,
    required this.descKey,
  }) : assert(id != '', 'id must not be empty'),
       assert(metric != '', 'metric must not be empty'),
       assert(targetValue > 0, 'targetValue must be positive'),
       assert(rewardCredits >= 0, 'rewardCredits must not be negative');

  factory PersonalTaskDefinition.fromJson(Map<String, Object?> json) {
    final target = json['targetValue'];
    final reward = json['rewardCredits'];
    if (target is! int || target < 1 || reward is! int || reward < 0) {
      throw const FormatException(
        'Task target and reward must be valid integers.',
      );
    }
    final window = switch (_requiredString(json, 'window')) {
      'perTurn' || 'per_turn' || 'turn' => PersonalTaskWindow.perTurn,
      'simultaneously' || 'simultaneous' => PersonalTaskWindow.simultaneously,
      'game' || 'throughout_game' => PersonalTaskWindow.game,
      final value => throw FormatException('Unknown task window: $value.'),
    };
    final aggregation = switch (json['aggregation'] ?? 'sum') {
      'sum' => PersonalTaskAggregation.sum,
      'max' || 'maximum' => PersonalTaskAggregation.maximum,
      final value => throw FormatException('Unknown task aggregation: $value.'),
    };
    return PersonalTaskDefinition(
      id: _requiredString(json, 'id'),
      metric: _requiredString(json, 'metric'),
      targetValue: target,
      window: window,
      aggregation: aggregation,
      rewardCredits: reward,
      nameKey: _requiredString(json, 'nameKey'),
      descKey: _requiredString(json, 'descKey'),
    );
  }

  final String id;
  final String metric;
  final int targetValue;
  final PersonalTaskWindow window;
  final PersonalTaskAggregation aggregation;
  final int rewardCredits;
  final String nameKey;
  final String descKey;
}

final class PersonalTaskCatalog {
  PersonalTaskCatalog({required Iterable<PersonalTaskDefinition> tasks})
    : _tasks = _index(tasks) {
    if (_tasks.isEmpty) throw ArgumentError('Task catalog must not be empty.');
  }

  factory PersonalTaskCatalog.fromJson(Map<String, Object?> json) {
    final rawTasks = json['tasks'] ?? json['entries'];
    if (rawTasks is! List<Object?> ||
        rawTasks.any((task) => task is! Map<String, dynamic>)) {
      throw const FormatException('Task catalog must contain a tasks array.');
    }
    return PersonalTaskCatalog(
      tasks: rawTasks.map((task) {
        if (task is! Map<String, dynamic>) {
          throw const FormatException('Personal task entry must be an object.');
        }
        return PersonalTaskDefinition.fromJson(
          Map<String, Object?>.from(task),
        );
      }),
    );
  }

  final Map<String, PersonalTaskDefinition> _tasks;
  Iterable<PersonalTaskDefinition> get tasks => _tasks.values;
  PersonalTaskDefinition task(String id) =>
      _tasks[id] ??
      (throw ArgumentError.value(id, 'id', 'Unknown personal task id.'));
  PersonalTaskDefinition? operator [](String id) => _tasks[id];

  static Map<String, PersonalTaskDefinition> _index(
    Iterable<PersonalTaskDefinition> tasks,
  ) {
    final result = <String, PersonalTaskDefinition>{};
    for (final task in tasks) {
      if (result.containsKey(task.id)) {
        throw ArgumentError('Duplicate personal task id ${task.id}.');
      }
      result[task.id] = task;
    }
    return UnmodifiableMapView(result);
  }
}

final class PersonalTaskProgress {
  PersonalTaskProgress({
    Map<String, Iterable<String>> assignedTasksByPlayer = const {},
    Map<String, Iterable<String>> completedTasksByPlayer = const {},
    Map<String, Map<String, int>> countersByPlayer = const {},
    Map<String, int> lastTurnByPlayer = const {},
  }) : assignedTasksByPlayer = UnmodifiableMapView({
         for (final entry in assignedTasksByPlayer.entries)
           entry.key: List.unmodifiable(entry.value),
       }),
       completedTasksByPlayer = UnmodifiableMapView({
         for (final entry in completedTasksByPlayer.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       countersByPlayer = UnmodifiableMapView({
         for (final entry in countersByPlayer.entries)
           entry.key: UnmodifiableMapView(Map.of(entry.value)),
       }),
       lastTurnByPlayer = UnmodifiableMapView(Map.of(lastTurnByPlayer));

  final Map<String, List<String>> assignedTasksByPlayer;
  final Map<String, Set<String>> completedTasksByPlayer;
  final Map<String, Map<String, int>> countersByPlayer;
  final Map<String, int> lastTurnByPlayer;

  bool isAssigned(String playerId, String taskId) =>
      assignedTasksByPlayer[playerId]?.contains(taskId) ?? false;
  bool isCompleted(String playerId, String taskId) =>
      completedTasksByPlayer[playerId]?.contains(taskId) ?? false;
  int valueOf(String playerId, String taskId) =>
      countersByPlayer[playerId]?[taskId] ?? 0;
}

final class PersonalTaskEvent {
  const PersonalTaskEvent({
    required this.playerId,
    required this.metric,
    this.amount = 1,
    this.value,
    this.simultaneousValue,
    this.turn,
    this.qualifies = true,
  }) : assert(amount > 0, 'amount must be positive');

  final String playerId;
  final String metric;
  final int amount;
  final int? value;
  final int? simultaneousValue;
  final int? turn;
  final bool qualifies;
}

final class PersonalTaskCompletion {
  const PersonalTaskCompletion({
    required this.playerId,
    required this.taskId,
    required this.rewardCredits,
  });

  final String playerId;
  final String taskId;
  final int rewardCredits;
}

final class PersonalTaskTransition {
  const PersonalTaskTransition({
    required this.progress,
    required this.completed,
  });

  final PersonalTaskProgress progress;
  final List<PersonalTaskCompletion> completed;
}

final class PersonalTaskEngine {
  const PersonalTaskEngine(this.catalog);

  final PersonalTaskCatalog catalog;

  PersonalTaskProgress assign(
    PersonalTaskProgress progress,
    String playerId,
    Iterable<String> taskIds,
  ) {
    final ids = List<String>.of(taskIds);
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      throw ArgumentError('A player must receive one or more unique tasks.');
    }
    for (final id in ids) {
      catalog.task(id);
      if (progress.assignedTasksByPlayer.values.any(
        (tasks) => tasks.contains(id),
      )) {
        throw ArgumentError('Task $id is already assigned.');
      }
    }
    final assigned = {
      ...progress.assignedTasksByPlayer,
      playerId: ids,
    };
    return PersonalTaskProgress(
      assignedTasksByPlayer: assigned,
      completedTasksByPlayer: progress.completedTasksByPlayer,
      countersByPlayer: progress.countersByPlayer,
      lastTurnByPlayer: progress.lastTurnByPlayer,
    );
  }

  PersonalTaskProgress assignTwo(
    PersonalTaskProgress progress,
    String playerId,
    String firstTaskId,
    String secondTaskId,
  ) => assign(progress, playerId, [firstTaskId, secondTaskId]);

  PersonalTaskTransition record(
    PersonalTaskProgress progress,
    PersonalTaskEvent event,
  ) {
    final assigned = progress.assignedTasksByPlayer[event.playerId];
    if (assigned == null) {
      return PersonalTaskTransition(progress: progress, completed: const []);
    }

    final counters = {
      for (final entry in progress.countersByPlayer.entries)
        entry.key: Map<String, int>.of(entry.value),
    };
    final completed = {
      for (final entry in progress.completedTasksByPlayer.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final lastTurns = Map<String, int>.of(progress.lastTurnByPlayer);
    if (event.turn != null && lastTurns[event.playerId] != event.turn) {
      lastTurns[event.playerId] = event.turn!;
      for (final taskId in assigned) {
        if (catalog.task(taskId).window == PersonalTaskWindow.perTurn) {
          counters.putIfAbsent(event.playerId, () => {}).remove(taskId);
        }
      }
    }

    final playerCounters = counters.putIfAbsent(event.playerId, () => {});
    final playerCompleted = completed.putIfAbsent(event.playerId, () => {});
    final newlyCompleted = <PersonalTaskCompletion>[];
    for (final taskId in assigned) {
      if (playerCompleted.contains(taskId)) continue;
      final task = catalog.task(taskId);
      if (task.metric != event.metric || !event.qualifies) continue;
      final observed = switch (task.window) {
        PersonalTaskWindow.perTurn => event.amount,
        PersonalTaskWindow.simultaneously =>
          event.simultaneousValue ?? event.value ?? event.amount,
        PersonalTaskWindow.game => event.value ?? event.amount,
      };
      final previous = playerCounters[taskId] ?? 0;
      final nextValue = task.aggregation == PersonalTaskAggregation.maximum
          ? (previous > observed ? previous : observed)
          : previous + observed;
      playerCounters[taskId] = nextValue;
      if (nextValue >= task.targetValue) {
        playerCompleted.add(taskId);
        newlyCompleted.add(
          PersonalTaskCompletion(
            playerId: event.playerId,
            taskId: taskId,
            rewardCredits: task.rewardCredits,
          ),
        );
      }
    }
    return PersonalTaskTransition(
      progress: PersonalTaskProgress(
        assignedTasksByPlayer: progress.assignedTasksByPlayer,
        completedTasksByPlayer: completed,
        countersByPlayer: counters,
        lastTurnByPlayer: lastTurns,
      ),
      completed: List.unmodifiable(newlyCompleted),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}
