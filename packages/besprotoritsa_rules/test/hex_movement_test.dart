import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('hex movement', () {
    test(
      'opens the MVP corridor and crew mess at two movement points each',
      () {
        final start = _mvpState(actionsLeft: 4);

        final corridor = step(
          start,
          const MoveCommand(HexCoord(0, 1)),
          FixedDiceRoller([]),
        );
        final crewMess = step(
          corridor.state,
          const MoveCommand(HexCoord(0, 2)),
          FixedDiceRoller([]),
        );

        expect(corridor.isAccepted, isTrue);
        expect(corridor.state.actionsLeft, 2);
        expect(corridor.state.players.single.coord, const HexCoord(0, 1));
        expect(corridor.state.tileAt(const HexCoord(0, 1))!.opened, isTrue);
        expect(crewMess.isAccepted, isTrue);
        expect(crewMess.state.actionsLeft, 0);
        expect(crewMess.state.players.single.coord, const HexCoord(0, 2));
        expect(crewMess.state.tileAt(const HexCoord(0, 2))!.opened, isTrue);
      },
    );

    test('uses one movement point when returning through opened sectors', () {
      final state = _mvpState(
        corridorOpened: true,
        crewMessOpened: true,
        playerCoord: const HexCoord(0, 2),
      );

      final result = step(
        state,
        const MoveCommand(HexCoord(0, 1)),
        FixedDiceRoller([]),
      );

      expect(result.isAccepted, isTrue);
      expect(result.state.actionsLeft, 1);
      expect(result.state.players.single.coord, const HexCoord(0, 1));
    });

    test('rejects opening a sector without two movement points', () {
      final result = step(
        _mvpState(actionsLeft: 1),
        const MoveCommand(HexCoord(0, 1)),
        FixedDiceRoller([]),
      );

      expect(result.rejection, isA<NotEnoughActions>());
      expect(result.state.tileAt(const HexCoord(0, 1))!.opened, isFalse);
    });

    test('rejects a step through a solid wall', () {
      final state = _mvpState(corridorExits: {HexEdge.south});

      final result = step(
        state,
        const MoveCommand(HexCoord(0, 1)),
        FixedDiceRoller([]),
      );

      expect(result.rejection, isA<PortMismatch>());
      expect(result.state.players.single.coord, const HexCoord(0, 0));
    });

    test('does not allow two tiles to occupy an opened sector coordinate', () {
      expect(
        () => _mvpState(
          extraTile: _tile(
            id: 'collision',
            coord: const HexCoord(0, 0),
            type: HexTileType.corridor,
            opened: false,
            exits: const {},
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

GameState _mvpState({
  int actionsLeft = 2,
  bool corridorOpened = false,
  bool crewMessOpened = false,
  HexCoord playerCoord = const HexCoord(0, 0),
  Set<HexEdge> corridorExits = const {HexEdge.north, HexEdge.south},
  HexTile? extraTile,
}) => GameState(
  seed: 7,
  round: 1,
  phase: GamePhase.players,
  activePlayerId: 'ada',
  actionsLeft: actionsLeft,
  board: [
    _tile(
      id: 'start',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const {HexEdge.south},
    ),
    _tile(
      id: 'corridor',
      coord: const HexCoord(0, 1),
      type: HexTileType.corridor,
      opened: corridorOpened,
      exits: corridorExits,
    ),
    _tile(
      id: 'crew-mess',
      coord: const HexCoord(0, 2),
      type: HexTileType.compartment,
      opened: crewMessOpened,
      exits: const {HexEdge.north},
    ),
    if (extraTile != null) extraTile,
  ],
  players: [
    PlayerState(
      id: 'ada',
      characterId: 'guard',
      coord: playerCoord,
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
  monsters: const [],
  decks: const {},
  quests: QuestState(),
);

HexTile _tile({
  required String id,
  required HexCoord coord,
  required HexTileType type,
  required bool opened,
  required Set<HexEdge> exits,
}) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: opened,
  exits: exits,
  hasTerminal: false,
  ventColor: VentColor.none,
);
