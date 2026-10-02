import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  final cards = <CardId, CardDefinition>{
    'knife': _card(
      'knife',
      ItemType.weapon,
      stats: const {'strength': 1},
      sourceDeck: 'items',
    ),
    'starter-pistol': _card(
      'starter-pistol',
      ItemType.weapon,
      sourceDeck: 'starterItems',
    ),
    'pistol': _card('pistol', ItemType.weapon, stats: const {'strength': 2}),
    'lab-coat': _card(
      'lab-coat',
      ItemType.clothing,
      stats: const {'science': 1},
    ),
    'load-bearing-vest': _card(
      'load-bearing-vest',
      ItemType.armor,
      behaviorIds: const ['equipment.extraWeaponSlot'],
    ),
    'backpack': _card(
      'backpack',
      ItemType.armor,
      behaviorIds: const ['equipment.extraBackpackCapacity'],
    ),
    'implant-r': _card(
      'implant-r',
      ItemType.modification,
      stats: const {'repair': 1},
    ),
    'implant-l': _card(
      'implant-l',
      ItemType.modification,
      stats: const {'agility': 1},
    ),
    'implant-v': _card(
      'implant-v',
      ItemType.modification,
      stats: const {'endurance': 1},
    ),
    'supply-1': _card('supply-1', ItemType.supply),
    'supply-2': _card('supply-2', ItemType.supply),
    'supply-3': _card('supply-3', ItemType.supply),
    'supply-4': _card('supply-4', ItemType.supply),
    'supply-5': _card('supply-5', ItemType.supply),
    'supply-6': _card('supply-6', ItemType.supply),
  };

  test('recalculates characteristics from changed equipment and implants', () {
    var player = _player(backpack: const ['knife', 'pistol', 'lab-coat']);
    player = InventoryRules.equip(player, 'knife', cards);
    player = InventoryRules.equip(player, 'lab-coat', cards);
    player = InventoryRules.receive(player, 'implant-r', cards);
    player = InventoryRules.implant(player, 'implant-r', cards);

    expect(
      InventoryRules.effectiveStats(player, cards),
      isA<EffectivePlayerStats>()
          .having((stats) => stats.strength, 'strength', 3)
          .having((stats) => stats.science, 'science', 3)
          .having((stats) => stats.repair, 'repair', 3),
    );

    player = InventoryRules.equip(player, 'pistol', cards);
    final afterWeaponSwap = InventoryRules.effectiveStats(player, cards);
    expect(afterWeaponSwap.strength, 4);
    expect(player.equipped.weapon, 'pistol');
    expect(player.backpack, contains('knife'));
  });

  test('allows exactly two weapons only with a load-bearing vest', () {
    var player = _player(
      backpack: const ['load-bearing-vest', 'knife', 'pistol'],
    );
    player = InventoryRules.equip(player, 'load-bearing-vest', cards);
    player = InventoryRules.equip(player, 'knife', cards);
    player = InventoryRules.equip(player, 'pistol', cards, weaponSlot: 1);

    expect(player.equipped.weapons, ['knife', 'pistol']);
    expect(
      () => InventoryRules.equip(player, 'knife', cards, weaponSlot: 2),
      throwsA(isA<InventoryRuleViolation>()),
    );
  });

  test(
    'enforces backpack limits while carried modifications remain unlimited',
    () {
      var player = _player(
        backpack: const ['supply-1', 'supply-2', 'supply-3', 'backpack'],
      );
      // A fourth normal card cannot be received with the base capacity of 3.
      final base = _player(
        backpack: const ['supply-1', 'supply-2', 'supply-3'],
      );
      expect(
        () => InventoryRules.receive(base, 'supply-4', cards),
        throwsA(isA<BackpackCapacityExceeded>()),
      );

      player = InventoryRules.equip(player, 'backpack', cards);
      player = InventoryRules.receive(player, 'supply-4', cards);
      player = InventoryRules.receive(player, 'supply-5', cards);
      expect(player.backpack.length, 5);
      expect(
        () => InventoryRules.receive(player, 'supply-6', cards),
        throwsA(isA<BackpackCapacityExceeded>()),
      );

      for (var index = 0; index != 8; index++) {
        player = InventoryRules.receive(player, 'implant-l', cards);
      }
      expect(player.carriedMods, hasLength(8));
      expect(player.backpack, hasLength(5));
    },
  );

  test('limits implants to two and makes implanted cards non-transferable', () {
    var player = _player();
    for (final id in ['implant-r', 'implant-l', 'implant-v']) {
      player = InventoryRules.receive(player, id, cards);
    }
    player = InventoryRules.implant(player, 'implant-r', cards);
    player = InventoryRules.implant(player, 'implant-l', cards);

    expect(
      () => InventoryRules.implant(player, 'implant-v', cards),
      throwsA(isA<InventoryRuleViolation>()),
    );
    expect(
      () => InventoryRules.discard(player, 'implant-r', cards),
      throwsA(isA<InventoryRuleViolation>()),
    );
    expect(
      () => InventoryRules.transfer(player, _player(), 'implant-l', cards),
      throwsA(isA<InventoryRuleViolation>()),
    );
  });

  test('allows implantation on receipt or before the first action only', () {
    final state = _state(
      cards,
      player: _player(carriedMods: const ['implant-r']),
      actionsTakenThisTurn: 1,
    );
    final tooLate = step(
      state,
      const ImplantModificationCommand('implant-r'),
      FixedDiceRoller([]),
    );
    expect(tooLate.rejection, isA<ImplantWindowClosed>());

    final received = step(
      state,
      const ReceiveCardCommand('implant-l', implantImmediately: true),
      FixedDiceRoller([]),
    );
    expect(received.rejection, isNull);
    expect(received.state.players.single.implanted, ['implant-l']);
  });

  test('can equip an item on receipt when the backpack is full', () {
    final state = _state(
      cards,
      player: _player(backpack: const ['supply-1', 'supply-2', 'supply-3']),
      actionsTakenThisTurn: 0,
    );

    final received = step(
      state,
      const ReceiveCardCommand('knife', equipImmediately: true),
      FixedDiceRoller([]),
    );

    expect(received.rejection, isNull);
    expect(received.state.players.single.equipped.weapon, 'knife');
    expect(received.state.players.single.backpack, [
      'supply-1',
      'supply-2',
      'supply-3',
    ]);
  });

  test(
    'on receipt uses a free extra weapon slot before replacing a weapon',
    () {
      final state = _state(
        cards,
        player: PlayerState(
          id: 'ada',
          characterId: 'scientist',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 8,
          credits: 0,
          backpack: const ['supply-1', 'supply-2', 'supply-3'],
          equipped: const EquippedGear(
            weapon: 'knife',
            armor: 'load-bearing-vest',
          ),
          carriedMods: const [],
          implanted: const [],
          conditions: const [],
          alive: true,
          stats: const PlayerStats(strength: 2, science: 2, repair: 2),
        ),
        actionsTakenThisTurn: 0,
      );

      final received = step(
        state,
        const ReceiveCardCommand('pistol', equipImmediately: true),
        FixedDiceRoller([]),
      );

      expect(received.rejection, isNull);
      expect(received.state.players.single.equipped.weapons, [
        'knife',
        'pistol',
      ]);
      expect(received.state.players.single.backpack, hasLength(3));
    },
  );

  test('discards equipped gear to its deck without spending an action', () {
    final state = GameState(
      seed: 1,
      round: 1,
      phase: GamePhase.playersTurn,
      activePlayerId: 'ada',
      actionsLeft: 1,
      actionsTakenThisTurn: 1,
      board: const [],
      players: [
        PlayerState(
          id: 'ada',
          characterId: 'scientist',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 8,
          credits: 0,
          backpack: const [],
          equipped: const EquippedGear(weapon: 'knife'),
          carriedMods: const [],
          implanted: const [],
          conditions: const [],
          alive: true,
          stats: const PlayerStats(strength: 2, science: 2, repair: 2),
        ),
      ],
      monsters: const [],
      decks: {
        'items': DeckState(drawPile: const ['pistol']),
      },
      quests: QuestState(),
      cardDefinitions: cards,
    );

    final discarded = step(
      state,
      const DiscardCardCommand('knife'),
      FixedDiceRoller([]),
    );

    expect(discarded.rejection, isNull);
    expect(discarded.state.players.single.equipped.weapon, isNull);
    expect(discarded.state.decks['items']!.discardPile, ['knife']);
    expect(discarded.state.actionsLeft, 1);
    expect(discarded.state.actionsTakenThisTurn, 1);
  });

  test('discards starter gear without a discard deck', () {
    final state = GameState(
      seed: 1,
      round: 1,
      phase: GamePhase.playersTurn,
      activePlayerId: 'ada',
      actionsLeft: 1,
      actionsTakenThisTurn: 1,
      board: const [],
      players: [
        PlayerState(
          id: 'ada',
          characterId: 'guard',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 11,
          credits: 0,
          backpack: const ['starter-pistol'],
          equipped: const EquippedGear(),
          carriedMods: const [],
          implanted: const [],
          conditions: const [],
          alive: true,
          stats: const PlayerStats(strength: 3, science: 1, repair: 1),
        ),
      ],
      monsters: const [],
      decks: const {},
      quests: QuestState(),
      cardDefinitions: cards,
    );

    final discarded = step(
      state,
      const DiscardCardCommand('starter-pistol'),
      FixedDiceRoller([]),
    );

    expect(discarded.rejection, isNull);
    expect(discarded.state.players.single.backpack, isEmpty);
    expect(discarded.state.decks, isEmpty);
    expect(discarded.state.actionsLeft, 1);
  });
}

