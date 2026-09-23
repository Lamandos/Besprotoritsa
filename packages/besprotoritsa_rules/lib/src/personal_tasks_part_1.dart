// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'personal_tasks.dart';

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
