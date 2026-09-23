part of 'save_json_models.dart';

// Helper conversions are documented by the public codec that owns them.
// ignore_for_file: public_member_api_docs

abstract final class SaveJsonEventModels {
  static Map<String, Object?> toJson(GameEvent event) => switch (event) {
    HexEntered() => {
      'type': 'hex_entered',
      'player_id': event.playerId,
      'from': _coordToJson(event.from),
      'to': _coordToJson(event.to),
    },
    ColocationTriggered() => {
      'type': 'colocation_triggered',
      'player_id': event.playerId,
      'coord': _coordToJson(event.coord),
    },
    DamageDealt() => {
      'type': 'damage_dealt',
      'player_id': event.playerId,
      'amount': event.amount,
    },
    ConditionDrawn() => {
      'type': 'condition_drawn',
      'player_id': event.playerId,
      'condition_id': event.conditionId,
    },
    MvpDemonstrationCompleted() => {
      'type': 'mvp_demonstration_completed',
      'quest_id': event.questId,
      'player_id': event.playerId,
    },
    HeroDied() => {
      'type': 'hero_died',
      'player_id': event.playerId,
      'restless_instance_id': event.restlessInstanceId,
      'coord': _coordToJson(event.coord),
    },
  };

  static GameEvent fromJson(Map<String, Object?> json) =>
      switch (_string(json, 'type')) {
        'hex_entered' => HexEntered(
          playerId: _string(json, 'player_id'),
          from: _coordFromJson(_object(json, 'from')),
          to: _coordFromJson(_object(json, 'to')),
        ),
        'colocation_triggered' => ColocationTriggered(
          playerId: _string(json, 'player_id'),
          coord: _coordFromJson(_object(json, 'coord')),
        ),
        'damage_dealt' => DamageDealt(
          playerId: _string(json, 'player_id'),
          amount: _int(json, 'amount'),
        ),
        'condition_drawn' => ConditionDrawn(
          playerId: _string(json, 'player_id'),
          conditionId: _string(json, 'condition_id'),
        ),
        'mvp_demonstration_completed' => MvpDemonstrationCompleted(
          questId: _string(json, 'quest_id'),
          playerId: _string(json, 'player_id'),
        ),
        'hero_died' => HeroDied(
          playerId: _string(json, 'player_id'),
          restlessInstanceId: _string(json, 'restless_instance_id'),
          coord: _coordFromJson(_object(json, 'coord')),
        ),
        final type => throw FormatException('Unknown game event type: $type.'),
      };
}

Map<String, Object?> _coordToJson(HexCoord coord) => {
  'q': coord.q,
  'r': coord.r,
};

HexCoord _coordFromJson(Map<String, Object?> json) =>
    HexCoord(_int(json, 'q'), _int(json, 'r'));

Map<String, Object?> _statsToJson(PlayerStats stats) => {
  'strength': stats.strength,
  'combat_strength': stats.combatStrength,
  'science': stats.science,
  'repair': stats.repair,
  'endurance': stats.endurance,
  'agility': stats.agility,
};

PlayerStats _statsFromJson(Map<String, Object?> json) => PlayerStats(
  strength: _int(json, 'strength'),
  combatStrength: _int(json, 'combat_strength'),
  science: _int(json, 'science'),
  repair: _int(json, 'repair'),
  endurance: _int(json, 'endurance'),
  agility: _int(json, 'agility'),
);

Map<String, Object?>? _contextToJson(RollContext? context) => switch (context) {
  null => null,
  SkillCheckContext() => {
    'type': 'skill',
    'player_id': context.playerId,
    'stat': context.stat.name,
    'difficulty': context.difficulty,
    'event_id': context.eventId,
    'quest_id': context.questId,
  },
  AttackRollContext() => {
    'type': 'attack',
    'player_id': context.playerId,
    'target_instance_id': context.targetInstanceId,
    'pre_attack_damage': context.preAttackDamage,
  },
};

RollContext? _contextFromJson(Object? value) {
  if (value == null) return null;
  final json = _asObject(value, 'pending_decision.context');
  return switch (json['type']) {
    'attack' => AttackRollContext(
      playerId: _string(json, 'player_id'),
      targetInstanceId: _string(json, 'target_instance_id'),
      preAttackDamage: _optionalInt(json, 'pre_attack_damage') ?? 0,
    ),
    'skill' || null => SkillCheckContext(
      playerId: _string(json, 'player_id'),
      stat: _enum(StatType.values, _string(json, 'stat'), 'stat'),
      difficulty: _int(json, 'difficulty'),
      eventId: _nullableString(json['event_id'], 'event_id'),
      questId: _nullableString(json['quest_id'], 'quest_id'),
    ),
    final type => throw FormatException('Unknown reroll context type: $type.'),
  };
}

E _enum<E extends Enum>(List<E> values, String name, String key) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $key enum value: $name.');
}

Map<String, Object?> _object(Map<String, Object?> json, String key) =>
    _asObject(json[key], key);

Map<String, Object?> _asObject(Object? value, String key) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return Map<String, Object?>.from(value);
}

String _string(Map<String, Object?> json, String key) =>
    _asString(json[key], key);

String _asString(Object? value, String key) {
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

String? _nullableString(Object? value, String key) {
  if (value == null || value is String) return value as String?;
  throw FormatException('$key must be a string or null.');
}

int _int(Map<String, Object?> json, String key) => _asInt(json[key], key);

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _asInt(value, key);
}

int _asInt(Object? value, String key) {
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

bool _boolOrDefault(Object? value, String key, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<String> _strings(Map<String, Object?> json, String key) =>
    _stringsFromValue(json[key], key);

List<String> _stringsFromValue(Object? value, String key) {
  if (value is! List<dynamic> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  return List<String>.from(value);
}

List<int> _ints(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<dynamic> || value.any((entry) => entry is! int)) {
    throw FormatException('$key must be an array of integers.');
  }
  return List<int>.from(value);
}
