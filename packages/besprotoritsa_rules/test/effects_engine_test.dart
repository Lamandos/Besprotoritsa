import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('two-tier card effects', () {
    test('Pneumo cannon treats 3 as a hit and damages its shooter on 6', () {
      final cannon = _card(
        id: 'pneumo-cannon',
        stats: const {'strength': 1},
        behaviorIds: const ['dice.successFace.3', 'dice.face6.damageBoth'],
      );
      EffectRegistry.standard().requireValid(cannon);
      expect(cannon.type, ItemType.weapon);
      expect(cannon.slots, {ItemSlot.weapon});
      expect(cannon.cost, 8);
      expect(cannon.staticEffects[CardStat.strength], 1);
      expect(cannon.staticEffects.range, 1);

      final result = step(
        _state(cards: [cannon], weapon: cannon.id, monsterHealth: 2),
        const AttackCommand('enemy-1'),
        FixedDiceRoller([3, 6]),
      );

      expect(result.state.monsters, isEmpty);
      expect(result.state.players.single.damage, 1);
      expect(result.state.actionsLeft, 1);
    });

    test(
      'Circular saw permits two one-die rerolls before its attack resolves',
      () {
        final saw = _card(
          id: 'circular-saw',
          behaviorIds: const ['dice.reroll.twoPerAttack'],
        );
        final rolled = step(
          _state(
            cards: [saw],
            weapon: saw.id,
            playerStrength: 2,
            monsterHealth: 2,
          ),
          const AttackCommand('enemy-1'),
          FixedDiceRoller([1, 1, 6, 6]),
        );
        final pending = rolled.state.pendingDecision! as AwaitingRerollChoice;

        final firstReroll = step(
          rolled.state,
          ResolvePendingDecisionCommand(RerollChoice(diceIndexes: const [0])),
          FixedDiceRoller([6, 6]),
        );
        final secondReroll = step(
          firstReroll.state,
          ResolvePendingDecisionCommand(RerollChoice(diceIndexes: const [1])),
          FixedDiceRoller([6]),
        );
        final resolved = step(
          secondReroll.state,
          const ResolvePendingDecisionCommand(KeepRollChoice()),
          FixedDiceRoller([]),
        );

        expect(pending.availableRerolls, 2);
        expect(pending.maxDicePerReroll, 1);
        expect(resolved.state.monsters, isEmpty);
        expect(resolved.state.actionsLeft, 1);
      },
    );

    test(
      'Laser cutter deals chained damage to every enemy in the killed sector',
      () {
        final cutter = _card(
          id: 'laser-cutter',
          behaviorIds: const ['combat.damageAllEnemiesInSectorOnKill'],
        );
        final result = step(
          _state(
            cards: [cutter],
            weapon: cutter.id,
            extraMonsters: [
              _monster('enemy-2'),
              _monster('enemy-away', coord: const HexCoord(0, 1)),
            ],
          ),
          const AttackCommand('enemy-1'),
          FixedDiceRoller([6]),
        );

        expect(result.state.monsters.map((monster) => monster.instanceId), [
          'enemy-away',
        ]);
      },
    );

    test('unknown behaviorId is reported as a data validation error', () {
      final invalid = _card(
        id: 'broken-card',
        behaviorIds: const ['not.in.the.registry'],
      );

      expect(
        () => EffectRegistry.standard().requireValid(invalid),
        throwsA(
          isA<EffectDataValidationException>().having(
            (error) => error.errors.single.behaviorId,
            'unknown id',
            'not.in.the.registry',
          ),
        ),
      );
    });
  });
}

CardDefinition _card({
  required String id,
  Map<String, int> stats = const {},
  List<String> behaviorIds = const [],
}) => CardDefinition.fromJson({
  'id': id,
  'category': 'weapon',
  'slots': ['weapon'],
  'cost': 8,
  'range': 1,
  'stats': stats,
  'behaviorIds': behaviorIds,
});

GameState _state({
  required List<CardDefinition> cards,
  required String weapon,
  int playerStrength = 1,
  int monsterHealth = 1,
  List<MonsterInstance> extraMonsters = const [],
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile(const HexCoord(0, 0)),
    _tile(const HexCoord(0, 1)),
  ],
  players: [
    PlayerState(
      id: 'ada',
      characterId: 'ada-character',
      coord: const HexCoord(0, 0),
      damage: 0,
      credits: 0,
      backpack: const [],
      equipped: EquippedGear(weapon: weapon),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
      stats: PlayerStats(strength: playerStrength),
    ),
  ],
  monsters: [
    _monster('enemy-1', health: monsterHealth),
    ...extraMonsters,
  ],
  decks: const {},
  quests: QuestState(),
  cardDefinitions: {for (final card in cards) card.id: card},
);

MonsterInstance _monster(
  String id, {
  HexCoord coord = const HexCoord(0, 0),
  int health = 1,
}) => MonsterInstance(
  instanceId: id,
  monsterId: 'test-monster',
  coord: coord,
  damage: 0,
  health: health,
);

HexTile _tile(HexCoord coord) => HexTile(
  id: 'tile-${coord.q}-${coord.r}',
  coord: coord,
  type: HexTileType.compartment,
  opened: true,
  exits: HexEdge.values,
  hasTerminal: false,
  ventColor: VentColor.none,
);
