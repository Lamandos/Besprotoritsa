import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('combat pipeline', () {
    test('hero attack rolls strength plus weapon and subtracts defense', () {
      final result = step(
        _state(
          monster: _monster(health: 3, defense: 1),
          player: _player(strength: 2, weaponModifier: 1),
        ),
        const AttackCommand('ghoul-1'),
        FixedDiceRoller([4, 6, 1]),
      );

      expect(result.state.actionsLeft, 1);
      expect(result.state.monsters.single.damage, 1);
      expect(result.state.log.last, 'attack:ada:ghoul-1:1');
    });

    test('attack remains legal when monster defense equals the dice pool', () {
      final result = step(
        _state(
          monster: _monster(health: 3, defense: 1),
          player: _player(),
        ),
        const AttackCommand('ghoul-1'),
        FixedDiceRoller([6]),
      );

      expect(result.rejection, isNull);
      expect(result.state.actionsLeft, 1);
      expect(result.state.monsters.single.damage, 0);
    });

    test('pistol reroll accepts exactly one selected die', () {
      final state = _state(
        monster: _monster(health: 2),
        player: _player(
          equipped: const EquippedGear(weapon: 'pistol'),
        ),
        cards: <CardId, CardDefinition>{
          'pistol': _card(
            'pistol',
            behaviorIds: const ['pistol_attack_reroll'],
          ),
        },
      );
      final attacked = step(
        state,
        const AttackCommand('ghoul-1'),
        FixedDiceRoller([1]),
      );

      final rerolled = step(
        attacked.state,
        ResolvePendingDecisionCommand(
          RerollChoice(diceIndexes: const <int>[0]),
        ),
        FixedDiceRoller([6]),
      );
      final resolved = step(
        rerolled.state,
        const ResolvePendingDecisionCommand(KeepRollChoice()),
        FixedDiceRoller([]),
      );

      expect(resolved.rejection, isNull);
      expect(resolved.state.monsters.single.damage, 1);
    });

    test('GU4-RD deals target damage on a successful pre-attack roll', () {
      final result = step(
        _state(
          monster: _monster(health: 3),
          player: _player(equipped: const EquippedGear(robot: 'gu4-rd')),
          cards: <CardId, CardDefinition>{
            'gu4-rd': _card(
              'gu4-rd',
              behaviorIds: const ['gu4_rd_pre_attack_roll'],
            ),
          },
        ),
        const AttackCommand('ghoul-1'),
        // The pre-attack die succeeds, while the regular attack misses.
        FixedDiceRoller([4, 1]),
      );

      expect(result.rejection, isNull);
      expect(result.state.monsters.single.damage, 1);
    });

    test('monster damage opens dodge and assigns one condition on damage', () {
      final attacked = resolveColocation(
        _state(
          monster: _monster(attack: 2),
          player: _player(agility: 2),
          conditions: const ['malaise'],
        ),
      );
      final pending = attacked.pendingDecision! as AwaitingDodge;
      final resolved = step(
        attacked,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([6, 1]),
      );

      expect(pending.monsterDamage, 2);
      expect(pending.requiredAgilitySuccesses, 2);
      expect(resolved.state.players.single.damage, 1);
      expect(resolved.state.players.single.conditions, ['malaise']);
      expect(resolved.state.decks['conditions']!.drawPile, isEmpty);
    });

    test('hero defense reduces monster damage before the dodge roll', () {
      final attacked = resolveColocation(
        _state(
          monster: _monster(attack: 2),
          player: _player(equipped: const EquippedGear(armor: 'armor')),
          cards: <CardId, CardDefinition>{
            'armor': _card(
              'armor',
              type: ItemType.armor,
              slot: ItemSlot.armor,
              stats: const {CardStat.defense: 1},
            ),
          },
        ),
      );

      final pending = attacked.pendingDecision! as AwaitingDodge;
      expect(pending.monsterDamage, 1);
      final resolved = step(
        attacked,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([6]),
      );
      expect(resolved.state.players.single.damage, 0);
      expect(resolved.state.players.single.conditions, isEmpty);
    });

    test('condition penalties stack and any healing clears all conditions', () {
      final weakened = _state(
        player: _player(strength: 3, conditions: const ['malaise', 'malaise']),
        monster: _monster(health: 3),
        conditions: const [],
      );
      final attacked = step(
        weakened,
        const AttackCommand('ghoul-1'),
        FixedDiceRoller([6]),
      );
      final injured = _state(
        player: _player(
          damage: 2,
          conditions: const ['malaise', 'concussion'],
        ),
        conditions: const [],
      );
      final healed = step(
        injured,
        const HealCommand(1),
        FixedDiceRoller([]),
      );

      expect(attacked.state.monsters.single.damage, 1);
      expect(healed.state.players.single.damage, 1);
      expect(healed.state.players.single.conditions, isEmpty);
      expect(
        healed.state.decks['conditions']!.discardPile,
        ['malaise', 'concussion'],
      );
    });
  });

  group('resolveColocation', () {
    test('only monsters with attack strength block the event phase', () {
      final passive = step(
        _state(
          monster: _monster(movement: 0),
          events: const ['quiet-event'],
        ),
        const EndTurnCommand(),
        FixedDiceRoller([]),
      );
      final active = step(
        _state(
          monster: _monster(attack: 1, movement: 0),
          events: const ['quiet-event'],
        ),
        const EndTurnCommand(),
        FixedDiceRoller([]),
      );

      expect(passive.state.pendingDecision, isA<AwaitingEventOption>());
      expect(active.state.pendingDecision, isNull);
      expect(active.state.phase, GamePhase.playersTurn);
    });

    test('event blocking follows monster activity data', () {
      final passiveByRule = step(
        _state(
          monster: _monster(attack: 3, movement: 0),
          events: const ['quiet-event'],
          monsterDefinitions: {
            'ghoul': {'activity': 'passive'},
          },
        ),
        const EndTurnCommand(),
        FixedDiceRoller([]),
      );
      final activeByRule = step(
        _state(
          monster: _monster(movement: 0),
          events: const ['quiet-event'],
          monsterDefinitions: {
            'ghoul': {'activity': 'active'},
          },
        ),
        const EndTurnCommand(),
        FixedDiceRoller([]),
      );

      expect(passiveByRule.state.pendingDecision, isA<AwaitingEventOption>());
      expect(activeByRule.state.pendingDecision, isNull);
      expect(activeByRule.state.phase, GamePhase.playersTurn);
    });

    test('replacement selection resumes damage queued for another hero', () {
      var state = resolveColocation(
        _state(
          monster: _monster(attack: 1),
          players: [
            _player(damage: 2),
            _player(id: 'boris', damage: 2),
          ],
          reserveHeroes: [
            ReserveHero(
              characterId: 'scientist',
              health: 3,
              stats: const PlayerStats(),
            ),
          ],
        ),
      );

      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1]),
      ).state;
      expect(state.pendingDecision, isA<AwaitingHeroReplacement>());

      state = step(
        state,
        const ResolvePendingDecisionCommand(
          SelectReplacementHeroChoice('scientist'),
        ),
        FixedDiceRoller([]),
      ).state;

      expect(state.pendingDecision, isA<AwaitingDodge>());
      expect(
        (state.pendingDecision! as AwaitingDodge).targetPlayerId,
        'boris',
      );
    });

    test('a Boil spawned under a hero detonates once and is removed', () {
      final spawned = spawnBoil(
        _state(player: _player()),
        const BoilToken(instanceId: 'boil-1', coord: HexCoord(0, 0)),
      );
      final resolved = step(
        spawned,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1]),
      );

      expect(spawned.boils, isEmpty);
      expect(spawned.pendingDecision, isA<AwaitingDodge>());
      expect(resolved.state.players.single.damage, 1);
      expect(resolved.state.players.single.conditions, isEmpty);
    });

    test('a spawned Boil does not re-trigger monsters in other cells', () {
      final spawned = spawnBoil(
        _state(
          players: [
            _player(),
            _player(id: 'boris', coord: const HexCoord(0, 1)),
          ],
          monster: _monster(coord: const HexCoord(0, 1), attack: 2),
        ),
        const BoilToken(instanceId: 'boil-1', coord: HexCoord(0, 0)),
      );

      final dodge = spawned.pendingDecision! as AwaitingDodge;
      expect(dodge.source, DamageSource.boil);
      expect(dodge.targetPlayerId, 'ada');
      expect(spawned.pendingDamage, isEmpty);
      expect(spawned.players.last.damage, 0);
    });

    test('plague doctor mask cancels Boil damage but consumes the Boil', () {
      final spawned = spawnBoil(
        _state(
          player: _player(
            equipped: const EquippedGear(armor: 'plague-doctor-mask'),
          ),
          cards: <CardId, CardDefinition>{
            'plague-doctor-mask': _card(
              'plague-doctor-mask',
              type: ItemType.armor,
              slot: ItemSlot.armor,
              behaviorIds: const ['damage.ignoreBoil'],
            ),
          },
        ),
        const BoilToken(instanceId: 'boil-immune', coord: HexCoord(0, 0)),
      );

      expect(spawned.pendingDecision, isNull);
      expect(spawned.players.single.damage, 0);
      expect(spawned.boils, isEmpty);
    });

    test(
      'a passing monster attacks every hero and continues to destination',
      () {
        final moved = moveMonsterOneStep(
          _state(
            monster: _monster(coord: const HexCoord(0, -1), attack: 1),
            players: [
              _player(),
              _player(id: 'boris'),
            ],
          ),
          'ghoul-1',
          const HexCoord(0, 0),
        );
        final afterAda = step(
          moved,
          const ResolvePendingDecisionCommand(DodgeChoice()),
          FixedDiceRoller([1]),
        );
        final afterBoris = step(
          afterAda.state,
          const ResolvePendingDecisionCommand(DodgeChoice()),
          FixedDiceRoller([1]),
        );

        expect(moved.monsters.single.coord, const HexCoord(0, 0));
        expect(
          (afterAda.state.pendingDecision! as AwaitingDodge).targetPlayerId,
          'boris',
        );
        expect(afterBoris.state.pendingDecision, isNull);
        expect(afterBoris.state.players.map((player) => player.damage), [1, 1]);
      },
    );

    test('vent capable monsters path and move between matching vents', () {
      final board = [
        _tile(const HexCoord(0, 0), ventColor: VentColor.red),
        _tile(const HexCoord(1, 0)),
        _tile(const HexCoord(2, 0)),
        _tile(const HexCoord(0, 2), ventColor: VentColor.red),
      ];
      final state = _state(
        board: board,
        monster: _monster(),
        players: [
          _player(coord: const HexCoord(2, 0)),
          _player(id: 'vent-target', coord: const HexCoord(0, 2)),
        ],
        monsterDefinitions: {
          'ghoul': {
            'features': ['moves-through-vents'],
          },
        },
      );

      expect(
        nearestTargets(state, state.monsters.single).first.id,
        'vent-target',
      );
      final moved = moveMonsterOneStep(
        state,
        'ghoul-1',
        const HexCoord(0, 2),
      );
      expect(moved.monsters.single.coord, const HexCoord(0, 2));
    });

    test('monster without vent capability cannot use a vent edge', () {
      final state = _state(
        board: [
          _tile(const HexCoord(0, 0), ventColor: VentColor.red),
          _tile(const HexCoord(0, 2), ventColor: VentColor.red),
        ],
        monster: _monster(),
        players: [_player(coord: const HexCoord(0, 2))],
        monsterDefinitions: {
          'ghoul': {'features': <String>[]},
        },
      );

      expect(nearestTargets(state, state.monsters.single), isEmpty);
      expect(
        () => moveMonsterOneStep(
          state,
          'ghoul-1',
          const HexCoord(0, 2),
        ),
        throwsArgumentError,
      );
    });

    test(
      'monster path and movement both reject mismatched exits and closed tiles',
      () {
        final start = _tile(const HexCoord(0, 0));
        final end = HexTile(
          id: 'closed',
          coord: const HexCoord(0, 1),
          type: HexTileType.corridor,
          opened: true,
          exits: const {HexEdge.south},
          hasTerminal: false,
          ventColor: VentColor.none,
        );
        final state = _state(
          board: [start, end],
          monster: _monster(),
          players: [_player(coord: const HexCoord(0, 1))],
        );

        expect(nearestTargets(state, state.monsters.single), isEmpty);
        expect(
          () => moveMonsterOneStep(
            state,
            'ghoul-1',
            const HexCoord(0, 1),
          ),
          throwsArgumentError,
        );

        final closed = HexTile(
          id: 'closed-target',
          coord: const HexCoord(0, 1),
          type: HexTileType.corridor,
          opened: false,
          exits: const {HexEdge.north, HexEdge.south},
          hasTerminal: false,
          ventColor: VentColor.none,
        );
        final closedState = _state(
          board: [start, closed],
          monster: _monster(),
          players: [_player(coord: const HexCoord(0, 1))],
        );
        expect(
          nearestTargets(closedState, closedState.monsters.single),
          isEmpty,
        );
        expect(
          () => moveMonsterOneStep(
            closedState,
            'ghoul-1',
            const HexCoord(0, 1),
          ),
          throwsArgumentError,
        );
      },
    );

    test('monster target ties prefer lower health then player order', () {
      final state = _state(
        board: [
          const HexCoord(0, 0),
          const HexCoord(0, 1),
          const HexCoord(1, 0),
          const HexCoord(1, -1),
        ].map(_tile),
        monster: _monster(),
        players: [
          _player(coord: const HexCoord(0, 1), damage: 1),
          _player(id: 'lower-health', coord: const HexCoord(1, 0), damage: 2),
          _player(id: 'later', coord: const HexCoord(1, -1), damage: 1),
        ],
      );

      expect(
        nearestTargets(state, state.monsters.single).map((player) => player.id),
        ['lower-health', 'ada', 'later'],
      );
    });
  });
}

