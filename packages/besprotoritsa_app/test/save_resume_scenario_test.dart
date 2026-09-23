import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/storage/save_system.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save and resume preserves a pending reroll byte-for-byte', (
    tester,
  ) async {
    final storage = InMemoryGameStorage();
    final saves = SaveSystem(storage: storage);
    final codec = GameStateJsonCodec();
    final firstSession = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(
            initialState: _initialState(),
            dice: FixedDiceRoller([1]),
          ),
        ),
      ],
    );
    addTearDown(firstSession.dispose);

    final firstController = firstSession.read(gameControllerProvider.notifier);
    expect(firstController.dispatch(const EndTurnCommand()), isTrue);
    expect(firstController.dispatch(const EndTurnCommand()), isTrue);
    expect(firstSession.read(gameControllerProvider).round, 3);

    expect(
      firstController.dispatch(const AttackCommand('training-ghoul')),
      isTrue,
    );
    final pending = firstSession.read(gameControllerProvider);
    expect(pending.pendingDecision, isA<AwaitingRerollChoice>());
    final savedDocument = codec.encode(pending);
    await saves.saveManual(SaveSlots.manual.first, pending, name: 'Раунд 3');

    // Simulate process loss: discard every in-memory provider and state object.
    firstSession.dispose();
    final restored = await saves.load(SaveSlots.manual.first);
    expect(restored, isNotNull);
    expect(codec.encode(restored!), savedDocument);
    expect(await saves.loadName(SaveSlots.manual.first), 'Раунд 3');

    final resumedSession = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(initialState: restored),
        ),
      ],
    );
    addTearDown(resumedSession.dispose);
    expect(
      codec.encode(resumedSession.read(gameControllerProvider)),
      savedDocument,
    );

    final resumedController = resumedSession.read(
      gameControllerProvider.notifier,
    );
    expect(
      resumedController.dispatch(
        const ResolvePendingDecisionCommand(KeepRollChoice()),
      ),
      isTrue,
    );
    expect(resumedController.dispatch(const EndTurnCommand()), isTrue);
    expect(resumedSession.read(gameControllerProvider).pendingDecision, isNull);
    expect(resumedSession.read(gameControllerProvider).round, 4);
  });
}

GameState _initialState() => GameState(
  seed: 0x5A6E,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    HexTile(
      id: 'anabiosis',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: HexEdge.values,
      hasTerminal: false,
      ventColor: VentColor.none,
    ),
  ],
  players: [
    PlayerState(
      id: 'ada',
      characterId: 'guard',
      coord: const HexCoord(0, 0),
      damage: 0,
      credits: 3,
      backpack: const [],
      equipped: const EquippedGear(weapon: 'circular-saw'),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
      stats: const PlayerStats(strength: 1),
    ),
  ],
  monsters: [
    MonsterInstance(
      instanceId: 'training-ghoul',
      monsterId: 'ghoul',
      coord: const HexCoord(0, 0),
      damage: 0,
      health: 9,
      movement: 0,
    ),
  ],
  decks: const {},
  quests: QuestState(),
  cardDefinitions: {
    'circular-saw': CardDefinition(
      id: 'circular-saw',
      type: ItemType.weapon,
      slots: const {ItemSlot.weapon},
      cost: 0,
      staticEffects: CardStaticEffects(const {}),
      behaviorIds: const ['dice.reroll.twoPerAttack'],
    ),
  },
);
