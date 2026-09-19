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
    'the start-sector chest transfers cards for free and rejects credits',
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
      expect(deposited.state.actionsLeft, state.actionsLeft);
      expect(deposited.state.chestCards, ['stored-item']);
      expect(deposited.state.players.single.backpack, isEmpty);

      final withdrawn = step(
        deposited.state,
        const WithdrawFromChestCommand('stored-item'),
        FixedDiceRoller([]),
      );
      expect(withdrawn.rejection, isNull);
      expect(withdrawn.state.chestCards, isEmpty);
      expect(withdrawn.state.players.single.backpack, ['stored-item']);
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
  });
}

GameState _state({
  required Map<CardId, CardDefinition> cards,
  required Iterable<HexTile> board,
  required Iterable<PlayerState> players,
  Iterable<MonsterInstance> monsters = const [],
  Map<DeckId, DeckState> decks = const {},
}) => GameState(
  seed: 13,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: board,
  players: players,
  monsters: monsters,
  decks: decks,
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
