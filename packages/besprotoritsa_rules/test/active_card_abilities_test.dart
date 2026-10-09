import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('BUG032 medic bag heals an adjacent hero for credits and an action', () {
    final state = _state(
      backpack: const ['medic-bag'],
      credits: 4,
      secondHeroDamage: 2,
    );

    final result = step(
      state,
      const UseCardAbilityCommand(
        'medic-bag',
        targetPlayerId: 'hero-2',
        amount: 2,
      ),
      SeededDiceRoller(11),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.credits, 2);
    expect(result.state.players.last.damage, 0);
    expect(result.state.actionsLeft, 1);
  });

  test('BUG032 a deployed tripwire kills the next non-boss entrant', () {
    final state = _state(backpack: const ['tripwire']);
    final placed = step(
      state,
      const UseCardAbilityCommand('tripwire'),
      SeededDiceRoller(12),
    );

    expect(placed.rejection, isNull);
    expect(placed.state.players.first.backpack, isEmpty);
    expect(placed.state.tripwires, hasLength(1));

    final entered = spawnMonster(
      placed.state,
      MonsterInstance(
        instanceId: 'ghoul-1',
        monsterId: 'ghoul',
        coord: const HexCoord(0, 0),
        damage: 0,
      ),
    );
    expect(entered.monsters, isEmpty);
    expect(entered.tripwires, isEmpty);
    expect(entered.decks['supplies']!.discardPile, contains('tripwire'));
  });

  test('BUG032 a consumable medicine is removed and restores health', () {
    final state = _state(backpack: const ['medkit'], damage: 3);
    final result = step(
      state,
      const UseCardAbilityCommand('medkit'),
      SeededDiceRoller(13),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.damage, 0);
    expect(result.state.players.first.backpack, isEmpty);
    expect(result.state.decks['supplies']!.discardPile, contains('medkit'));
    expect(result.state.actionsLeft, 2);
  });

  test('BUG039 consumable healing also clears and discards conditions', () {
    final state = _state(
      backpack: const ['medkit'],
      damage: 3,
      conditions: const ['infection'],
    );
    final result = step(
      state,
      const UseCardAbilityCommand('medkit'),
      SeededDiceRoller(131),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.damage, 0);
    expect(result.state.players.first.conditions, isEmpty);
    expect(
      result.state.decks['conditions']!.discardPile,
      contains('infection'),
    );
  });

  test('BUG039 medic bag healing also clears and discards conditions', () {
    final state = _state(
      backpack: const ['medic-bag'],
      credits: 2,
      damage: 2,
      conditions: const ['infection'],
    );
    final result = step(
      state,
      const UseCardAbilityCommand(
        'medic-bag',
        targetPlayerId: 'hero-1',
        amount: 1,
      ),
      SeededDiceRoller(132),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.conditions, isEmpty);
    expect(
      result.state.decks['conditions']!.discardPile,
      contains('infection'),
    );
  });

  test('BUG039 H3-AL healing also clears and discards conditions', () {
    final state = _state(
      equippedRobot: 'h3-al',
      secondHeroDamage: 2,
      secondConditions: const ['infection'],
    );
    final result = step(
      state,
      const UseCardAbilityCommand('h3-al', targetPlayerId: 'hero-2'),
      SeededDiceRoller(133),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.last.conditions, isEmpty);
    expect(
      result.state.decks['conditions']!.discardPile,
      contains('infection'),
    );
  });

  test(
    'BUG038 proton shield activates without crashing and prevents damage',
    () {
      final state = _state(backpack: const ['proton-shield'], damage: 1);
      late GameStepResult result;

      expect(
        () => result = step(
          state,
          const UseCardAbilityCommand('proton-shield'),
          SeededDiceRoller(134),
        ),
        returnsNormally,
      );

      expect(result.rejection, isNull);
      expect(result.state.players.first.damageImmuneThroughRound, state.round);
      expect(result.state.players.first.backpack, isEmpty);
      expect(
        result.state.decks['supplies']!.discardPile,
        contains('proton-shield'),
      );
    },
  );

  test(
    'BUG032 air canister spends two actions and transfers between airlocks',
    () {
      final state = _state(
        backpack: const ['air-canister'],
        board: [
          _tile('source', const HexCoord(0, 0), HexTileType.airlock),
          _tile('destination', const HexCoord(4, 0), HexTileType.airlock),
        ],
      );

      final result = step(
        state,
        const UseCardAbilityCommand(
          'air-canister',
          targetCoord: HexCoord(4, 0),
        ),
        SeededDiceRoller(14),
      );

      expect(result.rejection, isNull);
      expect(result.state.players.first.coord, const HexCoord(4, 0));
      expect(result.state.players.first.backpack, isEmpty);
      expect(result.state.actionsLeft, 0);
      expect(
        result.state.decks['supplies']!.discardPile,
        contains('air-canister'),
      );
    },
  );

  test('BUG032 door remote spends credits and toggles a corridor', () {
    final state = _state(
      backpack: const ['door-remote'],
      credits: 4,
      board: [
        _tile('start', const HexCoord(0, 0), HexTileType.start),
        _tile('hall', const HexCoord(2, 0), HexTileType.corridor),
      ],
    );

    final result = step(
      state,
      const UseCardAbilityCommand(
        'door-remote',
        targetCoord: HexCoord(2, 0),
      ),
      SeededDiceRoller(15),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.credits, 2);
    expect(result.state.actionsLeft, 1);
    expect(result.state.tileAt(const HexCoord(2, 0))!.isBlocked, isTrue);
    expect(result.state.players.first.backpack, contains('door-remote'));
  });

  test(
    'BUG032 H3-AL heals a teammate and rotates without losing static defense',
    () {
      final state = _state(
        equippedRobot: 'h3-al',
        secondHeroDamage: 2,
      );

      final result = step(
        state,
        const UseCardAbilityCommand('h3-al', targetPlayerId: 'hero-2'),
        SeededDiceRoller(16),
      );

      expect(result.rejection, isNull);
      expect(result.state.players.last.damage, 0);
      expect(result.state.players.first.exhaustedRobots, contains('h3-al'));
      expect(heroDefense(result.state, result.state.players.first), 1);
      expect(result.state.actionsLeft, 2);
    },
  );

  test('BUG032 power cell readies an exhausted robot and goes to discard', () {
    final state = _state(
      backpack: const ['power-cell'],
      exhaustedRobots: const ['h3-al'],
    );

    final result = step(
      state,
      const UseCardAbilityCommand('power-cell', targetCardId: 'h3-al'),
      SeededDiceRoller(17),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.exhaustedRobots, isEmpty);
    expect(result.state.players.first.backpack, isEmpty);
    expect(result.state.decks['supplies']!.discardPile, contains('power-cell'));
  });

  test('BUG032 C6-CAR Courier allows a remote exchange without an action', () {
    final state = _state(
      equippedRobot: 'c6-car-courier',
      credits: 3,
      actionsLeft: 0,
    );

    final result = step(
      state,
      const ExchangeCommand(partnerId: 'hero-2', giveCredits: 1),
      SeededDiceRoller(18),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.credits, 2);
    expect(result.state.players.last.credits, 1);
    expect(
      result.state.players.first.exhaustedRobots,
      contains('c6-car-courier'),
    );
    expect(result.state.actionsLeft, 0);
  });

  test(
    'BUG032 smuggler mark allows a remote one-card exchange for an action',
    () {
      final state = _state(
        backpack: const ['smuggler-mark', 'medkit'],
        actionsLeft: 1,
      );
      final result = step(
        state,
        const ExchangeCommand(partnerId: 'hero-2', giveCardId: 'medkit'),
        SeededDiceRoller(23),
      );

      expect(result.rejection, isNull);
      expect(result.state.players.first.backpack, contains('smuggler-mark'));
      expect(result.state.players.first.backpack, isNot(contains('medkit')));
      expect(result.state.players.last.backpack, contains('medkit'));
      expect(result.state.actionsLeft, 0);
    },
  );

  test('BUG041 an exhausted robot stays exhausted when transferred', () {
    final state = _state(
      equippedRobot: 'r69-nic3',
      secondHeroCoord: const HexCoord(0, 0),
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('r69-nic3'),
      SeededDiceRoller(135),
    );
    final exchanged = step(
      activated.state,
      const ExchangeCommand(
        partnerId: 'hero-2',
        giveCards: [
          InventoryCardSelection(
            cardId: 'r69-nic3',
            area: InventoryCardArea.robot,
          ),
        ],
      ),
      SeededDiceRoller(136),
    );

    expect(activated.rejection, isNull);
    expect(exchanged.rejection, isNull);
    expect(exchanged.state.players.first.equipped.robot, isNull);
    expect(
      exchanged.state.players.first.exhaustedRobots,
      isNot(contains('r69-nic3')),
    );
    expect(exchanged.state.players.last.backpack, contains('r69-nic3'));
    expect(
      exchanged.state.players.last.exhaustedRobots,
      contains('r69-nic3'),
    );
  });

  test('BUG032 skill stimulant is consumed in the reroll window', () {
    final state = _state(backpack: const ['science-stimulant']);
    final roll = step(
      state,
      const SkillCheckCommand(StatType.science),
      SeededDiceRoller(19),
    );

    expect(roll.rejection, isNull);
    final pending = roll.state.pendingDecision! as AwaitingRerollChoice;
    expect(pending.availableRerolls, 1);
    expect(pending.maxDicePerReroll, 1);
    expect(pending.rerollSources, ['science-stimulant']);

    final rerolled = step(
      roll.state,
      ResolvePendingDecisionCommand(
        RerollChoice(diceIndexes: [0]),
      ),
      SeededDiceRoller(20),
    );

    expect(rerolled.rejection, isNull);
    expect(rerolled.state.players.first.backpack, isEmpty);
    expect(
      rerolled.state.decks['supplies']!.discardPile,
      contains('science-stimulant'),
    );
    expect(
      (rerolled.state.pendingDecision! as AwaitingRerollChoice)
          .availableRerolls,
      0,
    );
  });

  test('BUG032 defibrillator rerolls any dice in a skill check', () {
    final state = _state(
      backpack: const ['science-stimulant', 'defibrillator'],
    );
    final roll = step(
      state,
      const SkillCheckCommand(StatType.science),
      SeededDiceRoller(24),
    );

    expect(roll.rejection, isNull);
    final pending = roll.state.pendingDecision! as AwaitingRerollChoice;
    expect(pending.availableRerolls, 2);
    expect(pending.maxDicePerReroll, greaterThan(1));
    expect(
      pending.rerollSources,
      ['defibrillator', 'science-stimulant'],
    );
  });

  test('BUG032 robot skill reroll rotates its source robot', () {
    final state = _state(equippedRobot: 'sc13-nc3');
    final roll = step(
      state,
      const SkillCheckCommand(StatType.science),
      SeededDiceRoller(21),
    );
    final rerolled = step(
      roll.state,
      ResolvePendingDecisionCommand(RerollChoice()),
      SeededDiceRoller(22),
    );

    expect(rerolled.rejection, isNull);
    expect(rerolled.state.players.first.exhaustedRobots, contains('sc13-nc3'));
    expect(
      (rerolled.state.pendingDecision! as AwaitingRerollChoice).rerollSources,
      isEmpty,
    );
  });

  test('BUG032 R69-NIC3 can ignore non-boss enemy features for its owner', () {
    final state = _state(
      equippedRobot: 'r69-nic3',
      monsters: [
        MonsterInstance(
          instanceId: 'drekovac-1',
          monsterId: 'drekovac',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 5,
          movement: 0,
        ),
      ],
      monsterDefinitions: {
        'drekovac': {
          'features': ['reduces-combat-strength'],
        },
      },
      playerStats: const PlayerStats(strength: 3, combatStrength: 3),
    );

    final activated = step(
      state,
      const UseCardAbilityCommand('r69-nic3'),
      SeededDiceRoller(25),
    );
    expect(activated.rejection, isNull);
    expect(activated.state.players.first.exhaustedRobots, contains('r69-nic3'));
    expect(activated.state.players.first.enemyFeaturesIgnoredThroughRound, 1);

    final attacked = step(
      activated.state,
      const AttackCommand('drekovac-1'),
      FixedDiceRoller([4, 4, 4]),
    );
    expect(attacked.rejection, isNull);
    expect(attacked.state.monsters.single.damage, 3);
  });

  test('BUG032 a non-boss enemy blocks exits unless its effect is ignored', () {
    final state = _state(
      monsters: [
        MonsterInstance(
          instanceId: 'likho-1',
          monsterId: 'likho',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 3,
          defense: 2,
          attack: 2,
          movement: 0,
        ),
      ],
      monsterDefinitions: {
        'likho': {
          'features': ['stationary', 'blocks-exits'],
        },
      },
    );

    expect(
      validate(state, const MoveCommand(HexCoord(1, 0))),
      isA<PathBlocked>(),
    );

    final protected = _state(
      equippedRobot: 'alarm-bot',
      monsters: state.monsters,
      monsterDefinitions: state.monsterDefinitions,
    );
    final activated = step(
      protected,
      const UseCardAbilityCommand('alarm-bot'),
      SeededDiceRoller(26),
    );
    final moved = step(
      activated.state,
      const MoveCommand(HexCoord(1, 0)),
      SeededDiceRoller(27),
    );

    expect(activated.rejection, isNull);
    expect(moved.rejection, isNull);
    expect(moved.state.players.first.coord, const HexCoord(1, 0));

    final teammate = _state(
      activePlayerId: 'hero-2',
      equippedRobot: 'alarm-bot',
      enemyFeaturesIgnoredThroughRound: 1,
      secondHeroCoord: const HexCoord(0, 0),
      monsters: state.monsters,
      monsterDefinitions: state.monsterDefinitions,
    );
    expect(
      validate(teammate, const MoveCommand(HexCoord(1, 0))),
      isA<PathBlocked>(),
    );
  });

  test(
    'BUG032 enemy combat penalty still applies to a teammate of R69 owner',
    () {
      final state = _state(
        activePlayerId: 'hero-2',
        equippedRobot: 'r69-nic3',
        enemyFeaturesIgnoredThroughRound: 1,
        monsters: [
          MonsterInstance(
            instanceId: 'drekovac-2',
            monsterId: 'drekovac',
            coord: const HexCoord(1, 0),
            damage: 0,
            health: 5,
            movement: 0,
          ),
        ],
        monsterDefinitions: {
          'drekovac': {
            'features': ['reduces-combat-strength'],
          },
        },
        secondHeroStats: const PlayerStats(strength: 3, combatStrength: 3),
      );

      final attacked = step(
        state,
        const AttackCommand('drekovac-2'),
        FixedDiceRoller([4, 4, 4]),
      );

      expect(attacked.rejection, isNull);
      expect(attacked.state.monsters.single.damage, 2);
    },
  );

  test('BUG032 R69 effect expires when the next round begins', () {
    final state = _state(
      roundNumber: 2,
      equippedRobot: 'r69-nic3',
      exhaustedRobots: const ['r69-nic3'],
      enemyFeaturesIgnoredThroughRound: 1,
      monsters: [
        MonsterInstance(
          instanceId: 'drekovac-expired',
          monsterId: 'drekovac',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 5,
          movement: 0,
        ),
      ],
      monsterDefinitions: {
        'drekovac': {
          'features': ['reduces-combat-strength'],
        },
      },
      playerStats: const PlayerStats(strength: 3, combatStrength: 3),
    );

    final attacked = step(
      state,
      const AttackCommand('drekovac-expired'),
      FixedDiceRoller([4, 4, 4]),
    );

    expect(attacked.rejection, isNull);
    expect(attacked.state.monsters.single.damage, 2);
  });

  test('BUG032 R69 does not suppress a boss feature', () {
    final activated = step(
      _state(
        equippedRobot: 'r69-nic3',
        monsters: [
          MonsterInstance(
            instanceId: 'boss-1',
            monsterId: 'boss',
            coord: const HexCoord(0, 0),
            damage: 0,
            health: 5,
            movement: 0,
          ),
        ],
        monsterDefinitions: {
          'boss': {
            'features': ['boss', 'reduces-combat-strength'],
          },
        },
        playerStats: const PlayerStats(strength: 3, combatStrength: 3),
      ),
      const UseCardAbilityCommand('r69-nic3'),
      SeededDiceRoller(29),
    );
    final attacked = step(
      activated.state,
      const AttackCommand('boss-1'),
      FixedDiceRoller([4, 4]),
    );

    expect(activated.rejection, isNull);
    expect(attacked.rejection, isNull);
    expect(attacked.state.monsters.single.damage, 2);
  });

  test('BUG032 R69 does not cancel global Boil effects', () {
    final activated = step(
      _state(equippedRobot: 'alarm-bot'),
      const UseCardAbilityCommand('alarm-bot'),
      SeededDiceRoller(28),
    );
    final spawned = spawnBoil(
      activated.state,
      const BoilToken(instanceId: 'global-boil', coord: HexCoord(0, 0)),
    );

    expect(activated.rejection, isNull);
    expect(spawned.pendingDecision, isA<AwaitingDodge>());
    expect(
      (spawned.pendingDecision! as AwaitingDodge).source,
      DamageSource.boil,
    );
  });

  test('BUG032 R69 does not cancel monster movement', () {
    final state = _state(
      equippedRobot: 'r69-nic3',
      board: [
        _tile('approach', const HexCoord(0, -1), HexTileType.corridor),
        _tile('start', const HexCoord(0, 0), HexTileType.start),
        _tile('neighbor', const HexCoord(1, 0), HexTileType.compartment),
      ],
      monsters: [
        MonsterInstance(
          instanceId: 'global-mover',
          monsterId: 'pack',
          coord: const HexCoord(0, -1),
          damage: 0,
          health: 3,
        ),
      ],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('r69-nic3'),
      SeededDiceRoller(30),
    );
    final moved = moveMonsterOneStep(
      activated.state,
      'global-mover',
      const HexCoord(0, 0),
    );

    expect(activated.rejection, isNull);
    expect(moved.monsters.single.coord, const HexCoord(0, 0));
  });
}

