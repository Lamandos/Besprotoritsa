part of 'inventory_rules.dart';

abstract final class _InventoryChanges {
  static PlayerState receive(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    final definition = _definition(cardId, definitions);
    if (definition.type == ItemType.modification) {
      return _copy(player, carriedMods: [...player.carriedMods, cardId]);
    }
    final capacity = _InventoryStats.backpackCapacity(player, definitions);
    if (player.backpack.length >= capacity) {
      throw BackpackCapacityExceeded(capacity);
    }
    return _copy(player, backpack: [...player.backpack, cardId]);
  }

  static PlayerState implant(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    final definition = _definition(cardId, definitions);
    if (definition.type != ItemType.modification ||
        !player.carriedMods.contains(cardId)) {
      throw const InventoryRuleViolation(
        'Only a carried modification may be implanted.',
      );
    }
    if (player.implanted.length >= InventoryRules.maxImplantedModifications) {
      throw const InventoryRuleViolation(
        'At most 2 modifications may be implanted.',
      );
    }
    final carried = List<CardId>.of(player.carriedMods)..remove(cardId);
    return _copy(
      player,
      carriedMods: carried,
      implanted: [...player.implanted, cardId],
    );
  }

  static PlayerState equip(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions, {
    int weaponSlot = 0,
  }) {
    final definition = _definition(cardId, definitions);
    if (!player.backpack.contains(cardId)) {
      throw const InventoryRuleViolation(
        'Only a backpack card may be equipped.',
      );
    }
    if (definition.type == ItemType.modification) {
      throw const InventoryRuleViolation(
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
            weaponSlot >= _InventoryStats.weaponCapacity(player, definitions)) {
          throw const InventoryRuleViolation(
            'This weapon slot is unavailable.',
          );
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
        throw const InventoryRuleViolation('This card has no equipment slot.');
    }
    if (replaced != null) backpack.add(replaced);
    final updated = _copy(player, backpack: backpack, equipped: nextGear);
    _requireBackpackFits(updated, definitions);
    return updated;
  }

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
          throw const InventoryRuleViolation('No weapon occupies this slot.');
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
        throw const InventoryRuleViolation(
          'Implanted modifications cannot be removed.',
        );
    }
    if (removed == null) {
      throw const InventoryRuleViolation('The equipment slot is empty.');
    }
    final updated = _copy(
      player,
      backpack: [...player.backpack, removed],
      equipped: nextGear,
    );
    _requireBackpackFits(updated, definitions);
    return updated;
  }

  static PlayerState discard(PlayerState player, CardId cardId) {
    if (player.implanted.contains(cardId)) {
      throw const InventoryRuleViolation(
        'An implanted modification cannot be discarded.',
      );
    }
    final backpack = List<CardId>.of(player.backpack);
    if (backpack.remove(cardId)) return _copy(player, backpack: backpack);
    final carried = List<CardId>.of(player.carriedMods);
    if (carried.remove(cardId)) return _copy(player, carriedMods: carried);
    throw const InventoryRuleViolation(
      'The card is not carried by this player.',
    );
  }

  static InventoryTransfer transfer(
    PlayerState from,
    PlayerState to,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) {
    if (from.implanted.contains(cardId)) {
      throw const InventoryRuleViolation(
        'An implanted modification cannot be transferred.',
      );
    }
    return InventoryTransfer(
      from: discard(from, cardId),
      to: receive(to, cardId, definitions),
    );
  }

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
    final capacity = _InventoryStats.backpackCapacity(player, definitions);
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
