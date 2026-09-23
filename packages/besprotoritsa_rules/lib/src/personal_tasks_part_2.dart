// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'personal_tasks.dart';

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
