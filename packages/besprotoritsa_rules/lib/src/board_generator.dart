// The public API is intentionally compact and self-describing.
// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:besprotoritsa_rules/src/game_state.dart';

/// The traversal aid used to cross directly between any two airlocks.
final class AirlockEquipment {
  const AirlockEquipment({
    this.hasSpaceSuit = false,
    this.hasOxygenTank = false,
  });

  final bool hasSpaceSuit;
  final bool hasOxygenTank;

  /// A space suit is preferred because it costs fewer movement points.
  int? get movementCost => hasSpaceSuit
      ? 1
      : hasOxygenTank
      ? 2
      : null;
}

/// Returns the movement cost for an all-to-all airlock transfer, if allowed.
int? airlockTransferCost(
  HexTile source,
  HexTile destination,
  AirlockEquipment equipment,
) =>
    source.type == HexTileType.airlock &&
        destination.type == HexTileType.airlock &&
        source.opened &&
        destination.opened &&
        !source.isBlocked &&
        !destination.isBlocked
    ? equipment.movementCost
    : null;

/// The locations printed on the ship-board sheets that are needed by story.
const storyLocationIds = <String>{
  'anabiosis',
  'morgue',
  'engineering-control-post',
  'dining-room',
  'reactor',
  'warehouse-compartment',
  'management-compartment',
  'medical-compartment',
  'cabins',
  'main-computer',
  'armory',
  'laboratory',
  'rescue-capsules',
};

/// Builds a reproducible, physically connected ship board from a numeric seed.
final class ShipBoardGenerator {
  const ShipBoardGenerator();

  ShipBoard generate(int seed) {
    final random = Random(seed);
    final locations = storyLocationIds.toList()
      ..sort()
      ..remove('anabiosis')
      ..shuffle(random);
    final airlocks = List<String>.generate(4, (index) => 'airlock-${index + 1}')
      ..shuffle(random);
    locations.addAll(airlocks);

    final tiles = <HexTile>[
      _room('anabiosis', const HexCoord(0, 0), HexTileType.start, const {}),
    ];
    var room = tiles.single;
    var direction = HexEdge.values[random.nextInt(HexEdge.values.length)];
    var nextDirection = _turnFrom(direction, random);
    for (var index = 0; index < locations.length; index++) {
      final corridorCoord = room.coord.neighbor(direction);
      final nextRoomCoord = corridorCoord.neighbor(nextDirection);
      final corridor = _corridor(
        index,
        corridorCoord,
        incoming: direction.opposite,
        outgoing: nextDirection,
      );
      final type = locations[index].startsWith('airlock-')
          ? HexTileType.airlock
          : HexTileType.compartment;
      final nextRoom = _room(
        locations[index],
        nextRoomCoord,
        type,
        {nextDirection.opposite},
      );
      tiles[tiles.indexOf(room)] = _withExit(room, direction);
      tiles.addAll([corridor, nextRoom]);
      room = nextRoom;
      direction = nextDirection;
      // After the initial turn, the chain expands in one direction.  This
      // prevents unrelated hex sides from touching and creating false ports.
      nextDirection = direction;
    }
    return ShipBoard(tiles);
  }

  HexEdge _turnFrom(HexEdge incoming, Random random) {
    final options =
        HexEdge.values.where((edge) => edge != incoming.opposite).toList()
          ..shuffle(random);
    return options.first;
  }

  HexTile _corridor(
    int index,
    HexCoord coord, {
    required HexEdge incoming,
    required HexEdge outgoing,
  }) => HexTile(
    id: 'corridor-${index + 1}',
    coord: coord,
    type: HexTileType.corridor,
    opened: true,
    exits: {incoming, outgoing},
    hasTerminal: false,
    ventColor: switch (index % 6) {
      2 || 3 => VentColor.green,
      4 => VentColor.red,
      _ => VentColor.none,
    },
  );
}

/// A checked board layout. Construction rejects invalid physical placement.
final class ShipBoard {
  ShipBoard(Iterable<HexTile> tiles) : tiles = List.unmodifiable(tiles) {
    if (this.tiles.isEmpty) {
      throw ArgumentError.value(tiles, 'tiles', 'Empty board.');
    }
    _validateUniqueCoordinates();
    _validatePortMatching();
    _validateRoomCorridorTopology();
    _validateConnected();
    _validateStoryLocations();
  }

