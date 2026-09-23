// Inventory transitions are kept separate from the turn reducer so callers
// can use the same rules for rewards, trading, shops, and setup.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/card_definition.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';

part 'inventory_stats_part.dart';
part 'inventory_changes_part.dart';

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
}

/// Returned when a card cannot be put into the backpack immediately.
final class BackpackCapacityExceeded implements Exception {
  const BackpackCapacityExceeded(this.capacity);

  final int capacity;

  @override
  String toString() => 'Backpack capacity is $capacity.';
}

/// Returned for attempts to use an unavailable equipment slot or zone.
final class InventoryRuleViolation implements Exception {
  const InventoryRuleViolation(this.message);

  final String message;

  @override
  String toString() => message;
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

  static Iterable<CardId> activeCardIds(PlayerState player) =>
      _InventoryStats.activeCardIds(player);

  static int backpackCapacity(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryStats.backpackCapacity(player, definitions);

  static int weaponCapacity(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryStats.weaponCapacity(player, definitions);

  static EffectivePlayerStats effectiveStats(
    PlayerState player,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryStats.effectiveStats(player, definitions);

  static PlayerState receive(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryChanges.receive(player, cardId, definitions);

  static PlayerState implant(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryChanges.implant(player, cardId, definitions);

  static PlayerState equip(
    PlayerState player,
    CardId cardId,
    Map<CardId, CardDefinition> definitions, {
    int weaponSlot = 0,
  }) => _InventoryChanges.equip(
    player,
    cardId,
    definitions,
    weaponSlot: weaponSlot,
  );

  static PlayerState unequip(
    PlayerState player,
    ItemSlot slot,
    Map<CardId, CardDefinition> definitions, {
    int weaponSlot = 0,
  }) => _InventoryChanges.unequip(
    player,
    slot,
    definitions,
    weaponSlot: weaponSlot,
  );

  static PlayerState discard(PlayerState player, CardId cardId) =>
      _InventoryChanges.discard(player, cardId);

  static InventoryTransfer transfer(
    PlayerState from,
    PlayerState to,
    CardId cardId,
    Map<CardId, CardDefinition> definitions,
  ) => _InventoryChanges.transfer(from, to, cardId, definitions);
}
