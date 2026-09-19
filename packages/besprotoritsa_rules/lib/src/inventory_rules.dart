// Inventory transitions are kept separate from the turn reducer so callers
// can use the same rules for rewards, trading, shops, and setup.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/card_definition.dart';
import 'package:besprotoritsa_rules/src/combat_models.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';

/// The result of applying all equipped and implanted static modifiers.
final class EffectivePlayerStats {
  const EffectivePlayerStats({
    required this.health,
    required this.strength,
    required this.combatStrength,
    required this.science,
    required this.repair,
    required this.endurance,
    required this.agility,
  });

  final int health;
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

/// Returned when a card cannot be put into the backpack immediately.
final class BackpackCapacityExceeded implements Exception {
  BackpackCapacityExceeded(this.capacity);

  final int capacity;

  @override
  String toString() => 'BackpackCapacityExceeded(capacity: $capacity)';
}

/// Returned for attempts to use an unavailable equipment slot or zone.
final class InventoryRuleViolation implements Exception {
  InventoryRuleViolation(this.message);

  final String message;

  @override
  String toString() => 'InventoryRuleViolation: $message';
}

/// Two updated inventories after a permitted card transfer.
final class InventoryTransfer {
  const InventoryTransfer({required this.from, required this.to});

  final PlayerState from;
  final PlayerState to;
}

/// Stateless, deterministic equipment and inventory rules.
abstract final class InventoryRules {
  static const int baseBackpackCapacity = 3;
  static const int expandedBackpackCapacity = 5;
  static const int maxImplantedModifications = 2;

  static const String _extraWeaponSlot = 'equipment.extraWeaponSlot';
  static const String _extraBackpackCapacity =
      'equipment.extraBackpackCapacity';

  /// The cards contributing permanent modifiers to a player's characteristics.
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
      ? expandedBackpackCapacity
      : baseBackpackCapacity;

