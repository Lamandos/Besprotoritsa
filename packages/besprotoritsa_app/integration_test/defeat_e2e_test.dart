import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('both heroes die in combat, become Restless, and open defeat', (
    tester,
  ) async {
    var state = _initialState();

    state = spawnMonster(state, _monster('ghoul-ada', const HexCoord(0, 0)));
    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([1]),
    ).state;
    expect(state.players.first.alive, isFalse);
    expect(state.pendingDecision, isA<AwaitingHeroReplacement>());
    expect(
      state.monsters.whereType<RestlessMonster>().map(
        (monster) => monster.coord,
      ),
      contains(const HexCoord(0, 0)),
    );

    state = step(
      state,
      const ResolvePendingDecisionCommand(
        SelectReplacementHeroChoice('scientist'),
      ),
      FixedDiceRoller([]),
    ).state;
    expect(state.reserveHeroes, isEmpty);

    state = spawnMonster(state, _monster('ghoul-boris', const HexCoord(0, 1)));
    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([1]),
    ).state;

    expect(state.players.every((hero) => !hero.alive), isTrue);
    expect(state.reserveHeroes, isEmpty);
    expect(state.isComplete, isTrue);
    expect(state.pendingDecision, isNull);
    expect(
      state.monsters.whereType<RestlessMonster>().map(
        (monster) => monster.coord,
      ),
      containsAll(const [HexCoord(0, 0), HexCoord(0, 1)]),
    );

    final container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(initialState: state),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );

    expect(find.byKey(const ValueKey<String>('defeat-screen')), findsOneWidget);
    expect(find.text('Поражение'), findsOneWidget);
  });
}

GameState _initialState() => GameState(
  seed: 0xDEF347,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile('anabiosis', const HexCoord(0, 0), const {HexEdge.south}),
    _tile('sector', const HexCoord(0, 1), const {HexEdge.north}),
  ],
  players: [
    _hero('ada', const HexCoord(0, 0)),
    _hero('boris', const HexCoord(0, 1)),
  ],
  monsters: const [],
  reserveHeroes: [
    ReserveHero(
      characterId: 'scientist',
      health: 3,
      stats: const PlayerStats(science: 3),
    ),
  ],
  decks: const {},
  quests: QuestState(),
);

PlayerState _hero(String id, HexCoord coord) => PlayerState(
  id: id,
  characterId: '$id-character',
  coord: coord,
  damage: 2,
  credits: 0,
  backpack: const [],
  equipped: const EquippedGear(),
  carriedMods: const [],
  implanted: const [],
  conditions: const [],
  alive: true,
  stats: const PlayerStats(agility: 1),
);

MonsterInstance _monster(String id, HexCoord coord) => MonsterInstance(
  instanceId: id,
  monsterId: 'ghoul',
  coord: coord,
  damage: 0,
  health: 2,
  attack: 1,
  movement: 0,
);

HexTile _tile(String id, HexCoord coord, Set<HexEdge> exits) => HexTile(
  id: id,
  coord: coord,
  type: id == 'anabiosis' ? HexTileType.start : HexTileType.corridor,
  opened: true,
  exits: exits,
  hasTerminal: false,
  ventColor: VentColor.none,
);
