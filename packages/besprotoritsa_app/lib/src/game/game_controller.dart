import 'package:besprotoritsa_app/src/game/event_queue.dart';
import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared animation pipeline for the MVP game UI.
final eventQueueProvider = Provider<EventQueue>((ref) {
  final queue = EventQueue();
  ref.onDispose(queue.dispose);
  return queue;
});

/// The authoritative game state and the only UI entrypoint for commands.
final gameControllerProvider =
    NotifierProvider<GameSessionController, GameState>(
      GameController.new,
    );

/// Common command surface for local and authoritative network sessions.
abstract class GameSessionController extends Notifier<GameState> {
  /// Submits a player action. A network controller returns true once queued;
  /// its state changes only after the server confirms the command.
  bool dispatch(GameCommand command);
}

/// Validates commands in the rules package, applies accepted steps, and queues
/// their semantic events for the presentation layer.
class GameController extends GameSessionController {
  /// Allows tests and alternate scenarios to inject deterministic state.
  GameController({GameState? initialState, DiceRoller? dice})
    : _initialState = initialState,
      _dice = dice;

  final GameState? _initialState;
  final DiceRoller? _dice;
  late final DiceRoller _roller;

  @override
  GameState build() {
    final initialState = _initialState ?? createMvpGameState();
    _roller = _dice ?? SeededDiceRoller(initialState.seed);
    return initialState;
  }

  /// Applies [command] if the input is currently allowed and valid.
  @override
  bool dispatch(GameCommand command) {
    final queue = ref.read(eventQueueProvider);
    if (queue.isPlaying || validate(state, command) != null) return false;
    final result = step(state, command, _roller);
    if (!result.isAccepted) return false;
    state = result.state;
    queue.enqueue(result.events);
    return true;
  }
}
