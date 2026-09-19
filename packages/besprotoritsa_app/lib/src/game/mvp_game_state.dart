import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Creates the compact, deterministic scenario shown by the MVP game screen.
///
/// The default keeps the original two-character MVP setup. The game shell can
/// supply a roster of two to four character identifiers for a new expedition.
GameState createMvpGameState({List<String>? characterIds}) {
  final roster = characterIds ?? const ['engineer', 'guard'];
  if (roster.length < 2 || roster.length > 4) {
    throw ArgumentError.value(
      characterIds,
      'characterIds',
      'Expected 2..4 heroes.',
    );
  }
  final isDefaultRoster = roster[0] == 'engineer' && roster[1] == 'guard';
  final players = isDefaultRoster
      ? <PlayerState>[
          _player('ada', 'engineer', const HexCoord(0, 0)),
          _player('boris', 'guard', const HexCoord(1, -1)),
        ]
      : List<PlayerState>.generate(
          roster.length,
          (index) => _player(
            'hero-${index + 1}',
            roster[index],
            index.isEven ? const HexCoord(0, 0) : const HexCoord(1, -1),
          ),
        );
  return GameState(
    seed: 17,
    round: 1,
    phase: GamePhase.playersTurn,
    activePlayerId: players.first.id,
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
    players: players,
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
}

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
