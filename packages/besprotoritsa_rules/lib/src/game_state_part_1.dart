// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'game_state.dart';

typedef PlayerId = String;
typedef CharacterId = String;
typedef CardId = String;
typedef QuestId = String;
typedef DeckId = String;
typedef LocationId = String;

/// One of the six directed sides of an axial hex.
enum HexEdge {
  north(0, -1),
  northEast(1, -1),
  southEast(1, 0),
  south(0, 1),
  southWest(-1, 1),
  northWest(-1, 0);

  const HexEdge(this.deltaQ, this.deltaR);

  final int deltaQ;
  final int deltaR;

  /// Returns an edge from its persisted value (0 through 5).
  static HexEdge fromIndex(int index) {
    if (index < 0 || index >= values.length) {
      throw ArgumentError.value(index, 'index', 'Hex edge must be in 0..5.');
    }
    return values[index];
  }

  /// The side facing this edge on a neighbouring hex.
  HexEdge get opposite => values[(index + 3) % values.length];
}

/// An immutable axial coordinate.
@immutable
final class HexCoord {
  const HexCoord(this.q, this.r);

  final int q;
  final int r;

  /// The coordinate one step through [edge].
  HexCoord neighbor(HexEdge edge) => HexCoord(q + edge.deltaQ, r + edge.deltaR);

  /// All six adjacent coordinates, in [HexEdge] order.
  Iterable<HexCoord> get neighbors => HexEdge.values.map(neighbor);

  /// The axial/cube distance to [other].
  int distanceTo(HexCoord other) {
    final deltaQ = q - other.q;
    final deltaR = r - other.r;
    return (deltaQ.abs() + deltaR.abs() + (deltaQ + deltaR).abs()) ~/ 2;
  }

  /// Returns the edge leading to [other], or null when it is not adjacent.
  HexEdge? edgeTowardOrNull(HexCoord other) {
    for (final edge in HexEdge.values) {
      if (neighbor(edge) == other) {
        return edge;
      }
    }
    return null;
  }

  /// Returns the edge leading to an adjacent [other].
  ///
  /// A coordinate is not a direction. Passing this coordinate itself or a
  /// non-neighbour is rejected instead of silently choosing an arbitrary edge.
  HexEdge edgeToward(HexCoord other) {
    final edge = edgeTowardOrNull(other);
    if (edge == null) {
      throw ArgumentError.value(other, 'other', 'Target must be adjacent.');
    }
    return edge;
  }

  @override
  bool operator ==(Object other) =>
      other is HexCoord && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => 'HexCoord($q, $r)';
}

enum HexTileType { start, compartment, corridor, airlock }

enum VentColor { none, green, red }

/// An immutable tile laid on the board.
@immutable
final class HexTile {
  HexTile({
    required this.id,
    required this.coord,
    required this.type,
    required this.opened,
    required Iterable<HexEdge> exits,
    this.locationId,
    required this.hasTerminal,
    required this.ventColor,
    this.isBlocked = false,
  }) : exits = Set.unmodifiable(exits) {
    _requireId(id, 'id');
    if (locationId != null) {
      _requireId(locationId!, 'locationId');
    }
  }

  final String id;
  final HexCoord coord;
  final HexTileType type;
  final bool opened;
  final Set<HexEdge> exits;
  final LocationId? locationId;
  final bool hasTerminal;
  final VentColor ventColor;
  final bool isBlocked;

  bool hasExit(HexEdge edge) => exits.contains(edge);
}

/// Gear occupying the four visible equipment slots of a player.
@immutable
final class EquippedGear {
  const EquippedGear({
    this.weapon,
    this.secondWeapon,
    this.armor,
    this.clothing,
    this.robot,
  });

  factory EquippedGear.withWeapons({
    required Iterable<CardId> weapons,
    CardId? armor,
    CardId? clothing,
    CardId? robot,
  }) {
    final weaponList = List<CardId>.of(weapons);
    if (weaponList.length > 2) {
      throw ArgumentError.value(
        weapons,
        'weapons',
        'At most two weapons may be equipped.',
      );
    }
    return EquippedGear(
      weapon: weaponList.isEmpty ? null : weaponList.first,
      secondWeapon: weaponList.length < 2 ? null : weaponList[1],
      armor: armor,
      clothing: clothing,
      robot: robot,
    );
  }

  /// Weapons in their displayed order. A second entry requires a load-bearing
  /// vest; inventory rules verify that rule against the card definitions.
  List<CardId> get weapons => List.unmodifiable([
    if (weapon != null) weapon!,
    if (secondWeapon != null) secondWeapon!,
  ]);

  /// The primary weapon.
  final CardId? weapon;

  /// The additional weapon, when a load-bearing vest allows one.
  final CardId? secondWeapon;

  final CardId? armor;
  final CardId? clothing;
  final CardId? robot;
}

/// An inert threat token which explodes when a player shares its cell.
@immutable
final class BoilToken {
  const BoilToken({required this.instanceId, required this.coord})
    : assert(instanceId != '', 'instanceId must not be empty');

  final String instanceId;
  final HexCoord coord;
}

/// The private and public state of one participant's character.
@immutable
final class PlayerState {
  PlayerState({
    required this.id,
    required this.characterId,
    required this.coord,
    required this.damage,
    this.health = 3,
    required this.credits,
    required Iterable<CardId> backpack,
    required this.equipped,
    required Iterable<CardId> carriedMods,
    required Iterable<CardId> implanted,
    required Iterable<CardId> conditions,
    required this.alive,
    this.stats = const PlayerStats(),
    this.weaponModifier = 0,
  }) : backpack = List.unmodifiable(backpack),
       carriedMods = List.unmodifiable(carriedMods),
       implanted = List.unmodifiable(implanted),
       conditions = List.unmodifiable(conditions) {
    _requireId(id, 'id');
    _requireId(characterId, 'characterId');
    _requireNonNegative(damage, 'damage');
    if (health < 1) {
      throw ArgumentError.value(health, 'health', 'Health must be positive.');
    }
    _requireNonNegative(credits, 'credits');
    _requireNonNegative(weaponModifier, 'weaponModifier');
    // A load-bearing backpack can raise the effective limit to five. The
    // current effective limit depends on card definitions and is enforced by
    // InventoryRules; this model-level ceiling prevents impossible states.
    if (this.backpack.length > 5) {
      throw ArgumentError.value(
        backpack,
        'backpack',
        'Backpack holds at most 5 cards.',
      );
    }
    if (this.implanted.length > 2) {
      throw ArgumentError.value(
        implanted,
        'implanted',
        'At most 2 modifications may be implanted.',
      );
    }
  }

  final PlayerId id;
  final CharacterId characterId;
  final HexCoord coord;
  final int damage;

  /// Maximum health; current HP is [health] minus [damage].
  final int health;
  final int credits;
  final List<CardId> backpack;
  final EquippedGear equipped;
  final List<CardId> carriedMods;
  final List<CardId> implanted;
  final List<CardId> conditions;
  final bool alive;
  final PlayerStats stats;

  /// The equipped weapon's bonus to the hero attack pool.
  final int weaponModifier;
}

/// A monster token on the board. [carriedGear] is used by a Restless monster.
