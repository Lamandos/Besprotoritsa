// Static card facts are deliberately data-only. Rules that cannot be expressed
// as a number live in EffectRegistry and are referenced by behaviorIds.
// ignore_for_file: public_member_api_docs

import 'dart:collection';

enum ItemType {
  weapon,
  armor,
  clothing,
  robot,
  modification,
  supply,
  specialItem,
}

enum ItemSlot { weapon, armor, clothing, robot, modification }

enum CardStat { strength, science, repair, endurance, agility, health, defense }

final class CardStaticEffects {
  CardStaticEffects(Map<CardStat, int> modifiers, {this.range})
    : modifiers = UnmodifiableMapView(Map.of(modifiers)) {
    if (range != null && range! < 0) {
      throw ArgumentError.value(range, 'range', 'Must not be negative.');
    }
  }

  factory CardStaticEffects.fromJson(Map<String, Object?> json) {
    final rawModifiers = json['stats'] ?? json['modifiers'] ?? const {};
    if (rawModifiers is! Map<String, Object?>) {
      throw const FormatException('Card stats must be an object.');
    }
    final modifiers = <CardStat, int>{};
    for (final entry in rawModifiers.entries) {
      final stat = _cardStatFromJson(entry.key);
      if (stat == null) continue;
      if (entry.value is! int) {
        throw FormatException('Card stat ${entry.key} must be an integer.');
      }
      modifiers[stat] = entry.value! as int;
    }
    final range = json['range'];
    if (range != null && range is! int) {
      throw const FormatException('Card range must be an integer.');
    }
    return CardStaticEffects(modifiers, range: range as int?);
  }

  final Map<CardStat, int> modifiers;
  final int? range;

  int operator [](CardStat stat) => modifiers[stat] ?? 0;
}

final class CardDefinition {
  CardDefinition({
    required this.id,
    required this.type,
    required Iterable<ItemSlot> slots,
    required this.cost,
    required this.staticEffects,
    Iterable<String> behaviorIds = const [],
  }) : slots = Set.unmodifiable(slots),
       behaviorIds = List.unmodifiable(behaviorIds) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (cost < 0) {
      throw ArgumentError.value(cost, 'cost', 'Must not be negative.');
    }
    if (this.behaviorIds.any((id) => id.isEmpty)) {
      throw ArgumentError.value(
        behaviorIds,
        'behaviorIds',
        'Must not contain empty ids.',
      );
    }
  }

  factory CardDefinition.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final category = _requiredString(json, 'category');
    final type = ItemType.values.byName(category);
    final slots = _slots(json['slots']);
    final cost = json['cost'];
    if (cost is! int) {
      throw const FormatException('Card cost must be an integer.');
    }
    return CardDefinition(
      id: id,
      type: type,
      slots: slots,
      cost: cost,
      staticEffects: CardStaticEffects.fromJson(json),
      behaviorIds: _behaviorIds(json),
    );
  }

  final String id;
  final ItemType type;
  final Set<ItemSlot> slots;
  final int cost;
  final CardStaticEffects staticEffects;
  final List<String> behaviorIds;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Card $key must be a non-empty string.');
  }
  return value;
}

Iterable<ItemSlot> _slots(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Card slots must be an array.');
  }
  return value.map((slot) {
    if (slot is! String) {
      throw const FormatException('Card slot must be a string.');
    }
    return ItemSlot.values.byName(slot);
  });
}

Iterable<String> _behaviorIds(Map<String, Object?> json) {
  final plural = json['behaviorIds'];
  if (plural != null) {
    if (plural is! List<Object?> || plural.any((id) => id is! String)) {
      throw const FormatException(
        'Card behaviorIds must be an array of strings.',
      );
    }
    return plural.cast<String>();
  }
  final singular = json['behaviorId'];
  if (singular == null) return const [];
  if (singular is! String) {
    throw const FormatException('Card behaviorId must be a string.');
  }
  return [singular];
}

CardStat? _cardStatFromJson(String key) => switch (key) {
  'strength' || 'combatStrength' => CardStat.strength,
  'science' => CardStat.science,
  'repair' => CardStat.repair,
  'endurance' => CardStat.endurance,
  'agility' => CardStat.agility,
  'health' => CardStat.health,
  'defense' => CardStat.defense,
  _ => null,
};
