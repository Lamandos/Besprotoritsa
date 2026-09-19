import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test(
    'a lethal hit creates an equipped Restless and queues a replacement',
    () {
      const sector = HexCoord(0, 1);
      var state = _state(
        player: _hero(
          coord: sector,
          damage: 2,
          credits: 7,
          backpack: const ['supply'],
          equipped: const EquippedGear(
            weapon: 'power-blade',
            armor: 'reinforced-armor',
            clothing: 'lab-coat',
          ),
        ),
        reserveHeroes: [
          ReserveHero(
            characterId: 'scientist',
            health: 8,
            credits: 5,
            stats: const PlayerStats(science: 4),
          ),
        ],
      );

      state = spawnMonster(
        state,
        MonsterInstance(
          instanceId: 'ghoul-1',
          monsterId: 'ghoul',
          coord: sector,
          damage: 0,
          health: 2,
          attack: 1,
        ),
      );
      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1]),
      ).state;

      final deceased = state.players.single;
      final restless = state.monsters.singleWhere(
        (monster) => monster.monsterId == RestlessMonster.restlessMonsterId,
      );
      expect(deceased.alive, isFalse);
      expect(deceased.credits, 0);
      expect(deceased.backpack, isEmpty);
      expect(restless, isA<RestlessMonster>());
      expect(restless.coord, sector);
      expect(restless.attack, 3); // base 1 + the equipped weapon's strength 2
      expect(restless.defense, 3); // base 0 + the equipped armor's defense 3
      expect(
        restless.carriedGear,
        containsAll(['power-blade', 'reinforced-armor', 'lab-coat']),
      );
      expect(restless.carriedGear, isNot(contains('supply')));
      expect(state.pendingDecision, isA<AwaitingHeroReplacement>());

      state = step(
        state,
        const ResolvePendingDecisionCommand(
          SelectReplacementHeroChoice('scientist'),
        ),
        FixedDiceRoller([]),
      ).state;
      expect(state.queuedReplacements['ada']!.characterId, 'scientist');
      expect(state.players.single.alive, isFalse);

      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      final replacement = state.players.single;
      expect(replacement.characterId, 'scientist');
      expect(replacement.alive, isTrue);
      expect(replacement.coord, const HexCoord(0, 0));
      expect(replacement.credits, 5);
      expect(state.queuedReplacements, isEmpty);
    },
  );

  test('defeating a Restless places its gear in the victor inventory', () {
    final hero = _hero(stats: const PlayerStats(strength: 1));
    final state = _state(
      player: hero,
      monsters: [
        RestlessMonster(
          instanceId: 'restless-1',
          coord: hero.coord,
          attack: 1,
          defense: 0,
          carriedGear: const ['power-blade', 'reinforced-armor'],
        ),
      ],
    );

    final result = step(
      state,
      const AttackCommand('restless-1'),
      FixedDiceRoller([6]),
    );

    expect(result.state.monsters, isEmpty);
    expect(
      result.state.players.single.backpack,
      containsAll(['power-blade', 'reinforced-armor']),
    );
  });

  test('the team loses immediately when a lethal hero has no reserve', () {
    final hero = _hero(damage: 2);
    var state = _state(player: hero);
    state = spawnMonster(
      state,
      MonsterInstance(
        instanceId: 'ghoul-1',
        monsterId: 'ghoul',
        coord: hero.coord,
        damage: 0,
        health: 2,
        attack: 1,
      ),
    );

    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([1]),
    ).state;

    expect(state.isComplete, isTrue);
    expect(state.pendingDecision, isNull);
    expect(
      state.monsters.any(
        (monster) => monster.monsterId == RestlessMonster.restlessMonsterId,
      ),
      isTrue,
    );
  });
}

GameState _state({
  PlayerState? player,
  Iterable<MonsterInstance> monsters = const [],
  Iterable<ReserveHero> reserveHeroes = const [],
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile('anabiosis', const HexCoord(0, 0), HexTileType.start),
    _tile('sector', const HexCoord(0, 1), HexTileType.corridor),
  ],
  players: [player ?? _hero()],
  monsters: monsters,
  reserveHeroes: reserveHeroes,
  decks: const {},
  cardDefinitions: {
    'power-blade': _card(
      'power-blade',
      ItemType.weapon,
      const {CardStat.strength: 2},
    ),
    'reinforced-armor': _card(
      'reinforced-armor',
      ItemType.armor,
      const {CardStat.defense: 3},
    ),
    'lab-coat': _card('lab-coat', ItemType.clothing, const {
      CardStat.science: 5,
    }),
    'supply': _card('supply', ItemType.supply, const {}),
  },
  quests: QuestState(),
);

CardDefinition _card(String id, ItemType type, Map<CardStat, int> modifiers) =>
    CardDefinition(
      id: id,
      type: type,
      slots: switch (type) {
        ItemType.weapon => const {ItemSlot.weapon},
        ItemType.armor => const {ItemSlot.armor},
        ItemType.clothing => const {ItemSlot.clothing},
        ItemType.robot => const {ItemSlot.robot},
        ItemType.modification => const {ItemSlot.modification},
        ItemType.supply || ItemType.specialItem => const {},
      },
      cost: 0,
      staticEffects: CardStaticEffects(modifiers),
    );

PlayerState _hero({
  HexCoord coord = const HexCoord(0, 0),
  int damage = 0,
  int health = 3,
  int credits = 0,
  Iterable<String> backpack = const [],
  EquippedGear equipped = const EquippedGear(),
  PlayerStats stats = const PlayerStats(),
}) => PlayerState(
  id: 'ada',
  characterId: 'guard',
  coord: coord,
  damage: damage,
  health: health,
  credits: credits,
  backpack: backpack,
  equipped: equipped,
  carriedMods: const [],
  implanted: const [],
  conditions: const [],
  alive: true,
  stats: stats,
);

HexTile _tile(String id, HexCoord coord, HexTileType type) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: true,
  exits: HexEdge.values.toSet(),
  hasTerminal: false,
  ventColor: VentColor.none,
);
