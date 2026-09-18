// Combat data is intentionally content-agnostic: the data package maps card
// definitions onto these small, deterministic rule-model values.
// ignore_for_file: public_member_api_docs

import 'dart:collection';

import 'package:meta/meta.dart';

enum StatType { strength, combatStrength, science, repair, endurance, agility }

@immutable
final class PlayerStats {
  const PlayerStats({
    this.strength = 0,
    this.combatStrength = 0,
    this.science = 0,
    this.repair = 0,
    this.endurance = 0,
    this.agility = 0,
  }) : assert(strength >= 0, 'strength must not be negative'),
       assert(combatStrength >= 0, 'combatStrength must not be negative'),
       assert(science >= 0, 'science must not be negative'),
       assert(repair >= 0, 'repair must not be negative'),
       assert(endurance >= 0, 'endurance must not be negative'),
       assert(agility >= 0, 'agility must not be negative');

  final int strength;
  final int combatStrength;
  final int science;
  final int repair;
  final int endurance;
  final int agility;

  int valueFor(StatType stat) => switch (stat) {
    StatType.strength => strength,
    StatType.combatStrength => combatStrength,
    StatType.science => science,
    StatType.repair => repair,
    StatType.endurance => endurance,
    StatType.agility => agility,
  };
}

@immutable
final class ConditionCard {
  ConditionCard({required this.id, Map<StatType, int> statModifiers = const {}})
    : statModifiers = UnmodifiableMapView(Map.of(statModifiers)) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
  }

  final String id;
  final Map<StatType, int> statModifiers;
}

enum DamageSource { monster, boil }

/// Damage which must be resolved after the current dodge decision, if any.
@immutable
final class IncomingDamage {
  const IncomingDamage({
    required this.targetPlayerId,
    required this.amount,
    required this.agilityDice,
    required this.source,
  }) : assert(targetPlayerId != '', 'targetPlayerId must not be empty'),
       assert(amount >= 0, 'amount must not be negative'),
       assert(agilityDice >= 1, 'agilityDice must be at least one');

  final String targetPlayerId;
  final int amount;
  final int agilityDice;
  final DamageSource source;
}
