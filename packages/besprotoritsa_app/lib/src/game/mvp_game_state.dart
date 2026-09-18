import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Creates the compact, deterministic scenario shown by the MVP game screen.
GameState createMvpGameState() => GameState(
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
      exits: const {HexEdge.south, HexEdge.northEast},
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
    _tile(
      id: 'guard-post',
      coord: const HexCoord(1, -1),
      type: HexTileType.compartment,
      opened: true,
      exits: const {HexEdge.southWest},
    ),
  ],
  players: [
    _player('ada', 'engineer', const HexCoord(0, 0)),
    _player('boris', 'guard', const HexCoord(1, -1)),
  ],
  monsters: [
    MonsterInstance(
      instanceId: 'ghoul-1',
      monsterId: 'ghoul',
      coord: const HexCoord(0, 1),
      damage: 0,
      health: 2,
      attack: 1,
    ),
  ],
  decks: {
    'conditions': DeckState(drawPile: const ['malaise']),
    'events': DeckState(drawPile: const ['cabin-noise']),
  },
  conditionCards: {
    'malaise': ConditionCard(
      id: 'malaise',
      statModifiers: const {StatType.strength: -1},
    ),
  },
  quests: QuestState(storyQuestIds: const ['chapter-1-awakening']),
);

PlayerState _player(String id, String characterId, HexCoord coord) =>
    PlayerState(
      id: id,
      characterId: characterId,
      coord: coord,
      damage: 0,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
      stats: const PlayerStats(science: 1, agility: 1),
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