GameState _state({
  Iterable<CardId> backpack = const [],
  int credits = 0,
  int damage = 0,
  int secondHeroDamage = 0,
  String? equippedRobot,
  Iterable<CardId> exhaustedRobots = const [],
  int actionsLeft = 2,
  int roundNumber = 1,
  String activePlayerId = 'hero-1',
  Iterable<CardId> conditions = const [],
  Iterable<CardId> secondConditions = const [],
  PlayerStats playerStats = const PlayerStats(),
  PlayerStats secondHeroStats = const PlayerStats(),
  HexCoord secondHeroCoord = const HexCoord(1, 0),
  int? enemyFeaturesIgnoredThroughRound,
  Iterable<MonsterInstance> monsters = const [],
  Map<String, Map<String, Object?>> monsterDefinitions = const {},
  Iterable<HexTile>? board,
}) => GameState(
  seed: 7,
  round: roundNumber,
  phase: GamePhase.playersTurn,
  activePlayerId: activePlayerId,
  actionsLeft: actionsLeft,
  board:
      board ??
      [
        _tile('start', const HexCoord(0, 0), HexTileType.start),
        _tile('neighbor', const HexCoord(1, 0), HexTileType.compartment),
      ],
  players: [
    PlayerState(
      id: 'hero-1',
      characterId: 'worker',
      coord: const HexCoord(0, 0),
      damage: damage,
      health: 5,
      credits: credits,
      backpack: backpack,
      equipped: EquippedGear(robot: equippedRobot),
      carriedMods: const [],
      implanted: const [],
      conditions: conditions,
      alive: true,
      stats: playerStats,
      exhaustedRobots: exhaustedRobots,
      enemyFeaturesIgnoredThroughRound: enemyFeaturesIgnoredThroughRound,
    ),
    PlayerState(
      id: 'hero-2',
      characterId: 'mechanic',
      coord: secondHeroCoord,
      damage: secondHeroDamage,
      health: 5,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: secondConditions,
      alive: true,
      stats: secondHeroStats,
    ),
  ],
  monsters: monsters,
  monsterDefinitions: monsterDefinitions,
  decks: {
    'supplies': DeckState(drawPile: const []),
    'monsters': DeckState(drawPile: const []),
    'conditions': DeckState(drawPile: const []),
  },
  conditionCards: {
    'infection': ConditionCard(id: 'infection'),
  },
  quests: QuestState(),
  cardDefinitions: {
    'medic-bag': CardDefinition(
      id: 'medic-bag',
      type: ItemType.supply,
      slots: const [],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'starterItems',
      behaviorIds: const ['action.spend', 'health.restorePerCredit'],
    ),
    'tripwire': CardDefinition(
      id: 'tripwire',
      type: ItemType.supply,
      slots: const [],
      cost: 5,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['action.spend', 'monster.trapOnEnter'],
    ),
    'medkit': CardDefinition(
      id: 'medkit',
      type: ItemType.supply,
      slots: const [],
      cost: 8,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'health.restoreAll'],
    ),
    'proton-shield': CardDefinition(
      id: 'proton-shield',
      type: ItemType.supply,
      slots: const [],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'damage.preventUntilRoundEnd'],
    ),
    'air-canister': CardDefinition(
      id: 'air-canister',
      type: ItemType.supply,
      slots: const [],
      cost: 4,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const [
        'card.discardCost',
        'action.spend',
        'map.moveAirlock',
      ],
    ),
    'door-remote': CardDefinition(
      id: 'door-remote',
      type: ItemType.supply,
      slots: const [],
      cost: 10,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const [
        'action.spend',
        'economy.spendCredits',
        'map.openCloseCorridor',
      ],
    ),
    'power-cell': CardDefinition(
      id: 'power-cell',
      type: ItemType.supply,
      slots: const [],
      cost: 7,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'robot.ready'],
    ),
    'h3-al': CardDefinition(
      id: 'h3-al',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {CardStat.defense: 1}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'health.restore'],
    ),
    'c6-car-courier': CardDefinition(
      id: 'c6-car-courier',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'map.remoteExchange'],
    ),
    'sc13-nc3': CardDefinition(
      id: 'sc13-nc3',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'dice.reroll.allForSkill'],
    ),
    'science-stimulant': CardDefinition(
      id: 'science-stimulant',
      type: ItemType.supply,
      slots: const [],
      cost: 3,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'dice.reroll.one'],
    ),
    'defibrillator': CardDefinition(
      id: 'defibrillator',
      type: ItemType.supply,
      slots: const [],
      cost: 4,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'dice.reroll.anyCountPerAttack'],
    ),
    'r69-nic3': CardDefinition(
      id: 'r69-nic3',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'robot.ignoreEnemyFeatures'],
    ),
    'alarm-bot': CardDefinition(
      id: 'alarm-bot',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'robot.ignoreEnemyFeatures'],
    ),
    'smuggler-mark': CardDefinition(
      id: 'smuggler-mark',
      type: ItemType.supply,
      slots: const [],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'starterItems',
      behaviorIds: const ['economy.purchaseDiscount.2', 'map.remoteExchange'],
    ),
  },
);

HexTile _tile(String id, HexCoord coord, HexTileType type) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: true,
  exits: HexEdge.values,
  hasTerminal: false,
  ventColor: VentColor.none,
);
