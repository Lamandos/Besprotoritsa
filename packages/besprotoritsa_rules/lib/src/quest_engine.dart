import 'dart:collection';

import 'package:besprotoritsa_rules/src/combat_models.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';

// Quest content is intentionally exposed as a small public data API.
// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

enum QuestConditionType {
  arrive,
  skillCheck,
  killMonster,
  collectItem,
  counter,
}

final class QuestCondition {
  const QuestCondition({
    required this.id,
    required this.type,
    this.locationId,
    this.skill,
    this.monsterId,
    this.itemId,
    this.metric,
    this.targetValue = 1,
  }) : assert(id != '', 'id must not be empty'),
       assert(targetValue > 0, 'targetValue must be positive');

  factory QuestCondition.fromJson(Map<String, Object?> json) {
    final typeValue = _requiredString(json, 'type');
    final type = switch (typeValue) {
      'arrive' || 'arrival' || 'location' => QuestConditionType.arrive,
      'skillCheck' || 'skill_check' || 'skill' => QuestConditionType.skillCheck,
      'killMonster' ||
      'kill_monster' ||
      'monster' => QuestConditionType.killMonster,
      'collectItem' ||
      'collect_item' ||
      'item' => QuestConditionType.collectItem,
      'counter' || 'count' => QuestConditionType.counter,
      _ => throw FormatException('Unknown quest condition type: $typeValue.'),
    };
    final target = json['targetValue'] ?? json['count'] ?? json['amount'] ?? 1;
    if (target is! int || target < 1) {
      throw const FormatException(
        'Quest condition targetValue must be positive.',
      );
    }
    final skillName = _optionalString(json['skill']);
    final skill = skillName == null ? null : StatType.values.byName(skillName);
    return QuestCondition(
      id: _requiredString(json, 'id'),
      type: type,
      locationId: _optionalString(json['locationId']),
      skill: skill,
      monsterId: _optionalString(json['monsterId']),
      itemId: _optionalString(json['itemId']),
      metric: _optionalString(json['metric']),
      targetValue: target,
    );
  }

  final String id;
  final QuestConditionType type;
  final String? locationId;
  final StatType? skill;
  final String? monsterId;
  final String? itemId;
  final String? metric;
  final int targetValue;
}

final class QuestReward {
  const QuestReward({this.credits = 0, this.items = const []})
    : assert(credits >= 0, 'credits must not be negative');

  factory QuestReward.fromJson(Map<String, Object?> json) {
    final credits = json['credits'] ?? 0;
    final items = json['items'] ?? const <Object?>[];
    if (credits is! int || credits < 0) {
      throw const FormatException('Quest reward credits must be non-negative.');
    }
    if (items is! List<Object?> || items.any((item) => item is! String)) {
      throw const FormatException('Quest reward items must be strings.');
    }
    return QuestReward(
      credits: credits,
      items: List<String>.from(items),
    );
  }

  final int credits;
  final List<String> items;
}

final class QuestDefinition {
  QuestDefinition({
    required this.id,
    required this.number,
    required this.chapter,
    required Iterable<QuestCondition> conditions,
    required Iterable<QuestId> nextQuestIds,
    required this.reward,
    required this.nameKey,
    required this.descKey,
    this.targetLocation,
    Iterable<QuestId> prerequisites = const [],
    this.endsGame = false,
  }) : conditions = List.unmodifiable(conditions),
       nextQuestIds = List.unmodifiable(nextQuestIds),
       prerequisites = List.unmodifiable(prerequisites) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Must not be empty.');
    if (number < 1 || chapter < 0) {
      throw ArgumentError(
        'Quest number must be positive and chapter non-negative.',
      );
    }
    if (conditions.map((condition) => condition.id).toSet().length !=
        this.conditions.length) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'Ids must be unique.',
      );
    }
  }

  factory QuestDefinition.fromJson(Map<String, Object?> json) {
    final rawConditions = json['conditions'] ?? const <Object?>[];
    if (rawConditions is! List<Object?> ||
        rawConditions.any((condition) => condition is! Map<String, dynamic>)) {
      throw const FormatException(
        'Quest conditions must be an array of objects.',
      );
    }
    final rawReward = json['reward'] ?? const <String, Object?>{};
    if (rawReward is! Map<String, dynamic>) {
      throw const FormatException('Quest reward must be an object.');
    }
    final number = json['number'] ?? json['questNumber'] ?? 0;
    final chapter = json['chapter'] ?? 1;
    if (number is! int || chapter is! int) {
      throw const FormatException('Quest number and chapter must be integers.');
    }
    return QuestDefinition(
      id: _requiredString(json, 'id'),
      number: number,
      chapter: chapter,
      targetLocation: _optionalString(json['targetLocation']),
      conditions: rawConditions.map((condition) {
        if (condition is! Map<String, dynamic>) {
          throw const FormatException('Quest condition must be an object.');
        }
        return QuestCondition.fromJson(Map<String, Object?>.from(condition));
      }),
      reward: QuestReward.fromJson(
        Map<String, Object?>.from(rawReward),
      ),
      nextQuestIds: _stringList(json['nextQuestIds'], 'nextQuestIds'),
      prerequisites: _stringList(
        json['prerequisiteQuestIds'] ?? json['prerequisites'],
        'prerequisiteQuestIds',
        allowNull: true,
      ),
      endsGame: json['endsGame'] as bool? ?? false,
      nameKey: _requiredString(json, 'nameKey'),
      descKey: _requiredString(json, 'descKey'),
    );
  }

  final QuestId id;
  final int number;
  final int chapter;
  final String? targetLocation;
  final List<QuestCondition> conditions;
  final List<QuestId> nextQuestIds;
  final List<QuestId> prerequisites;
  final QuestReward reward;
  final String nameKey;
  final String descKey;
  final bool endsGame;
}

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
