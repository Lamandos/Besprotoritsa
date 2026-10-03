import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  final cards = <CardId, CardDefinition>{
    'supply-a': _card('supply-a', cost: 2),
    'supply-b': _card('supply-b', cost: 1),
    'supply-c': _card('supply-c', cost: 1),
    'stored-item': _card('stored-item'),
    'ada-item': _card('ada-item'),
    'boris-item': _card('boris-item'),
    'knife': _gear('knife', ItemType.weapon, ItemSlot.weapon),
    'pistol': _gear('pistol', ItemType.weapon, ItemSlot.weapon),
    'load-bearing-vest': _gear(
      'load-bearing-vest',
      ItemType.armor,
      ItemSlot.armor,
      behaviorIds: const ['equipment.extraWeaponSlot'],
    ),
  };

  test(
    'terminal reveals three supplies, charges one purchase, and reshuffles',
    () {
      final state = _state(
        cards: cards,
        board: [_terminalTile()],
        players: [_player('ada', credits: 3)],
        decks: {
          'supplies': DeckState(
            drawPile: const ['supply-a', 'supply-b', 'supply-c'],
          ),
        },
      );

      final opened = step(
        state,
        const UseTerminalCommand(),
        FixedDiceRoller([]),
      );
      expect(opened.rejection, isNull);
      expect(opened.state.actionsLeft, 1);
      final pending = opened.state.pendingDecision! as AwaitingTerminalPick;
      expect(pending.offeredCards, const ['supply-a', 'supply-b', 'supply-c']);
      expect(opened.state.decks['supplies']!.drawPile, isEmpty);

      final purchased = step(
        opened.state,
        const ResolvePendingDecisionCommand(TerminalPickChoice('supply-a')),
        FixedDiceRoller([]),
      );
      expect(purchased.rejection, isNull);
      expect(purchased.state.pendingDecision, isNull);
      expect(purchased.state.players.single.credits, 1);
      expect(purchased.state.players.single.backpack, ['supply-a']);
      expect(
        purchased.state.decks['supplies']!.drawPile,
        unorderedEquals([
          'supply-b',
          'supply-c',
        ]),
      );
    },
  );

  test('terminal is unavailable with a monster in its sector', () {
    final state = _state(
      cards: cards,
      board: [_terminalTile()],
      players: [_player('ada')],
      monsters: [_monster(const HexCoord(0, 0))],
      decks: {
        'supplies': DeckState(drawPile: const ['supply-a']),
      },
    );

    expect(
      validate(state, const UseTerminalCommand()),
      isA<TerminalUnavailable>(),
    );
  });

  test(
    'the start-sector chest transfers cards for one action and rejects credits',
    () {
      final state = _state(
        cards: cards,
        board: [_startTile()],
        players: [
          _player('ada', backpack: const ['stored-item'], credits: 4),
        ],
      );

      final deposited = step(
        state,
        const DepositIntoChestCommand('stored-item'),
        FixedDiceRoller([]),
      );
      expect(deposited.rejection, isNull);
      expect(deposited.state.actionsLeft, state.actionsLeft - 1);
      expect(deposited.state.chestCards, ['stored-item']);
      expect(deposited.state.players.single.backpack, isEmpty);

      final withdrawn = step(
        deposited.state,
        const WithdrawFromChestCommand('stored-item'),
        FixedDiceRoller([]),
      );
      expect(withdrawn.rejection, isNull);
      expect(withdrawn.state.actionsLeft, state.actionsLeft - 2);
      expect(withdrawn.state.chestCards, isEmpty);
      expect(withdrawn.state.players.single.backpack, ['stored-item']);
      final repeated = step(
        withdrawn.state,
        const DepositIntoChestCommand('stored-item'),
        FixedDiceRoller([]),
      );
      expect(repeated.rejection, isA<NotEnoughActions>());
      expect(repeated.state, same(withdrawn.state));
      expect(
        step(
          withdrawn.state,
          const DepositCreditsIntoChestCommand(1),
          FixedDiceRoller([]),
        ).rejection,
        isA<CreditsCannotBeStoredInChest>(),
      );
    },
  );

  test('the start-sector chest rejects transfers without an action', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        _player('ada', backpack: const ['stored-item'], actionPoints: 0),
      ],
      actionsLeft: 0,
      chestCards: const ['withdrawn-item'],
    );

    final deposit = step(
      state,
      const DepositIntoChestCommand('stored-item'),
      FixedDiceRoller([]),
    );
    final withdraw = step(
      state,
      const WithdrawFromChestCommand('withdrawn-item'),
      FixedDiceRoller([]),
    );

    expect(deposit.rejection, isA<NotEnoughActions>());
    expect(withdraw.rejection, isA<NotEnoughActions>());
    expect(deposit.state, same(state));
    expect(withdraw.state, same(state));
  });

  test('a chest batch deposits and withdraws any number for one action', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        _player('ada', backpack: const ['stored-item', 'ada-item']),
      ],
      chestCards: const ['boris-item'],
    );

    final result = step(
      state,
      TransferChestCardsCommand(
        depositCardIds: const ['stored-item', 'ada-item'],
        withdrawCardIds: const ['boris-item'],
      ),
      FixedDiceRoller([]),
    );

    expect(result.rejection, isNull);
    expect(result.state.actionsLeft, state.actionsLeft - 1);
    expect(result.state.players.single.backpack, ['boris-item']);
    expect(result.state.chestCards, ['stored-item', 'ada-item']);
  });

  test('a rejected chest batch leaves cards and action points unchanged', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        _player(
          'ada',
          backpack: const ['stored-item', 'ada-item', 'boris-item'],
        ),
      ],
      chestCards: const ['supply-a'],
    );

    final fullBackpack = step(
      state,
      TransferChestCardsCommand(withdrawCardIds: const ['supply-a']),
      FixedDiceRoller([]),
    );
    final emptyTransfer = step(
      state,
      TransferChestCardsCommand(),
      FixedDiceRoller([]),
    );

    expect(fullBackpack.rejection, isA<InventoryCommandRejected>());
    expect(fullBackpack.state, same(state));
    expect(emptyTransfer.rejection, isA<InvalidCommandArguments>());
    expect(emptyTransfer.state, same(state));
  });

  test('transferring slot-granting armor requires removing excess weapons', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        PlayerState(
          id: 'ada',
          characterId: 'ada-character',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 8,
          credits: 0,
          backpack: const [],
          equipped: const EquippedGear(
            weapon: 'knife',
            secondWeapon: 'pistol',
            armor: 'load-bearing-vest',
          ),
          carriedMods: const [],
          implanted: const [],
          conditions: const [],
          alive: true,
          stats: const PlayerStats(strength: 2, science: 2, repair: 2),
        ),
      ],
    );

    final result = step(
      state,
      TransferChestCardsCommand(
        depositCards: [
          const InventoryCardSelection(
            cardId: 'load-bearing-vest',
            area: InventoryCardArea.armor,
          ),
        ],
      ),
      FixedDiceRoller([]),
    );

    expect(result.rejection, isA<InventoryCommandRejected>());
    expect(result.state, same(state));
  });

  test('a chest batch can remove the vest and excess weapon together', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        PlayerState(
          id: 'ada',
          characterId: 'ada-character',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 8,
          credits: 0,
          backpack: const [],
          equipped: const EquippedGear(
            weapon: 'knife',
            secondWeapon: 'pistol',
            armor: 'load-bearing-vest',
          ),
          carriedMods: const [],
          implanted: const [],
          conditions: const [],
          alive: true,
          stats: const PlayerStats(strength: 2, science: 2, repair: 2),
        ),
      ],
    );

    final result = step(
      state,
      TransferChestCardsCommand(
        depositCards: [
          const InventoryCardSelection(
            cardId: 'load-bearing-vest',
            area: InventoryCardArea.armor,
          ),
          const InventoryCardSelection(
            cardId: 'pistol',
            area: InventoryCardArea.weapon,
          ),
        ],
      ),
      FixedDiceRoller([]),
    );

    expect(result.rejection, isNull);
    expect(result.state.players.single.equipped.weapons, ['knife']);
    expect(result.state.chestCards, ['load-bearing-vest', 'pistol']);
  });

  test('co-located players exchange cards and credits for one action', () {
    final state = _state(
      cards: cards,
      board: [_startTile()],
      players: [
        _player('ada', backpack: const ['ada-item'], credits: 3),
        _player('boris', backpack: const ['boris-item'], credits: 1),
      ],
    );

    final exchanged = step(
      state,
      const ExchangeCommand(
        partnerId: 'boris',
        giveCardId: 'ada-item',
        receiveCardId: 'boris-item',
        giveCredits: 2,
        receiveCredits: 1,
      ),
      FixedDiceRoller([]),
    );
    expect(exchanged.rejection, isNull);
    expect(exchanged.state.actionsLeft, 1);
    expect(exchanged.state.players[0].backpack, ['boris-item']);
    expect(exchanged.state.players[0].credits, 2);
    expect(exchanged.state.players[1].backpack, ['ada-item']);
    expect(exchanged.state.players[1].credits, 2);
  });

  test('decks recycle discards and can find a particular card', () {
    final recycled = DeckRules.draw(
      DeckState(drawPile: const [], discardPile: const ['one', 'two']),
      seed: 7,
    );
    expect(recycled.cards, hasLength(1));
    expect(recycled.deck.discardPile, isEmpty);
    expect(
      [...recycled.cards, ...recycled.deck.drawPile],
      unorderedEquals([
        'one',
        'two',
      ]),
    );

    final searched = DeckRules.drawSpecific(
      DeckState(drawPile: const ['one', 'target', 'two']),
      'target',
      seed: 9,
    );
    expect(searched.cards, ['target']);
    expect(searched.deck.drawPile, unorderedEquals(['one', 'two']));

    final searchedDiscard = DeckRules.drawSpecific(
      DeckState(
        drawPile: const ['top'],
        discardPile: const ['target', 'other'],
      ),
      'target',
      seed: 10,
    );
    expect(searchedDiscard.cards, ['target']);
    expect(searchedDiscard.deck.drawPile, ['top']);
    expect(searchedDiscard.deck.discardPile, ['other']);
  });
}