  final List<HexTile> tiles;

  HexTile? tileAt(HexCoord coord) {
    for (final tile in tiles) {
      if (tile.coord == coord) return tile;
    }
    return null;
  }

  bool canTraverse(HexCoord from, HexCoord to) {
    final source = tileAt(from);
    final destination = tileAt(to);
    final edge = from.edgeTowardOrNull(to);
    return source != null &&
        destination != null &&
        edge != null &&
        !source.isBlocked &&
        !destination.isBlocked &&
        source.hasExit(edge) &&
        destination.hasExit(edge.opposite);
  }

  int? airlockTravelCost(
    HexCoord from,
    HexCoord to,
    AirlockEquipment equipment,
  ) {
    final source = tileAt(from);
    final destination = tileAt(to);
    if (source == null || destination == null) return null;
    return airlockTransferCost(source, destination, equipment);
  }

  void _validateUniqueCoordinates() {
    final coordinates = <HexCoord>{};
    for (final tile in tiles) {
      if (!coordinates.add(tile.coord)) {
        throw ArgumentError.value(
          tile.coord,
          'tiles',
          'Tile coordinate collision.',
        );
      }
    }
  }

  void _validatePortMatching() {
    for (final tile in tiles) {
      for (final edge in HexEdge.values) {
        final adjacent = tileAt(tile.coord.neighbor(edge));
        if (adjacent == null) continue;
        if (tile.hasExit(edge) != adjacent.hasExit(edge.opposite)) {
          throw ArgumentError.value(
            tile.coord,
            'tiles',
            'Mismatched ports at ${tile.coord} and ${adjacent.coord}.',
          );
        }
      }
    }
  }

  void _validateRoomCorridorTopology() {
    for (final tile in tiles) {
      if (tile.type == HexTileType.corridor) {
        final rooms = _connectedNeighbors(tile).where(_isRoom).length;
        if (rooms != 2) {
          throw ArgumentError.value(
            tile.id,
            'tiles',
            'Each corridor must connect exactly two rooms.',
          );
        }
      }
      if (_isRoom(tile) && _connectedNeighbors(tile).any(_isRoom)) {
        throw ArgumentError.value(
          tile.id,
          'tiles',
          'Rooms cannot connect directly; a corridor is required.',
        );
      }
    }
  }

  void _validateConnected() {
    final seen = <HexCoord>{tiles.first.coord};
    final pending = <HexCoord>[tiles.first.coord];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final edge in HexEdge.values) {
        final next = current.neighbor(edge);
        if (canTraverse(current, next) && seen.add(next)) pending.add(next);
      }
    }
    if (seen.length != tiles.length) {
      throw ArgumentError.value(tiles, 'tiles', 'Board is not connected.');
    }
  }

  void _validateStoryLocations() {
    final locations = tiles
        .map((tile) => tile.locationId)
        .whereType<String>()
        .toSet();
    final missing = storyLocationIds.difference(locations);
    if (missing.isNotEmpty) {
      throw ArgumentError.value(missing, 'tiles', 'Missing story locations.');
    }
  }

  Iterable<HexTile> _connectedNeighbors(HexTile tile) sync* {
    for (final edge in tile.exits) {
      final neighbor = tileAt(tile.coord.neighbor(edge));
      if (neighbor != null && neighbor.hasExit(edge.opposite)) yield neighbor;
    }
  }
}

bool _isRoom(HexTile tile) => tile.type != HexTileType.corridor;

HexTile _room(
  String id,
  HexCoord coord,
  HexTileType type,
  Set<HexEdge> exits,
) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: true,
  exits: exits,
  locationId: id,
  hasTerminal: id == 'engineering-control-post' || id == 'main-computer',
  ventColor: VentColor.none,
);

HexTile _withExit(HexTile tile, HexEdge exit) => HexTile(
  id: tile.id,
  coord: tile.coord,
  type: tile.type,
  opened: tile.opened,
  exits: {...tile.exits, exit},
  locationId: tile.locationId,
  hasTerminal: tile.hasTerminal,
  ventColor: tile.ventColor,
  isBlocked: tile.isBlocked,
);