CardDefinition _card(
  String id,
  ItemType type, {
  Map<String, int> stats = const {},
  List<String> behaviorIds = const [],
  String? sourceDeck,
}) => CardDefinition(
  id: id,
  type: type,
  slots: [
    switch (type) {
      ItemType.weapon => ItemSlot.weapon,
      ItemType.armor => ItemSlot.armor,
      ItemType.clothing => ItemSlot.clothing,
      ItemType.robot => ItemSlot.robot,
      ItemType.modification => ItemSlot.modification,
      ItemType.supply || ItemType.specialItem => ItemSlot.modification,
    },
  ],
  cost: 0,
  staticEffects: CardStaticEffects.fromJson({'stats': stats}),
  sourceDeck: sourceDeck,
  behaviorIds: behaviorIds,
);

PlayerState _player({
  Iterable<CardId> backpack = const [],
  Iterable<CardId> carriedMods = const [],
}) => PlayerState(
  id: 'ada',
  characterId: 'scientist',
  coord: const HexCoord(0, 0),
  damage: 0,
  health: 8,
  credits: 0,
  backpack: backpack,
  equipped: const EquippedGear(),
  carriedMods: carriedMods,
  implanted: const [],
  conditions: const [],
  alive: true,
  stats: const PlayerStats(strength: 2, science: 2, repair: 2),
);

GameState _state(
  Map<CardId, CardDefinition> cards, {
  required PlayerState player,
  required int actionsTakenThisTurn,
}) => GameState(
  seed: 1,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: player.id,
  actionsLeft: 2,
  actionsTakenThisTurn: actionsTakenThisTurn,
  board: const [],
  players: [player],
  monsters: const [],
  decks: const {},
  quests: QuestState(),
  cardDefinitions: cards,
);
