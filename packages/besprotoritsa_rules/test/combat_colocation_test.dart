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
  });
}

GameState _state({
  PlayerState? player,
  Iterable<PlayerState>? players,
  MonsterInstance? monster,
  Iterable<String> conditions = const ['concussion'],
  Map<CardId, CardDefinition> cards = const <CardId, CardDefinition>{},
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.players,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile(const HexCoord(0, -1)),
    _tile(const HexCoord(0, 0)),
    _tile(const HexCoord(0, 1)),
  ],
  players: players ?? [player ?? _player()],
  monsters: [if (monster != null) monster],
  decks: {
    'conditions': DeckState(drawPile: conditions),
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
  quests: QuestState(),
);

HexTile _tile(HexCoord coord) => HexTile(
  id: 'tile-${coord.q}-${coord.r}',
  coord: coord,
  type: HexTileType.corridor,
  opened: true,
  exits: HexEdge.values.toSet(),
  hasTerminal: false,
  ventColor: VentColor.none,
);

PlayerState _player({
  String id = 'ada',
  int strength = 1,
  int agility = 1,
  int weaponModifier = 0,
  int damage = 0,
  Iterable<String> conditions = const [],
  EquippedGear equipped = const EquippedGear(),
}) => PlayerState(
  id: id,
  characterId: '$id-character',
  coord: const HexCoord(0, 0),
  damage: damage,
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
}) => MonsterInstance(
  instanceId: 'ghoul-1',
  monsterId: 'ghoul',
  coord: coord,
  damage: 0,
  health: health,
  defense: defense,
  attack: attack,
);

CardDefinition _card(String id, {List<String> behaviorIds = const []}) =>
    CardDefinition(
      id: id,
      type: ItemType.robot,
      slots: const <ItemSlot>{ItemSlot.robot},
      cost: 0,
      staticEffects: CardStaticEffects(const <CardStat, int>{}),
      behaviorIds: behaviorIds,
    );
