// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'quest_engine.dart';

final class QuestEngine {
  const QuestEngine(this.graph);

  final QuestGraph graph;

  QuestProgress initialProgress() => QuestProgress.initial(graph);

  QuestTransition apply(QuestProgress progress, QuestEvent event) {
    final conditionProgress = _copyConditionProgress(
      progress.conditionProgress,
    );
    for (final questId in progress.activeQuestIds) {
      final quest = graph.quest(questId);
      for (final condition in quest.conditions) {
        final increment = _eventIncrement(condition, event);
        if (increment == 0) continue;
        final values = conditionProgress.putIfAbsent(questId, () => {});
        final current = values[condition.id] ?? 0;
        values[condition.id] =
            condition.type == QuestConditionType.arrive ||
                condition.type == QuestConditionType.skillCheck
            ? 1
            : current + increment;
      }
    }
    return _settle(
      QuestProgress(
        activeQuestIds: progress.activeQuestIds,
        completedQuestIds: progress.completedQuestIds,
        conditionProgress: conditionProgress,
      ),
    );
  }

  QuestTransition complete(QuestProgress progress, QuestId questId) {
    if (!progress.isActive(questId)) {
      throw StateError('Quest $questId is not active.');
    }
    final quest = graph.quest(questId);
    if (!_isReady(progress, quest)) {
      throw StateError('Quest $questId conditions are not complete.');
    }
    return _settle(progress, forcedQuestId: questId);
  }

  QuestTransition _settle(QuestProgress progress, {QuestId? forcedQuestId}) {
    var pendingForcedQuestId = forcedQuestId;
    final active = [...progress.activeQuestIds];
    final completed = {...progress.completedQuestIds};
    final completedNow = <QuestId>[];
    final activatedNow = <QuestId>[];
    final rewards = <QuestRewardGrant>[];
    var gameWon = false;

    while (true) {
      QuestDefinition? ready;
      if (pendingForcedQuestId != null &&
          !completed.contains(pendingForcedQuestId)) {
        ready = graph.quest(pendingForcedQuestId);
      } else {
        for (final id in active) {
          if (completed.contains(id)) continue;
          final candidate = graph.quest(id);
          if (_isReady(
            QuestProgress(
              activeQuestIds: active,
              completedQuestIds: completed,
              conditionProgress: progress.conditionProgress,
            ),
            candidate,
          )) {
            ready = candidate;
            break;
          }
        }
      }
      if (ready == null) break;
      pendingForcedQuestId = null;
      active.remove(ready.id);
      completed.add(ready.id);
      completedNow.add(ready.id);
      rewards.add(QuestRewardGrant(questId: ready.id, reward: ready.reward));
      gameWon = gameWon || ready.endsGame;

      for (final nextId in ready.nextQuestIds) {
        if (completed.contains(nextId) || active.contains(nextId)) continue;
        final next = graph.quest(nextId);
        final candidateProgress = QuestProgress(
          activeQuestIds: active,
          completedQuestIds: completed,
          conditionProgress: progress.conditionProgress,
        );
        if (next.prerequisites.every(candidateProgress.isCompleted)) {
          active.add(nextId);
          activatedNow.add(nextId);
        }
      }
    }

    return QuestTransition(
      progress: QuestProgress(
        activeQuestIds: active,
        completedQuestIds: completed,
        conditionProgress: progress.conditionProgress,
      ),
      completedQuestIds: List.unmodifiable(completedNow),
      activatedQuestIds: List.unmodifiable(activatedNow),
      rewards: List.unmodifiable(rewards),
      gameWon: gameWon,
    );
  }

  bool _isReady(QuestProgress progress, QuestDefinition quest) =>
      quest.prerequisites.every(progress.isCompleted) &&
      quest.conditions.every(
        (condition) =>
            progress.valueOf(quest.id, condition.id) >= condition.targetValue,
      );

  int _eventIncrement(QuestCondition condition, QuestEvent event) =>
      switch (event) {
        QuestArrived(:final locationId) =>
          condition.type == QuestConditionType.arrive &&
                  condition.locationId == locationId
              ? 1
              : 0,
        QuestSkillChecked(:final skill, :final locationId, :final success) =>
          condition.type == QuestConditionType.skillCheck &&
                  success &&
                  condition.skill == skill &&
                  condition.locationId == locationId
              ? 1
              : 0,
        QuestMonsterKilled(:final monsterId, :final count) =>
          condition.type == QuestConditionType.killMonster &&
                  condition.monsterId == monsterId
              ? count
              : 0,
        QuestItemCollected(:final itemId, :final count) =>
          condition.type == QuestConditionType.collectItem &&
                  condition.itemId == itemId
              ? count
              : 0,
        QuestCounterIncremented(:final metric, :final amount) =>
          condition.type == QuestConditionType.counter &&
                  condition.metric == metric
              ? amount
              : 0,
      };
}

Map<QuestId, Map<String, int>> _copyConditionProgress(
  Map<QuestId, Map<String, int>> source,
) => {
  for (final entry in source.entries) entry.key: Map.of(entry.value),
};

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Object? value) => value == null
    ? null
    : value is String && value.isNotEmpty
    ? value
    : (throw const FormatException('Expected a non-empty string or null.'));

List<String> _stringList(
  Object? value,
  String key, {
  bool allowNull = false,
}) {
  if (value == null && allowNull) return const [];
  if (value is String) return [value];
  if (value is! List<Object?> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  return List<String>.from(value);
}
