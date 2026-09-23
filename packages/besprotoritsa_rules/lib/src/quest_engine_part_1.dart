// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'quest_engine.dart';

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
