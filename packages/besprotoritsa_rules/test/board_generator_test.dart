import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('ShipBoardGenerator', () {
    test('generates 100 connected, collision-free boards', () {
      const generator = ShipBoardGenerator();

      for (var seed = 0; seed < 100; seed++) {
        final board = generator.generate(seed);
        _expectPhysicallyValid(board, seed);
      }
    });

    test('includes every story location and both vent colours', () {
      final board = const ShipBoardGenerator().generate(17);
      final locations = board.tiles
          .map((tile) => tile.locationId)
          .whereType<String>()
          .toSet();

      expect(locations, containsAll(storyLocationIds));
      expect(
        board.tiles.where((tile) => tile.type == HexTileType.airlock),
        hasLength(4),
      );
      expect(
        board.tiles.map((tile) => tile.ventColor),
        contains(VentColor.green),
      );
      expect(
        board.tiles.map((tile) => tile.ventColor),
        contains(VentColor.red),
      );
      final straightOrTurn = board.tiles
          .where((tile) => tile.type == HexTileType.corridor)
          .map((tile) {
            final exits = tile.exits.toList();
            return exits.first.opposite == exits.last;
          })
          .toSet();
      expect(straightOrTurn, containsAll({true, false}));
    });

    test('connects every airlock with a suit or oxygen tank', () {
      final board = const ShipBoardGenerator().generate(29);
      final airlocks = board.tiles
          .where((tile) => tile.type == HexTileType.airlock)
          .toList();

      for (final source in airlocks) {
        for (final destination in airlocks.where((tile) => tile != source)) {
          expect(
            board.airlockTravelCost(
              source.coord,
              destination.coord,
              const AirlockEquipment(hasSpaceSuit: true),
            ),
            1,
          );
          expect(
            board.airlockTravelCost(
              source.coord,
              destination.coord,
              const AirlockEquipment(hasOxygenTank: true),
            ),
            2,
          );
        }
      }
    });

    test(
      'seals only an empty adjacent corridor and blocks normal movement',
      () {
        final closed = step(
          _corridorState(includeMonster: true),
          const CloseCorridorCommand(HexCoord(0, 1)),
          FixedDiceRoller([]),
        );

        expect(closed.isAccepted, isTrue);
        expect(closed.state.actionsLeft, 1);
        expect(closed.state.tileAt(const HexCoord(0, 1))!.isBlocked, isTrue);
        expect(
          validate(closed.state, const MoveCommand(HexCoord(0, 1))),
          isA<PathBlocked>(),
        );
        expect(
          () => moveMonsterOneStep(
            closed.state,
            'crawler',
            const HexCoord(0, 1),
          ),
          throwsArgumentError,
        );
      },
    );

    test('uses the specified equipment for direct airlock movement', () {
      final result = step(
        _airlockState(),
        const AirlockMoveCommand(
          HexCoord(3, 0),
          AirlockEquipment(hasOxygenTank: true),
        ),
        FixedDiceRoller([]),
      );

      expect(result.isAccepted, isTrue);
      expect(result.state.players.single.coord, const HexCoord(3, 0));
      expect(result.state.actionsLeft, 0);
    });
  });
}

void _expectPhysicallyValid(ShipBoard board, int seed) {
  expect(
    board.tiles.map((tile) => tile.coord).toSet(),
    hasLength(board.tiles.length),
    reason: 'seed $seed has colliding coordinates',
  );
  for (final tile in board.tiles) {
    for (final edge in HexEdge.values) {
      final neighbor = board.tileAt(tile.coord.neighbor(edge));
      if (neighbor == null) continue;
      expect(
        tile.hasExit(edge),
        neighbor.hasExit(edge.opposite),
        reason: 'seed $seed has mismatched ports at ${tile.coord}:$edge',
      );
    }
    if (tile.type == HexTileType.corridor) {
      final adjacentRooms = HexEdge.values
          .map((edge) => board.tileAt(tile.coord.neighbor(edge)))
          .whereType<HexTile>()
          .where((neighbor) => neighbor.type != HexTileType.corridor)
          .length;
      expect(adjacentRooms, 2, reason: 'seed $seed corridor ${tile.id}');
    }
  }
  expect(
    _reachable(board),
    hasLength(board.tiles.length),
    reason: 'seed $seed',
  );
}

Set<HexCoord> _reachable(ShipBoard board) {
  final visited = <HexCoord>{board.tiles.first.coord};
  final pending = <HexCoord>[board.tiles.first.coord];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final edge in HexEdge.values) {
      final next = current.neighbor(edge);
      if (board.canTraverse(current, next) && visited.add(next)) {
        pending.add(next);
      }
    }
  }
  return visited;
}

GameState _corridorState({bool includeMonster = false}) => _state(
  [
    _tile('start', const HexCoord(0, 0), HexTileType.start, {HexEdge.south}),
    _tile(
      'corridor',
      const HexCoord(0, 1),
      HexTileType.corridor,
      {HexEdge.north, HexEdge.south},
    ),
    _tile(
      'room',
      const HexCoord(0, 2),
      HexTileType.compartment,
      {HexEdge.north},
    ),
  ],
  monsters: includeMonster
      ? [
          MonsterInstance(
            instanceId: 'crawler',
            monsterId: 'crawler',
            coord: const HexCoord(0, 2),
            damage: 0,
          ),
        ]
      : const [],
);

GameState _airlockState() => _state([
  _tile('airlock-one', const HexCoord(0, 0), HexTileType.airlock, const {}),
  _tile('airlock-two', const HexCoord(3, 0), HexTileType.airlock, const {}),
]);

GameState _state(
  List<HexTile> board, {
  Iterable<MonsterInstance> monsters = const [],
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'hero',
  actionsLeft: 2,
  board: board,
  players: [
    PlayerState(
      id: 'hero',
      characterId: 'guard',
      coord: board.first.coord,
      damage: 0,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
    ),
  ],
  monsters: monsters,
  decks: const {},
  quests: QuestState(),
);

HexTile _tile(
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
  hasTerminal: false,
  ventColor: VentColor.none,
);
