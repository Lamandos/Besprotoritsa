// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'quest_engine.dart';

final class QuestGraph {
  QuestGraph({
    required Iterable<QuestDefinition> quests,
    Iterable<QuestId>? initialQuestIds,
  }) : _quests = _indexQuests(quests) {
    if (_quests.isEmpty) throw ArgumentError('Quest graph must not be empty.');
    for (final quest in _quests.values) {
      for (final nextId in quest.nextQuestIds) {
        if (!_quests.containsKey(nextId)) {
          throw ArgumentError(
            'Quest ${quest.id} references unknown quest $nextId.',
          );
        }
      }
      for (final prerequisite in quest.prerequisites) {
        if (!_quests.containsKey(prerequisite)) {
          throw ArgumentError(
            'Quest ${quest.id} references unknown prerequisite $prerequisite.',
          );
        }
      }
    }
    final declaredInitialQuestIds = initialQuestIds;
    final List<QuestId> resolvedInitialQuestIds;
    if (declaredInitialQuestIds == null || declaredInitialQuestIds.isEmpty) {
      final numbered = _quests.values.where((quest) => quest.number == 1);
      if (numbered.length != 1) {
        throw ArgumentError(
          'Quest graph must declare exactly one initial quest.',
        );
      }
      resolvedInitialQuestIds = [numbered.single.id];
    } else {
      resolvedInitialQuestIds = List.of(declaredInitialQuestIds);
    }
    this.initialQuestIds = List.unmodifiable(resolvedInitialQuestIds);
    if (this.initialQuestIds.any((id) => !_quests.containsKey(id))) {
      throw ArgumentError('Initial quest ids must exist in the graph.');
    }
  }

  factory QuestGraph.fromJson(Map<String, Object?> json) {
    final rawQuests = json['quests'] ?? json['entries'];
    if (rawQuests is! List<Object?> ||
        rawQuests.any((quest) => quest is! Map<String, dynamic>)) {
      throw const FormatException('Quest graph must contain a quests array.');
    }
    final initial = _stringList(
      json['initialQuestIds'] ?? json['initialQuestId'],
      'initialQuestIds',
      allowNull: true,
    );
    return QuestGraph(
      quests: rawQuests.map(
        (quest) {
          if (quest is! Map<String, dynamic>) {
            throw const FormatException('Quest entry must be an object.');
          }
          return QuestDefinition.fromJson(Map<String, Object?>.from(quest));
        },
      ),
      initialQuestIds: initial,
    );
  }

  final Map<QuestId, QuestDefinition> _quests;
  late final List<QuestId> initialQuestIds;

  Iterable<QuestDefinition> get quests => _quests.values;
  QuestDefinition quest(QuestId id) =>
      _quests[id] ?? (throw ArgumentError.value(id, 'id', 'Unknown quest id.'));
  QuestDefinition? operator [](QuestId id) => _quests[id];

  static Map<QuestId, QuestDefinition> _indexQuests(
    Iterable<QuestDefinition> quests,
  ) {
    final result = <QuestId, QuestDefinition>{};
    for (final quest in quests) {
      if (result.containsKey(quest.id)) {
        throw ArgumentError('Duplicate quest id ${quest.id}.');
      }
      result[quest.id] = quest;
    }
    return UnmodifiableMapView(result);
  }
}

final class QuestProgress {
  QuestProgress({
    required Iterable<QuestId> activeQuestIds,
    Iterable<QuestId> completedQuestIds = const [],
    Map<QuestId, Map<String, int>> conditionProgress = const {},
  }) : activeQuestIds = List.unmodifiable(activeQuestIds),
       completedQuestIds = Set.unmodifiable(completedQuestIds),
       conditionProgress = UnmodifiableMapView({
         for (final entry in conditionProgress.entries)
           entry.key: UnmodifiableMapView(Map.of(entry.value)),
       }) {
    if (this.activeQuestIds.toSet().length != this.activeQuestIds.length) {
      throw ArgumentError('Active quest ids must be unique.');
    }
    if (this.activeQuestIds.any(this.completedQuestIds.contains)) {
      throw ArgumentError('A quest cannot be active and completed.');
    }
  }

  factory QuestProgress.initial(QuestGraph graph) => QuestProgress(
    activeQuestIds: graph.initialQuestIds,
  );

  final List<QuestId> activeQuestIds;
  final Set<QuestId> completedQuestIds;
  final Map<QuestId, Map<String, int>> conditionProgress;

  bool isActive(QuestId id) => activeQuestIds.contains(id);
  bool isCompleted(QuestId id) => completedQuestIds.contains(id);

  int valueOf(QuestId questId, String conditionId) =>
      conditionProgress[questId]?[conditionId] ?? 0;
}

sealed class QuestEvent {
  const QuestEvent();
}

final class QuestArrived extends QuestEvent {
  const QuestArrived(this.locationId);
  final String locationId;
}

final class QuestSkillChecked extends QuestEvent {
  const QuestSkillChecked({
    required this.skill,
    required this.locationId,
    required this.success,
  });
  final StatType skill;
  final String locationId;
  final bool success;
}

final class QuestMonsterKilled extends QuestEvent {
  const QuestMonsterKilled({required this.monsterId, this.count = 1});
  final String monsterId;
  final int count;
}

final class QuestItemCollected extends QuestEvent {
  const QuestItemCollected({required this.itemId, this.count = 1});
  final String itemId;
  final int count;
}

final class QuestCounterIncremented extends QuestEvent {
  const QuestCounterIncremented({required this.metric, this.amount = 1});
  final String metric;
  final int amount;
}

final class QuestRewardGrant {
  const QuestRewardGrant({required this.questId, required this.reward});
  final QuestId questId;
  final QuestReward reward;
}

final class QuestTransition {
  const QuestTransition({
    required this.progress,
    required this.completedQuestIds,
    required this.activatedQuestIds,
    required this.rewards,
    required this.gameWon,
  });

  final QuestProgress progress;
  final List<QuestId> completedQuestIds;
  final List<QuestId> activatedQuestIds;
  final List<QuestRewardGrant> rewards;
  final bool gameWon;
}
