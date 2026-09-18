import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('validate', () {
    test('rejects action commands when no actions remain', () {
      final state = _state(actionsLeft: 0);

      expect(
        validate(state, const MoveCommand(HexCoord(0, 1))),
        isA<NotEnoughActions>(),
      );
    });

    test(
      'distinguishes missing targets, distant targets, and incompatible ports',
      () {
        final state = _state();
        final mismatchedPorts = _state(
          board: [
            _tile('start', const HexCoord(0, 0), {HexEdge.south}),
            _tile('next', const HexCoord(0, 1), {}),
          ],
        );

        expect(
          validate(state, const MoveCommand(HexCoord(4, 4))),
          isA<InvalidTargetCoord>(),
        );
        expect(
          validate(
            _state(
              board: [
                _tile('start', const HexCoord(0, 0), {HexEdge.south}),
                _tile('far', const HexCoord(0, 2), {HexEdge.north}),
              ],
            ),
            const MoveCommand(HexCoord(0, 2)),
          ),
          isA<TargetOutOfRange>(),
        );
        expect(
          validate(mismatchedPorts, const MoveCommand(HexCoord(0, 1))),
          isA<PortMismatch>(),
        );
      },
    );

    test('blocks basic actions while a decision is pending', () {
      final state = _state(
        pendingDecision: AwaitingRerollChoice(
          dice: const [3],
          availableRerolls: 1,
          window: const DecisionWindow(remainingTicks: 1),
        ),
      );

      expect(
        validate(state, const MoveCommand(HexCoord(0, 1))),
        isA<ActionBlockedByPendingDecision>(),
      );
      expect(
        validate(state, const AttackCommand('monster')),
        isA<ActionBlockedByPendingDecision>(),
      );
      expect(
        validate(state, const EndTurnCommand()),
        isA<ActionBlockedByPendingDecision>(),
      );
      expect(
        validate(state, const ResolvePendingDecisionCommand(KeepRollChoice())),
        isNull,
      );
    });
  });

  group('step', () {
    test('does not modify state for a rejected command', () {
      final state = _state(actionsLeft: 0);

      final result = step(
        state,
        const MoveCommand(HexCoord(0, 1)),
        FixedDiceRoller([]),
      );

      expect(result.rejection, isA<NotEnoughActions>());
      expect(identical(result.state, state), isTrue);
    });

    test('moves through matching ports and consumes one action', () {
      final result = step(
        _state(),
        const MoveCommand(HexCoord(0, 1)),
        FixedDiceRoller([]),
      );

      expect(result.isAccepted, isTrue);
      expect(result.state.actionsLeft, 1);
      expect(result.state.players.single.coord, const HexCoord(0, 1));
      expect(result.state.pendingDecision, isNull);
    });

    test(
      'skill check creates a reroll decision and resolution unblocks actions',
      () {
        final afterRoll = step(
          _state(),
          const SkillCheckCommand(StatType.science),
          FixedDiceRoller([2]),
        );
        final pending =
            afterRoll.state.pendingDecision! as AwaitingRerollChoice;

        expect(afterRoll.state.actionsLeft, 1);
        expect(pending.dice, [2]);
        expect(pending.availableRerolls, 1);
        expect(pending.window.remainingTicks, 1);

        final resolved = step(
          afterRoll.state,
          const ResolvePendingDecisionCommand(KeepRollChoice()),
          FixedDiceRoller([]),
        );
        expect(resolved.state.pendingDecision, isNull);
        expect(
          validate(resolved.state, const MoveCommand(HexCoord(0, 1))),
          isNull,
        );
      },
    );

    test('rerolls selected dice while keeping the decision pending', () {
      final state = _state(
        pendingDecision: AwaitingRerollChoice(
          dice: const [1, 6],
          availableRerolls: 1,
          window: const DecisionWindow(remainingTicks: 2),
        ),
      );

      final result = step(
        state,
        ResolvePendingDecisionCommand(RerollChoice(diceIndexes: [0])),
        FixedDiceRoller([5]),
      );

      final pending = result.state.pendingDecision! as AwaitingRerollChoice;
      expect(pending.dice, [5, 6]);
      expect(pending.availableRerolls, 0);
    });

    test('dodge uses agility hits to prevent incoming damage', () {
      final state = _state(
        pendingDecision: const AwaitingDodge(
          monsterDamage: 2,
          requiredAgilitySuccesses: 2,
        ),
      );

      final result = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([5, 1]),
      );

      expect(result.state.pendingDecision, isNull);
      expect(result.state.players.single.damage, 1);
    });

    test('event option only resolves an available branch', () {
      final state = _state(
        pendingDecision: AwaitingEventOption(options: const ['A', 'B']),
      );

      final invalid = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('C')),
        FixedDiceRoller([]),
      );
      final accepted = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('B')),
        FixedDiceRoller([]),
      );

      expect(invalid.rejection, isA<ActionBlockedByPendingDecision>());
      expect(accepted.state.pendingDecision, isNull);
      expect(accepted.state.log.last, 'event-option:ada:B');
    });
  });
}

GameState _state({
  int actionsLeft = 2,
  Iterable<HexTile>? board,
  PendingDecision? pendingDecision,
}) => GameState(
  seed: 7,
  round: 1,
  phase: GamePhase.players,
  activePlayerId: 'ada',
  actionsLeft: actionsLeft,
  board:
      board ??
      [
        _tile('start', const HexCoord(0, 0), {HexEdge.south}),
        _tile('next', const HexCoord(0, 1), {HexEdge.north}),
      ],
  players: [_player()],
  monsters: [
    MonsterInstance(
      instanceId: 'monster',
      monsterId: 'ghoul',
      coord: const HexCoord(0, 0),
      damage: 0,
    ),
  ],
  decks: const {},
  quests: QuestState(),
  pendingDecision: pendingDecision,
);

HexTile _tile(String id, HexCoord coord, Set<HexEdge> exits) => HexTile(
  id: id,
  coord: coord,
  type: HexTileType.corridor,
  opened: true,
  exits: exits,
  hasTerminal: false,
  ventColor: VentColor.none,
);

PlayerState _player() => PlayerState(
  id: 'ada',
  characterId: 'guard',
  coord: const HexCoord(0, 0),
  damage: 0,
  credits: 0,
  backpack: const [],
  equipped: const EquippedGear(),
  carriedMods: const [],
  implanted: const [],
  conditions: const [],
  alive: true,
);