GameState _state({
  required Map<CardId, CardDefinition> cards,
  required Iterable<HexTile> board,
  required Iterable<PlayerState> players,
  Iterable<MonsterInstance> monsters = const [],
  Map<DeckId, DeckState> decks = const {},
  int actionsLeft = 2,
  Iterable<CardId> chestCards = const [],
}) => GameState(
  seed: 13,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: actionsLeft,
  board: board,
  players: players,
  monsters: monsters,
  decks: decks,
  chestCards: chestCards,
  quests: QuestState(),
  cardDefinitions: cards,
);

HexTile _terminalTile() => HexTile(
  id: 'terminal',
  coord: const HexCoord(0, 0),
  type: HexTileType.compartment,
  opened: true,
  exits: const {},
  hasTerminal: true,
  ventColor: VentColor.none,
);

HexTile _startTile() => HexTile(
  id: 'anabiosis',
  coord: const HexCoord(0, 0),
  type: HexTileType.start,
  opened: true,
  exits: const {},
  hasTerminal: false,
  ventColor: VentColor.none,
);

PlayerState _player(
  String id, {
  Iterable<CardId> backpack = const [],
  int credits = 0,
  int actionPoints = 2,
}) => PlayerState(
  id: id,
  characterId: '$id-character',
  coord: const HexCoord(0, 0),
  damage: 0,
  credits: credits,
  backpack: backpack,
  equipped: const EquippedGear(),
  carriedMods: const [],
  implanted: const [],
  conditions: const [],
  alive: true,
  actionPoints: actionPoints,
);

MonsterInstance _monster(HexCoord coord) => MonsterInstance(
  instanceId: 'monster',
  monsterId: 'monster',
  coord: coord,
  damage: 0,
  attack: 1,
);

CardDefinition _card(String id, {int cost = 0}) => CardDefinition(
  id: id,
  type: ItemType.supply,
  slots: const [ItemSlot.modification],
  cost: cost,
  staticEffects: CardStaticEffects(const {}),
);

CardDefinition _gear(
  String id,
  ItemType type,
  ItemSlot slot, {
  List<String> behaviorIds = const [],
}) => CardDefinition(
  id: id,
  type: type,
  slots: [slot],
  cost: 0,
  staticEffects: CardStaticEffects(const {}),
  behaviorIds: behaviorIds,
);