  static int weaponCapacity(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _hasBehavior(player, definitions, _extraWeaponSlot) ? 2 : 1;

  /// Computes current values without changing the base character record.
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

  /// Adds a received card. Modifications always go to [PlayerState.carriedMods]
  /// and therefore never consume backpack space.
  static PlayerState receive(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    final definition = _definition(cardId, definitions);
    if (definition.type == ItemType.modification) {
      return _copy(player, carriedMods: [...player.carriedMods, cardId]);
    }
    final capacity = backpackCapacity(player, definitions);
    if (player.backpack.length >= capacity) {
      throw BackpackCapacityExceeded(capacity);
    }
    return _copy(player, backpack: [...player.backpack, cardId]);
  }

  /// Places an unimplanted modification permanently into its implant zone.
  /// Timing is checked by the implant command; this method also
  /// supports setup/reward flows that already established permission.
  static PlayerState implant(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    final definition = _definition(cardId, definitions);
    if (definition.type != ItemType.modification ||
        !player.carriedMods.contains(cardId)) {
      throw InventoryRuleViolation(
        'Only a carried modification may be implanted.',
      );
    }
    if (player.implanted.length >= maxImplantedModifications) {
      throw InventoryRuleViolation('At most 2 modifications may be implanted.');
    }
    final carried = List<CardId>.of(player.carriedMods)..remove(cardId);
    return _copy(
      player,
      carriedMods: carried,
      implanted: [...player.implanted, cardId],
    );
  }

  /// Equips a card from the backpack. Replaced equipment goes back to the
  /// backpack, which must still meet its immediate capacity limit.
  static PlayerState equip(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions, {
    int weaponSlot = 0,
  }) {
    final definition = _definition(cardId, definitions);
    if (!player.backpack.contains(cardId)) {
      throw InventoryRuleViolation('Only a backpack card may be equipped.');
    }
    if (definition.type == ItemType.modification) {
      throw InventoryRuleViolation(
        'Modifications are carried or implanted, not equipped.',
      );
    }
    final backpack = List<CardId>.of(player.backpack)..remove(cardId);
    final gear = player.equipped;
    late EquippedGear nextGear;
    CardId? replaced;
    switch (definition.type) {
      case ItemType.weapon:
        if (weaponSlot < 0 ||
            weaponSlot >= weaponCapacity(player, definitions)) {
          throw InventoryRuleViolation('This weapon slot is unavailable.');
        }
        final weapons = List<CardId>.of(gear.weapons);
        if (weaponSlot < weapons.length) {
          replaced = weapons[weaponSlot];
          weapons[weaponSlot] = cardId;
        } else {
          weapons.add(cardId);
        }
        nextGear = EquippedGear.withWeapons(
          weapons: weapons,
          armor: gear.armor,
          clothing: gear.clothing,
          robot: gear.robot,
        );
      case ItemType.armor:
        replaced = gear.armor;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          armor: cardId,
          clothing: gear.clothing,
          robot: gear.robot,
        );
      case ItemType.clothing:
        replaced = gear.clothing;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          armor: gear.armor,
          clothing: cardId,
          robot: gear.robot,
        );
      case ItemType.robot:
        replaced = gear.robot;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          armor: gear.armor,
          clothing: gear.clothing,
          robot: cardId,
        );
      case ItemType.modification || ItemType.supply || ItemType.specialItem:
        throw InventoryRuleViolation('This card has no equipment slot.');
    }
    if (replaced != null) backpack.add(replaced);
    final updated = _copy(player, backpack: backpack, equipped: nextGear);
    _requireBackpackFits(updated, definitions);
    return updated;
  }

  /// Removes an equipped card to the backpack. Implant slots deliberately do
  /// not exist here: implanted modifications can never be removed.
  static PlayerState unequip(
    PlayerState player,
    ItemSlot slot,
    Map<CardId, CardDefinition> definitions, {
    int weaponSlot = 0,
  }) {
    final gear = player.equipped;
    CardId? removed;
    late EquippedGear nextGear;
    switch (slot) {
      case ItemSlot.weapon:
        if (weaponSlot < 0 || weaponSlot >= gear.weapons.length) {
          throw InventoryRuleViolation('No weapon occupies this slot.');
        }
        final weapons = List<CardId>.of(gear.weapons);
        removed = weapons.removeAt(weaponSlot);
        nextGear = EquippedGear.withWeapons(
          weapons: weapons,
          armor: gear.armor,
          clothing: gear.clothing,
          robot: gear.robot,
        );
      case ItemSlot.armor:
        removed = gear.armor;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          clothing: gear.clothing,
          robot: gear.robot,
        );
      case ItemSlot.clothing:
        removed = gear.clothing;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          armor: gear.armor,
          robot: gear.robot,
        );
      case ItemSlot.robot:
        removed = gear.robot;
        nextGear = EquippedGear.withWeapons(
          weapons: gear.weapons,
          armor: gear.armor,
          clothing: gear.clothing,
        );
      case ItemSlot.modification:
        throw InventoryRuleViolation(
          'Implanted modifications cannot be removed.',
        );
    }
    if (removed == null) {
      throw InventoryRuleViolation('The equipment slot is empty.');
    }
    final updated = _copy(
      player,
      backpack: [...player.backpack, removed],
      equipped: nextGear,
    );
    _requireBackpackFits(updated, definitions);
    return updated;
  }

  /// Discards a non-implanted card. Implants cannot be discarded, sold, or
  /// otherwise removed from their permanent zone.
  static PlayerState discard(PlayerState player, CardId cardId) {
    if (player.implanted.contains(cardId)) {
      throw InventoryRuleViolation(
        'An implanted modification cannot be discarded.',
      );
    }
    final backpack = List<CardId>.of(player.backpack);
    if (backpack.remove(cardId)) return _copy(player, backpack: backpack);
    final carried = List<CardId>.of(player.carriedMods);
    if (carried.remove(cardId)) return _copy(player, carriedMods: carried);
    throw InventoryRuleViolation('The card is not carried by this player.');
  }

  /// Transfers a backpack card or an unimplanted modification to another
  /// player. Implanted modifications are intentionally rejected.
  static InventoryTransfer transfer(
    PlayerState from,
    PlayerState to,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    if (from.implanted.contains(cardId)) {
      throw InventoryRuleViolation(
        'An implanted modification cannot be transferred.',
      );
    }
    final source = discard(from, cardId);
    return InventoryTransfer(
      from: source,
      to: receive(to, cardId, definitions),
    );
  }

  static bool _hasBehavior(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
    String behaviorId,
  ) => activeCardIds(player).any(
    (id) => definitions[id]?.behaviorIds.contains(behaviorId) ?? false,
  );

  static CardDefinition _definition(
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    final definition = definitions[cardId];
    if (definition == null) {
      throw InventoryRuleViolation('Unknown card "$cardId".');
    }
    return definition;
  }

  static void _requireBackpackFits(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) {
    final capacity = backpackCapacity(player, definitions);
    if (player.backpack.length > capacity) {
      throw BackpackCapacityExceeded(capacity);
    }
  }

  static PlayerState _copy(
    PlayerState player, {
    Iterable<CardId>? backpack,
    EquippedGear? equipped,
    Iterable<CardId>? carriedMods,
    Iterable<CardId>? implanted,
  }) => PlayerState(
    id: player.id,
    characterId: player.characterId,
    coord: player.coord,
    damage: player.damage,
    health: player.health,
    credits: player.credits,
    backpack: backpack ?? player.backpack,
    equipped: equipped ?? player.equipped,
    carriedMods: carriedMods ?? player.carriedMods,
    implanted: implanted ?? player.implanted,
    conditions: player.conditions,
    alive: player.alive,
    stats: player.stats,
    weaponModifier: player.weaponModifier,
  );
}