GameState _state({
  PlayerState? player,
  Iterable<PlayerState>? players,
  MonsterInstance? monster,
  Iterable<ReserveHero> reserveHeroes = const [],
  Iterable<String> conditions = const ['concussion'],
  Iterable<String> events = const [],
  Map<CardId, CardDefinition> cards = const <CardId, CardDefinition>{},
  Map<CardId, Map<String, Object?>> monsterDefinitions = const {},
  Iterable<HexTile>? board,
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.players,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board:
      board ??
      [
        _tile(const HexCoord(0, -1)),
        _tile(const HexCoord(0, 0)),
        _tile(const HexCoord(0, 1)),
      ],
  players: players ?? [player ?? _player()],
  monsters: [if (monster != null) monster],
  reserveHeroes: reserveHeroes,
  decks: {
    'conditions': DeckState(drawPile: conditions),
    'events': DeckState(drawPile: events),
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
  cardDefinitions: cards,
  monsterDefinitions: monsterDefinitions,
  quests: QuestState(),
);

HexTile _tile(HexCoord coord, {VentColor ventColor = VentColor.none}) =>
    HexTile(
      id: 'tile-${coord.q}-${coord.r}',
      coord: coord,
      type: HexTileType.corridor,
      opened: true,
      exits: HexEdge.values.toSet(),
      hasTerminal: false,
      ventColor: ventColor,
    );

PlayerState _player({
  String id = 'ada',
  HexCoord coord = const HexCoord(0, 0),
  int strength = 1,
  int agility = 1,
  int weaponModifier = 0,
  int damage = 0,
  int health = 3,
  Iterable<String> conditions = const [],
  EquippedGear equipped = const EquippedGear(),
}) => PlayerState(
  id: id,
  characterId: '$id-character',
  coord: coord,
  damage: damage,
  health: health,
  credits: 0,
  backpack: const [],
  equipped: equipped,
  carriedMods: const [],
  implanted: const [],
  conditions: conditions,
  alive: true,
  stats: PlayerStats(strength: strength, agility: agility),
  weaponModifier: weaponModifier,
);

MonsterInstance _monster({
  HexCoord coord = const HexCoord(0, 0),
  int health = 1,
  int defense = 0,
  int attack = 0,
  int movement = 1,
}) => MonsterInstance(
  instanceId: 'ghoul-1',
  monsterId: 'ghoul',
  coord: coord,
  damage: 0,
  health: health,
  defense: defense,
  attack: attack,
  movement: movement,
);

CardDefinition _card(
  String id, {
  List<String> behaviorIds = const [],
  ItemType type = ItemType.robot,
  ItemSlot slot = ItemSlot.robot,
  Map<CardStat, int> stats = const <CardStat, int>{},
}) => CardDefinition(
  id: id,
  type: type,
  slots: <ItemSlot>{slot},
  cost: 0,
  staticEffects: CardStaticEffects(stats),
  behaviorIds: behaviorIds,
);
