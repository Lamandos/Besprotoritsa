import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('BUG074 discarding an exhausted robot clears its exhaustion', () {
    final state = _state(
      equippedRobot: 'h3-al',
      exhaustedRobots: const ['h3-al'],
      itemDeckDrawPile: const [],
    );

    final result = step(
      state,
      const DiscardCardCommand('h3-al'),
      SeededDiceRoller(148),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.equipped.robot, isNull);
    expect(result.state.players.first.exhaustedRobots, isEmpty);
  });

  test('BUG069 PROT2-CT cannot activate outside combat', () {
    final state = _state(equippedRobot: 'prot2-ct');

    final result = step(
      state,
      const UseCardAbilityCommand('prot2-ct'),
      SeededDiceRoller(150),
    );

    expect(result.rejection, isNotNull);
    expect(result.state.players.first.monsterDefenseBonusRound, isNull);
    expect(result.state.players.first.exhaustedRobots, isEmpty);
  });

  test('BUG069 PROT2-CT can activate during combat', () {
    final state = _state(
      equippedRobot: 'prot2-ct',
      monsters: [
        MonsterInstance(
          instanceId: 'ghoul-1',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 3,
        ),
      ],
    );

    final result = step(
      state,
      const UseCardAbilityCommand('prot2-ct'),
      SeededDiceRoller(151),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.monsterDefenseBonusRound, 1);
    expect(result.state.players.first.exhaustedRobots, ['prot2-ct']);
  });

  test('BUG056 GTU-B1c4 cannot bank a hit before combat', () {
    final state = _state(equippedRobot: 'gtu-b1c4');

    final result = step(
      state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(130),
    );

    expect(result.rejection, isNotNull);
    expect(result.state.players.first.nextAttackBonusHits, 0);
    expect(result.state.players.first.exhaustedRobots, isEmpty);
  });

  test('BUG056 GTU-B1c4 bonus is captured by the attack window', () {
    final opponent = MonsterInstance(
      instanceId: 'ghoul-1',
      monsterId: 'ghoul',
      coord: const HexCoord(0, 0),
      damage: 0,
      health: 20,
      attack: 1,
      movement: 0,
    );
    final state = _state(
      equippedRobot: 'gtu-b1c4',
      equippedWeapon: 'assault-rifle',
      monsters: [opponent],
    );
    final baseline = _state(
      equippedWeapon: 'assault-rifle',
      monsters: [opponent],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(141),
    );
    final pending = step(
      activated.state,
      const AttackCommand('ghoul-1'),
      SeededDiceRoller(142),
    );
    final baselinePending = step(
      baseline,
      const AttackCommand('ghoul-1'),
      SeededDiceRoller(142),
    );

    expect(activated.rejection, isNull);
    expect(pending.rejection, isNull);
    expect(pending.state.pendingDecision, isA<AwaitingRerollChoice>());
    expect(pending.state.players.first.nextAttackBonusHits, 0);

    final resolved = step(
      pending.state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      SeededDiceRoller(143),
    );
    final baselineResolved = step(
      baselinePending.state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      SeededDiceRoller(143),
    );
    expect(
      resolved.state.monsters.single.damage,
      baselineResolved.state.monsters.single.damage + 1,
    );
  });

  test('BUG056 a pending GTU-B1c4 hit cannot be stacked', () {
    final state = _state(
      backpack: const ['power-cell'],
      equippedRobot: 'gtu-b1c4',
      monsters: [
        MonsterInstance(
          instanceId: 'ghoul-1',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 20,
          attack: 1,
          movement: 0,
        ),
      ],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(144),
    );
    final reloaded = step(
      activated.state,
      const UseCardAbilityCommand('power-cell', targetCardId: 'gtu-b1c4'),
      SeededDiceRoller(145),
    );
    final activatedAgain = step(
      reloaded.state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(146),
    );

    expect(activated.rejection, isNull);
    expect(reloaded.rejection, isNull);
    expect(activatedAgain.rejection, isNotNull);
    expect(activatedAgain.state.players.first.nextAttackBonusHits, 1);
  });

  test('BUG076 GTU-B1c4 bonus is cleared when moving sectors', () {
    final state = _state(
      equippedRobot: 'gtu-b1c4',
      monsters: [
        MonsterInstance(
          instanceId: 'first-fight',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 3,
        ),
      ],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(149),
    );

    final moved = step(
      activated.state,
      const MoveCommand(HexCoord(1, 0)),
      SeededDiceRoller(150),
    );

    expect(activated.rejection, isNull);
    expect(moved.rejection, isNull);
    expect(moved.state.players.first.coord, const HexCoord(1, 0));
    expect(moved.state.players.first.nextAttackBonusHits, 0);
  });

  test('BUG076 GTU-B1c4 bonus is cleared when ending the turn', () {
    final state = _state(
      equippedRobot: 'gtu-b1c4',
      monsters: [
        MonsterInstance(
          instanceId: 'first-fight',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 3,
        ),
      ],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('gtu-b1c4'),
      SeededDiceRoller(151),
    );

    final endedTurn = step(
      activated.state,
      const EndTurnCommand(),
      SeededDiceRoller(152),
    );

    expect(activated.rejection, isNull);
    expect(endedTurn.rejection, isNull);
    expect(endedTurn.state.players.first.nextAttackBonusHits, 0);
  });

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

  test('BUG042 placing one tripwire consumes only one duplicate', () {
    final state = _state(backpack: const ['tripwire', 'tripwire']);
    final result = step(
      state,
      const UseCardAbilityCommand('tripwire'),
      SeededDiceRoller(120),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.backpack, ['tripwire']);
    expect(result.state.tripwires, hasLength(1));
  });

  test('BUG043 gas cylinder kill awards Restless gear to the killer', () {
    final state = _state(
      backpack: const ['gas-cylinder'],
      monsters: [
        RestlessMonster(
          instanceId: 'restless-gas',
          coord: const HexCoord(0, 0),
          attack: 1,
          defense: 0,
          carriedGear: const ['medkit'],
        ),
      ],
    );
    final result = step(
      state,
      const UseCardAbilityCommand(
        'gas-cylinder',
        targetMonsterInstanceId: 'restless-gas',
      ),
      SeededDiceRoller(121),
    );

    expect(result.rejection, isNull);
    expect(result.state.monsters, isEmpty);
    expect(result.state.players.first.backpack, contains('medkit'));
  });

  test('BUG043 tripwire kill awards Restless gear to its owner', () {
    final tripwireState = _state(backpack: const ['tripwire']);
    final placed = step(
      tripwireState,
      const UseCardAbilityCommand('tripwire'),
      SeededDiceRoller(122),
    );
    final tripwireResult = spawnMonster(
      placed.state,
      RestlessMonster(
        instanceId: 'restless-tripwire',
        coord: const HexCoord(0, 0),
        attack: 1,
        defense: 0,
        carriedGear: const ['medkit'],
      ),
    );

    expect(tripwireResult.monsters, isEmpty);
    expect(tripwireResult.players.first.backpack, contains('medkit'));
  });

  test('BUG060 gas cylinder awards a monster defeat reward', () {
    final state = _state(
      backpack: const ['gas-cylinder'],
      supplyDeckDrawPile: const ['medkit'],
      monsterDefinitions: {
        'ghoul': {'features': <String>[]},
      },
      monsters: [
        MonsterInstance(
          instanceId: 'reward-gas-ghoul',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 2,
          movement: 0,
          defeatRewardDeckId: 'supplies',
        ),
      ],
    );

    final result = step(
      state,
      const UseCardAbilityCommand(
        'gas-cylinder',
        targetMonsterInstanceId: 'reward-gas-ghoul',
      ),
      SeededDiceRoller(147),
    );

    expect(result.rejection, isNull);
    expect(result.state.monsters, isEmpty);
    expect(result.state.players.first.backpack, contains('medkit'));
    expect(result.state.decks['supplies']!.drawPile, isEmpty);
  });

  test('BUG060 tripwire awards a monster defeat reward', () {
    final state = _state(
      backpack: const ['tripwire'],
      supplyDeckDrawPile: const ['medkit'],
      monsterDefinitions: {
        'ghoul': {'features': <String>[]},
      },
    );
    final placed = step(
      state,
      const UseCardAbilityCommand('tripwire'),
      SeededDiceRoller(148),
    );
    final triggered = spawnMonster(
      placed.state,
      MonsterInstance(
        instanceId: 'reward-tripwire-ghoul',
        monsterId: 'ghoul',
        coord: const HexCoord(0, 0),
        damage: 0,
        health: 2,
        movement: 0,
        defeatRewardDeckId: 'supplies',
      ),
    );

    expect(placed.rejection, isNull);
    expect(triggered.monsters, isEmpty);
    expect(triggered.players.first.backpack, contains('medkit'));
    expect(triggered.decks['supplies']!.drawPile, isEmpty);
  });

  test('BUG061 PROT3-CT prevents pneumatic gun self-damage', () {
    final state = _state(
      equippedRobot: 'prot3-ct',
      equippedWeapon: 'pneumo-cannon',
      monsters: [
        MonsterInstance(
          instanceId: 'pneumo-target',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 10,
          movement: 0,
        ),
      ],
    );
    final activated = step(
      state,
      const UseCardAbilityCommand('prot3-ct'),
      SeededDiceRoller(149),
    );
    final attacked = step(
      activated.state,
      const AttackCommand('pneumo-target'),
      FixedDiceRoller([6]),
    );

    expect(activated.rejection, isNull);
    expect(attacked.rejection, isNull);
    expect(attacked.state.players.first.damage, 0);
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

  test('BUG057 Old Cloak increases active healing by one', () {
    final rationed = step(
      _state(
        backpack: const ['dry-rations'],
        equippedArmor: 'old-cloak',
        damage: 5,
      ),
      const UseCardAbilityCommand('dry-rations'),
      SeededDiceRoller(137),
    );
    final bagged = step(
      _state(
        backpack: const ['medic-bag'],
        equippedArmor: 'old-cloak',
        credits: 1,
        damage: 4,
      ),
      const UseCardAbilityCommand(
        'medic-bag',
        targetPlayerId: 'hero-1',
        amount: 1,
      ),
      SeededDiceRoller(138),
    );
    final robotic = step(
      _state(
        equippedRobot: 'h3-al',
        equippedArmor: 'old-cloak',
        damage: 4,
      ),
      const UseCardAbilityCommand('h3-al'),
      SeededDiceRoller(139),
    );

    expect(rationed.rejection, isNull);
    expect(rationed.state.players.first.damage, 0);
    expect(bagged.rejection, isNull);
    expect(bagged.state.players.first.damage, 2);
    expect(robotic.rejection, isNull);
    expect(robotic.state.players.first.damage, 0);
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
    'BUG064 air canister transfers for one remaining action',
    () {
      final state = _state(
        backpack: const ['air-canister'],
        actionsLeft: 1,
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
      expect(result.state.actionsLeft, 0);
      expect(result.state.players.first.backpack, isEmpty);
    },
  );

  test(
    'air canister spends one action and transfers between airlocks',
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
      expect(result.state.actionsLeft, 1);
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

  test('BUG045 door remote rejects a fogged corridor', () {
    final state = _state(
      backpack: const ['door-remote'],
      credits: 4,
      board: [
        _tile('start', const HexCoord(0, 0), HexTileType.start),
        _tile(
          'fogged-hall',
          const HexCoord(2, 0),
          HexTileType.corridor,
          opened: false,
        ),
      ],
    );

    final result = step(
      state,
      const UseCardAbilityCommand(
        'door-remote',
        targetCoord: HexCoord(2, 0),
      ),
      SeededDiceRoller(123),
    );

    expect(result.rejection, isA<InventoryCommandRejected>());
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
      backpack: const ['medkit'],
      actionsLeft: 0,
    );

    final result = step(
      state,
      const ExchangeCommand(partnerId: 'hero-2', giveCardId: 'medkit'),
      SeededDiceRoller(18),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.backpack, isEmpty);
    expect(result.state.players.last.backpack, ['medkit']);
    expect(
      result.state.players.first.exhaustedRobots,
      contains('c6-car-courier'),
    );
    expect(result.state.actionsLeft, 0);
  });

  test('BUG052 courier rejects remote credit transfers', () {
    final state = _state(equippedRobot: 'c6-car-courier', credits: 3);

    final result = step(
      state,
      const ExchangeCommand(partnerId: 'hero-2', giveCredits: 1),
      SeededDiceRoller(252),
    );

    expect(result.rejection, isA<ExchangeUnavailable>());
    expect(result.state.players.first.credits, 3);
    expect(result.state.players.last.credits, 0);
    expect(result.state.players.first.exhaustedRobots, isEmpty);
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

  test('BUG051 courier permits multiple remote items with smuggler mark', () {
    final state = _state(
      equippedRobot: 'c6-car-courier',
      backpack: const ['smuggler-mark', 'medkit', 'medkit'],
      actionsLeft: 0,
    );
    final result = step(
      state,
      const ExchangeCommand(
        partnerId: 'hero-2',
        giveCardIds: ['medkit', 'medkit'],
      ),
      SeededDiceRoller(232),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.first.backpack, ['smuggler-mark']);
    expect(result.state.players.last.backpack, ['medkit', 'medkit']);
    expect(
      result.state.players.first.exhaustedRobots,
      contains('c6-car-courier'),
    );
    expect(result.state.actionsLeft, 0);
  });

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
  String? equippedWeapon,
  String? equippedArmor,
  Iterable<CardId> exhaustedRobots = const [],
  int actionsLeft = 2,
  int roundNumber = 1,
  Iterable<CardId> supplyDeckDrawPile = const [],
  Iterable<CardId>? itemDeckDrawPile,
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
      equipped: EquippedGear(
        weapon: equippedWeapon,
        armor: equippedArmor,
        robot: equippedRobot,
      ),
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
    'supplies': DeckState(drawPile: supplyDeckDrawPile),
    'monsters': DeckState(drawPile: const []),
    'conditions': DeckState(drawPile: const []),
    if (itemDeckDrawPile != null)
      'items': DeckState(drawPile: itemDeckDrawPile),
  },
  conditionCards: {
    'infection': ConditionCard(id: 'infection'),
  },
  quests: QuestState(),
  cardDefinitions: {
    'gtu-b1c4': CardDefinition(
      id: 'gtu-b1c4',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'combat.addHit'],
    ),
    'prot2-ct': CardDefinition(
      id: 'prot2-ct',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'combat.addDefense'],
    ),
    'prot3-ct': CardDefinition(
      id: 'prot3-ct',
      type: ItemType.robot,
      slots: const [ItemSlot.robot],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['robot.exhaust', 'damage.ignoreAnyUntilRoundEnd'],
    ),
    'pneumo-cannon': CardDefinition(
      id: 'pneumo-cannon',
      type: ItemType.weapon,
      slots: const [ItemSlot.weapon],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'items',
      behaviorIds: const ['dice.successFace.3', 'dice.face6.damageBoth'],
    ),
    'old-cloak': CardDefinition(
      id: 'old-cloak',
      type: ItemType.armor,
      slots: const [ItemSlot.armor],
      cost: 0,
      staticEffects: CardStaticEffects(const {CardStat.defense: 1}),
      sourceDeck: 'specialItems',
      behaviorIds: const ['health.healingBonus'],
    ),
    'assault-rifle': CardDefinition(
      id: 'assault-rifle',
      type: ItemType.weapon,
      slots: const [ItemSlot.weapon],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'specialItems',
      behaviorIds: const ['dice.reroll.anyCountPerAttack'],
    ),
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
    'gas-cylinder': CardDefinition(
      id: 'gas-cylinder',
      type: ItemType.supply,
      slots: const [],
      cost: 6,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['action.spend', 'monster.killNonBoss'],
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
    'dry-rations': CardDefinition(
      id: 'dry-rations',
      type: ItemType.supply,
      slots: const [],
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      sourceDeck: 'supplies',
      behaviorIds: const ['card.discardCost', 'health.restore'],
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

HexTile _tile(
  String id,
  HexCoord coord,
  HexTileType type, {
  bool opened = true,
}) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: opened,
  exits: HexEdge.values,
  hasTerminal: false,
  ventColor: VentColor.none,
);
