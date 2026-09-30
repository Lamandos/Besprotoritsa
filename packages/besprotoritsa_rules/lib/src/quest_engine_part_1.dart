// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'quest_engine.dart';

enum QuestConditionType {
  arrive,
  skillCheck,
  killMonster,
  collectItem,
  equippedForBattle,
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
      'equippedForBattle' ||
      'equipped_for_battle' => QuestConditionType.equippedForBattle,
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
  const QuestReward({
    this.credits = 0,
    this.items = const [],
    this.drawItems = 0,
    this.drawItemsPerPlayerAtTargetLocation = 0,
    this.drawSuppliesPerPlayer = 0,
    this.creditRollDicePerPlayer = 0,
  }) : assert(credits >= 0, 'credits must not be negative'),
       assert(drawItems >= 0, 'drawItems must not be negative'),
       assert(
         drawItemsPerPlayerAtTargetLocation >= 0,
         'drawItemsPerPlayerAtTargetLocation must not be negative',
       ),
       assert(
         drawSuppliesPerPlayer >= 0,
         'drawSuppliesPerPlayer must not be negative',
       ),
       assert(
         creditRollDicePerPlayer >= 0,
         'creditRollDicePerPlayer must not be negative',
       );

  factory QuestReward.fromJson(Map<String, Object?> json) {
    final credits = json['credits'] ?? 0;
    final items = json['items'] ?? const <Object?>[];
    final drawItems = json['drawItems'] ?? 0;
    final drawItemsPerPlayerAtTargetLocation =
        json['drawItemsPerPlayerAtTargetLocation'] ?? 0;
    final drawSuppliesPerPlayer = json['drawSuppliesPerPlayer'] ?? 0;
    final creditRollDicePerPlayer = json['creditRollDicePerPlayer'] ?? 0;
    if (credits is! int || credits < 0) {
      throw const FormatException('Quest reward credits must be non-negative.');
    }
    if (items is! List<Object?> || items.any((item) => item is! String)) {
      throw const FormatException('Quest reward items must be strings.');
    }
    if ([
      drawItems,
      drawItemsPerPlayerAtTargetLocation,
      drawSuppliesPerPlayer,
      creditRollDicePerPlayer,
    ].any((value) => value is! int || value < 0)) {
      throw const FormatException(
        'Quest reward counts must be non-negative integers.',
      );
    }
    return QuestReward(
      credits: credits,
      items: List<String>.from(items),
      drawItems: drawItems as int,
      drawItemsPerPlayerAtTargetLocation:
          drawItemsPerPlayerAtTargetLocation as int,
      drawSuppliesPerPlayer: drawSuppliesPerPlayer as int,
      creditRollDicePerPlayer: creditRollDicePerPlayer as int,
    );
  }

  final int credits;
  final List<String> items;
  final int drawItems;
  final int drawItemsPerPlayerAtTargetLocation;
  final int drawSuppliesPerPlayer;
  final int creditRollDicePerPlayer;
}

final class QuestCompletionEffect {
  const QuestCompletionEffect.damageAllPlayersIfQuestActive({
    required this.questId,
    required this.amount,
  });

  factory QuestCompletionEffect.fromJson(Map<String, Object?> json) {
    if (json['type'] != 'damage_all_players_if_quest_active') {
      throw FormatException(
        'Unknown quest completion effect: ${json['type']}.',
      );
    }
    final amount = json['amount'];
    if (amount is! int || amount < 1) {
      throw const FormatException(
        'Quest completion damage must be a positive integer.',
      );
    }
    return QuestCompletionEffect.damageAllPlayersIfQuestActive(
      questId: _requiredString(json, 'questId'),
      amount: amount,
    );
  }

  final QuestId questId;
  final int amount;
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
    Iterable<QuestId> discardQuestIds = const [],
    this.targetLocation,
    this.spawnMonsterId,
    this.spawnLocationId,
    Iterable<QuestId> prerequisites = const [],
    Iterable<QuestCompletionEffect> completionEffects = const [],
    this.endsGame = false,
  }) : conditions = List.unmodifiable(conditions),
       nextQuestIds = List.unmodifiable(nextQuestIds),
       discardQuestIds = List.unmodifiable(discardQuestIds),
       prerequisites = List.unmodifiable(prerequisites),
       completionEffects = List.unmodifiable(completionEffects) {
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
    final rawEffects = json['completionEffects'] ?? const <Object?>[];
    if (rawEffects is! List<Object?> ||
        rawEffects.any((effect) => effect is! Map<String, dynamic>)) {
      throw const FormatException(
        'Quest completionEffects must be an array of objects.',
      );
    }
    if (number is! int || chapter is! int) {
      throw const FormatException('Quest number and chapter must be integers.');
    }
    return QuestDefinition(
      id: _requiredString(json, 'id'),
      number: number,
      chapter: chapter,
      targetLocation: _optionalString(json['targetLocation']),
      spawnMonsterId: _optionalString(json['spawnMonsterId']),
      spawnLocationId: _optionalString(json['spawnLocationId']),
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
      discardQuestIds: _stringList(
        json['discardQuestIds'],
        'discardQuestIds',
        allowNull: true,
      ),
      prerequisites: _stringList(
        json['prerequisiteQuestIds'] ?? json['prerequisites'],
        'prerequisiteQuestIds',
        allowNull: true,
      ),
      completionEffects: rawEffects.map((effect) {
        if (effect is! Map<String, dynamic>) {
          throw const FormatException(
            'Quest completion effect must be an object.',
          );
        }
        return QuestCompletionEffect.fromJson(
          Map<String, Object?>.from(effect),
        );
      }),
      endsGame: json['endsGame'] as bool? ?? false,
      nameKey: _requiredString(json, 'nameKey'),
      descKey: _requiredString(json, 'descKey'),
    );
  }

  final QuestId id;
  final int number;
  final int chapter;
  final String? targetLocation;
  final String? spawnMonsterId;
  final String? spawnLocationId;
  final List<QuestCondition> conditions;
  final List<QuestId> nextQuestIds;
  final List<QuestId> discardQuestIds;
  final List<QuestId> prerequisites;
  final List<QuestCompletionEffect> completionEffects;
  final QuestReward reward;
  final String nameKey;
  final String descKey;
  final bool endsGame;
}
