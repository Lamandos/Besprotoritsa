part of 'inventory_rules.dart';

abstract final class _InventoryStats {
  static const String _extraWeaponSlot = 'equipment.extraWeaponSlot';
  static const String _extraBackpackCapacity =
      'equipment.extraBackpackCapacity';

  static Iterable<CardId> activeCardIds(PlayerState player) sync* {
    yield* player.equipped.weapons;
    for (final cardId in [
      player.equipped.armor,
      player.equipped.clothing,
      player.equipped.robot,
    ]) {
      if (cardId != null) yield cardId;
    }
    yield* player.implanted;
  }

  static int backpackCapacity(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _hasBehavior(player, definitions, _extraBackpackCapacity)
      ? InventoryRules.expandedBackpackCapacity
      : InventoryRules.baseBackpackCapacity;

  static int weaponCapacity(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _hasBehavior(player, definitions, _extraWeaponSlot) ? 2 : 1;

  static EffectivePlayerStats effectiveStats(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) {
    var health = player.health;
    var strength = player.stats.strength;
    var science = player.stats.science;
    var repair = player.stats.repair;
    var endurance = player.stats.endurance;
    var agility = player.stats.agility;
    for (final id in activeCardIds(player)) {
      final effects = definitions[id]?.staticEffects;
      if (effects == null) continue;
      health += effects[CardStat.health];
      strength += effects[CardStat.strength];
      science += effects[CardStat.science];
      repair += effects[CardStat.repair];
      endurance += effects[CardStat.endurance];
      agility += effects[CardStat.agility];
    }
    return EffectivePlayerStats(
      health: health,
      strength: strength,
      combatStrength:
          player.stats.combatStrength + strength - player.stats.strength,
      science: science,
      repair: repair,
      endurance: endurance,
      agility: agility,
    );
  }

  static bool _hasBehavior(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
    String behaviorId,
  ) => activeCardIds(player).any(
    (id) => definitions[id]?.behaviorIds.contains(behaviorId) ?? false,
  );
}
