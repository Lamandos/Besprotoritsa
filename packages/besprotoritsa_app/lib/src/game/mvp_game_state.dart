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
          _player('boris', 'guard', const HexCoord(0, 0)),
        ]
      : List<PlayerState>.generate(
          roster.length,
          (index) => _player(
            'hero-${index + 1}',
            roster[index],
            const HexCoord(0, 0),
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
    ],
    players: players,
    monsters: [
      MonsterInstance(
        instanceId: 'ghoul-1',
        monsterId: 'ghoul',
        coord: const HexCoord(0, 1),
        damage: 0,
        health: 2,
        attack: 2,
      ),
    ],
    decks: {
      'conditions': DeckState(drawPile: const ['malaise', 'concussion']),
      'events': DeckState(drawPile: const ['cabin-noise']),
    },
    conditionCards: {
      'malaise': ConditionCard(
        id: 'malaise',
        statModifiers: const {StatType.strength: -1},
      ),
      'concussion': ConditionCard(
        id: 'concussion',
        statModifiers: const {StatType.repair: -1},
      ),
    },
    cardDefinitions: _mvpCards,
    quests: QuestState(storyQuestIds: const ['chapter-1-awakening']),
  );
}

PlayerState _player(String id, String characterId, HexCoord coord) {
  final definition = _mvpCharacters[characterId] ?? _fallbackCharacter;
  return PlayerState(
    id: id,
    characterId: characterId,
    coord: coord,
    damage: 0,
    health: definition.health,
    credits: definition.credits,
    backpack: definition.startItems,
    equipped: definition.equipped,
    carriedMods: const [],
    implanted: const [],
    conditions: const [],
    alive: true,
    stats: definition.stats,
  );
}

const _fallbackCharacter = _MvpCharacter(
  health: 10,
  stats: PlayerStats(),
  credits: 3,
  startItems: <CardId>[],
  equipped: EquippedGear(),
);

const _mvpCharacters = <String, _MvpCharacter>{
  'engineer': _MvpCharacter(
    health: 10,
    stats: PlayerStats(
      strength: 3,
      combatStrength: 3,
      science: 2,
      repair: 3,
      endurance: 2,
      agility: 1,
    ),
    credits: 3,
    startItems: <CardId>[],
    equipped: EquippedGear(robot: 'gu4-rd'),
  ),
  'guard': _MvpCharacter(
    health: 11,
    stats: PlayerStats(
      strength: 3,
      combatStrength: 3,
      science: 1,
      repair: 1,
      endurance: 3,
      agility: 3,
    ),
    credits: 3,
    startItems: <CardId>[],
    equipped: EquippedGear(weapon: 'pistol'),
  ),
  'scientist': _MvpCharacter(
    health: 8,
    stats: PlayerStats(
      strength: 2,
      combatStrength: 2,
      science: 4,
      repair: 2,
      endurance: 1,
      agility: 2,
    ),
    credits: 5,
    startItems: <CardId>['lucky-socks'],
    equipped: EquippedGear(),
  ),
  'mechanic': _MvpCharacter(
    health: 9,
    stats: PlayerStats(
      strength: 2,
      combatStrength: 2,
      science: 2,
      repair: 3,
      endurance: 2,
      agility: 2,
    ),
    credits: 4,
    startItems: <CardId>['hard-hat'],
    equipped: EquippedGear(),
  ),
  'healer': _MvpCharacter(
    health: 8,
    stats: PlayerStats(
      strength: 2,
      combatStrength: 2,
      science: 3,
      repair: 2,
      endurance: 2,
      agility: 2,
    ),
    credits: 4,
    startItems: <CardId>['medic-bag'],
    equipped: EquippedGear(),
  ),
};

final _mvpCards = <CardId, CardDefinition>{
  'pistol': CardDefinition(
    id: 'pistol',
    type: ItemType.weapon,
    slots: const <ItemSlot>{ItemSlot.weapon},
    cost: 0,
    staticEffects: CardStaticEffects(const <CardStat, int>{
      CardStat.strength: 2,
    }),
    behaviorIds: const <String>['pistol_attack_reroll'],
  ),
  'gu4-rd': CardDefinition(
    id: 'gu4-rd',
    type: ItemType.robot,
    slots: const <ItemSlot>{ItemSlot.robot},
    cost: 0,
    staticEffects: CardStaticEffects(const <CardStat, int>{}),
    behaviorIds: const <String>['gu4_rd_pre_attack_roll'],
  ),
};

final class _MvpCharacter {
  const _MvpCharacter({
    required this.health,
    required this.stats,
    required this.credits,
    required this.startItems,
    required this.equipped,
  });

  final int health;
  final PlayerStats stats;
  final int credits;
  final List<CardId> startItems;
  final EquippedGear equipped;
}

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
