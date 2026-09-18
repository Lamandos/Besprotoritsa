import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('projectFor hides fog, deck order, and another player private data', () {
    final state = GameState(
      seed: 42,
      round: 1,
      phase: GamePhase.players,
      activePlayerId: 'ada',
      actionsLeft: 2,
      board: [
        HexTile(
          id: 'start',
          coord: const HexCoord(0, 0),
          type: HexTileType.start,
          opened: true,
          exits: const {HexEdge.southEast},
          hasTerminal: false,
          ventColor: VentColor.none,
        ),
        HexTile(
          id: 'unknown-corridor',
          coord: const HexCoord(1, 0),
          type: HexTileType.corridor,
          opened: false,
          exits: const {HexEdge.northWest},
          locationId: 'secret-location',
          hasTerminal: true,
          ventColor: VentColor.red,
        ),
      ],
      players: [
        _player('ada', backpack: const ['pistol']),
        _player(
          'boris',
          backpack: const ['secret-card'],
          conditions: const ['wound'],
        ),
      ],
      monsters: const [],
      decks: {
        'events': DeckState(drawPile: const ['event-2', 'event-1']),
      },
      quests: QuestState(
        storyQuestIds: const ['chapter-1'],
        personalTasksByPlayer: const {
          'ada': ['ada-task'],
          'boris': ['boris-secret-task'],
        },
      ),
    );

    final view = projectFor(state, 'ada');
    final fog = view.board[1];
    final other = view.players.singleWhere((player) => player.id == 'boris');

    expect(fog.isFogged, isTrue);
    expect(fog.tile, isNull);
    expect(view.decks['events']!.cardsRemaining, 2);
    expect(view.decks['events'], isNot(isA<DeckState>()));
    expect(other.backpack, isEmpty);
    expect(other.conditions, isEmpty);
    expect(other.hiddenCardCount, 2);
    expect(view.quests.personalTasks, ['ada-task']);
    expect(view.quests.hiddenPersonalTaskCounts, {'boris': 1});
  });

  test('state collections cannot be changed through their public API', () {
    final player = _player('ada');

    expect(() => player.backpack.add('extra'), throwsUnsupportedError);
    expect(() => player.implanted.add('mod'), throwsUnsupportedError);
  });
}

PlayerState _player(
  String id, {
  Iterable<CardId> backpack = const [],
  Iterable<CardId> conditions = const [],
}) => PlayerState(
  id: id,
  characterId: '$id-character',
  coord: const HexCoord(0, 0),
  damage: 0,
  credits: 0,
  backpack: backpack,
  equipped: const EquippedGear(),
  carriedMods: const [],
  implanted: const [],
  conditions: conditions,
  alive: true,
);
