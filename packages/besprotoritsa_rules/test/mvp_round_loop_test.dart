import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('runs the MVP from the first step through Quest 1 completion', () {
    var state = _mvpState();

    state = step(
      state,
      const MoveCommand(HexCoord(0, 1)),
      FixedDiceRoller([]),
    ).state;
    expect(state.actionsLeft, 0);
    expect(state.players.single.coord, const HexCoord(0, 1));

    // Ending the player phase automatically runs monsters, then draws the
    // eligible hero's event. There are no monsters in this first MVP round.
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    expect(state.phase, GamePhase.eventsPhase);
    expect(state.pendingDecision, isA<AwaitingEventOption>());

    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('investigate')),
      FixedDiceRoller([6]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingRerollChoice>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;
    expect(state.phase, GamePhase.playersTurn);
    expect(state.round, 2);
    expect(state.players.single.backpack, contains('event-supply'));

    state = step(
      state,
      const MoveCommand(HexCoord(0, 2)),
      FixedDiceRoller([]),
    ).state;
    expect(state.players.single.coord, const HexCoord(0, 2));
    expect(state.tileAt(const HexCoord(0, 2))!.opened, isTrue);

    // The exhausted event deck recycles its discard, so the same event is
    // drawn again before the next player turn begins.
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    expect(state.pendingDecision, isA<AwaitingEventOption>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('investigate')),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;
    expect(state.phase, GamePhase.playersTurn);
    expect(state.round, 3);
    expect(state.actionsLeft, 2);

    state = step(
      state,
      const SkillCheckCommand(StatType.science),
      FixedDiceRoller([5]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingRerollChoice>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(
      state.quests.statusOf('chapter-1-awakening'),
      QuestStatus.completed,
    );
    expect(state.isComplete, isTrue);
    expect(state.gameEvents.single, isA<MvpDemonstrationCompleted>());
  });
}

GameState _mvpState() => GameState(
  seed: 17,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile(
      id: 'anabiosis',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const {HexEdge.south},
    ),
    _tile(
      id: 'corridor',
      coord: const HexCoord(0, 1),
      type: HexTileType.corridor,
      opened: false,
      exits: const {HexEdge.north, HexEdge.south},
    ),
    _tile(
      id: 'crew-mess',
      coord: const HexCoord(0, 2),
      type: HexTileType.compartment,
      opened: false,
      exits: const {HexEdge.north},
      locationId: 'crew-mess',
    ),
  ],
  players: [
    PlayerState(
      id: 'ada',
      characterId: 'engineer',
      coord: const HexCoord(0, 0),
      damage: 0,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
      stats: const PlayerStats(science: 1, agility: 1),
    ),
  ],
  monsters: const [],
  decks: {
    'events': DeckState(drawPile: const ['cabin-noise']),
  },
  quests: QuestState(storyQuestIds: const ['chapter-1-awakening']),
);

HexTile _tile({
  required String id,
  required HexCoord coord,
  required HexTileType type,
  required bool opened,
  required Set<HexEdge> exits,
  String? locationId,
}) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: opened,
  exits: exits,
  locationId: locationId,
  hasTerminal: false,
  ventColor: VentColor.none,
);
