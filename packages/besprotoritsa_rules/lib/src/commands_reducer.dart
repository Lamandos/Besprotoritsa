// Commands and their reducer are deliberately kept dependency-free so an
// identical transition can run on a client, server, or replay verifier.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/dice_roller.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';
import 'package:meta/meta.dart';

enum StatType { strength, combatStrength, science, repair, endurance, agility }

sealed class GameCommand {
  const GameCommand();
}

final class MoveCommand extends GameCommand {
  const MoveCommand(this.target);

  final HexCoord target;
}

final class AttackCommand extends GameCommand {
  const AttackCommand(this.targetInstanceId);

  final String targetInstanceId;
}

final class SkillCheckCommand extends GameCommand {
  const SkillCheckCommand(this.stat);

  final StatType stat;
}

final class ResolvePendingDecisionCommand extends GameCommand {
  const ResolvePendingDecisionCommand(this.choice);

  final DecisionChoice choice;
}

final class EndTurnCommand extends GameCommand {
  const EndTurnCommand();
}

sealed class CommandRejection {
  const CommandRejection();
}

final class NotEnoughActions extends CommandRejection {
  const NotEnoughActions();
}

final class InvalidTargetCoord extends CommandRejection {
  const InvalidTargetCoord();
}

final class PortMismatch extends CommandRejection {
  const PortMismatch();
}

final class TargetOutOfRange extends CommandRejection {
  const TargetOutOfRange();
}

final class ActionBlockedByPendingDecision extends CommandRejection {
  const ActionBlockedByPendingDecision();
}

sealed class DecisionChoice {
  const DecisionChoice();
}

final class KeepRollChoice extends DecisionChoice {
  const KeepRollChoice();
}

/// Rerolls the specified dice. An empty [diceIndexes] means all dice.
final class RerollChoice extends DecisionChoice {
  RerollChoice({Iterable<int> diceIndexes = const []})
    : diceIndexes = List.unmodifiable(diceIndexes);

  final List<int> diceIndexes;
}

final class DodgeChoice extends DecisionChoice {
  const DodgeChoice();
}

final class EventOptionChoice extends DecisionChoice {
  const EventOptionChoice(this.option);

  final String option;
}

@immutable
final class GameStepResult {
  const GameStepResult({required this.state, this.rejection});

  final GameState state;
  final CommandRejection? rejection;

  GameState get nextState => state;
  bool get isAccepted => rejection == null;
}

/// Reports why [command] cannot be applied to [state], or null when it can.
CommandRejection? validate(GameState state, GameCommand command) {
  if (state.pendingDecision != null &&
      command is! ResolvePendingDecisionCommand) {
    return const ActionBlockedByPendingDecision();
  }

  if (command is ResolvePendingDecisionCommand) {
    return state.pendingDecision == null
        ? const ActionBlockedByPendingDecision()
        : null;
  }

  if (command is EndTurnCommand) {
    return null;
  }

  if (state.actionsLeft == 0 || _activePlayer(state) == null) {
    return const NotEnoughActions();
  }

  if (command case MoveCommand(:final target)) {
    final player = _activePlayer(state)!;
    final source = state.tileAt(player.coord);
    final destination = state.tileAt(target);
    if (source == null || !source.opened || destination == null) {
      return const InvalidTargetCoord();
    }
    final edge = player.coord.edgeTowardOrNull(target);
    if (edge == null) {
      return const TargetOutOfRange();
    }
    if (!source.hasExit(edge) || !destination.hasExit(edge.opposite)) {
      return const PortMismatch();
    }
    if (state.actionsLeft < _movementCost(destination)) {
      return const NotEnoughActions();
    }
  }

  if (command case AttackCommand(:final targetInstanceId)) {
    final player = _activePlayer(state)!;
    final monster = _monsterById(state, targetInstanceId);
    if (monster == null || player.coord.distanceTo(monster.coord) != 0) {
      return const TargetOutOfRange();
    }
  }

  return null;
}

/// Applies one command without mutating [state]. Rejected commands return the
/// original state unchanged and describe their rejection in the result.
GameStepResult step(GameState state, GameCommand command, DiceRoller dice) {
  final rejection = validate(state, command);
  if (rejection != null) {
    return GameStepResult(state: state, rejection: rejection);
  }

  return switch (command) {
    MoveCommand(:final target) => _move(state, target),
    AttackCommand(:final targetInstanceId) => _startRoll(
      state,
      dice,
      'attack:${state.activePlayerId}:$targetInstanceId',
    ),
    SkillCheckCommand(:final stat) => _startRoll(
      state,
      dice,
      'skill-check:${state.activePlayerId}:${stat.name}',
    ),
    ResolvePendingDecisionCommand(:final choice) => _resolveDecision(
      state,
      choice,
      dice,
    ),
    EndTurnCommand() => GameStepResult(state: _endTurn(state)),
  };
}

GameStepResult _move(GameState state, HexCoord target) {
  final destination = state.tileAt(target)!;
  final opensSector = !destination.opened;
  return GameStepResult(
    state: _copyState(
      state,
      actionsLeft: state.actionsLeft - _movementCost(destination),
      board: opensSector ? _openTile(state.board, destination) : null,
      players: _replaceActivePlayer(
        state,
        (player) => _copyPlayer(player, coord: target),
      ),
      logEntry: 'move:${state.activePlayerId}:$target',
    ),
  );
}

int _movementCost(HexTile destination) => destination.opened ? 1 : 2;

List<HexTile> _openTile(List<HexTile> board, HexTile destination) => [
  for (final tile in board)
    if (tile.coord == destination.coord)
      HexTile(
        id: tile.id,
        coord: tile.coord,
        type: tile.type,
        opened: true,
        exits: tile.exits,
        locationId: tile.locationId,
        hasTerminal: tile.hasTerminal,
        ventColor: tile.ventColor,
      )
    else
      tile,
];

GameStepResult _startRoll(
  GameState state,
  DiceRoller dice,
  String logEntry,
) => GameStepResult(
  state: _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    pendingDecision: AwaitingRerollChoice(
      dice: dice.rollDice(1),
      availableRerolls: 1,
      window: const DecisionWindow(remainingTicks: 1),
    ),
    logEntry: logEntry,
  ),
);

GameStepResult _resolveDecision(
  GameState state,
  DecisionChoice choice,
  DiceRoller dice,
) {
  final pending = state.pendingDecision!;
  return switch (pending) {
    AwaitingRerollChoice() => _resolveReroll(state, pending, choice, dice),
    AwaitingDodge() => _resolveDodge(state, pending, choice, dice),
    AwaitingEventOption() => _resolveEventOption(state, pending, choice),
  };
}

GameStepResult _resolveReroll(
  GameState state,
  AwaitingRerollChoice pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is KeepRollChoice) {
    return GameStepResult(state: _copyState(state, clearPendingDecision: true));
  }
  if (choice is! RerollChoice || pending.availableRerolls == 0) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }

  final indexes = choice.diceIndexes.isEmpty
      ? List<int>.generate(pending.dice.length, (index) => index)
      : choice.diceIndexes;
  if (indexes.any((index) => index < 0 || index >= pending.dice.length)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final rerolled = List<int>.of(pending.dice);
  final newRolls = dice.rollDice(indexes.length);
  for (var index = 0; index < indexes.length; index++) {
    rerolled[indexes[index]] = newRolls[index];
  }
  return GameStepResult(
    state: _copyState(
      state,
      pendingDecision: AwaitingRerollChoice(
        dice: rerolled,
        availableRerolls: pending.availableRerolls - 1,
        window: pending.window,
      ),
    ),
  );
}

GameStepResult _resolveDodge(
  GameState state,
  AwaitingDodge pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is! DodgeChoice) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final hits = countHits(dice.rollDice(pending.requiredAgilitySuccesses));
  final remainingDamage = (pending.monsterDamage - hits).clamp(
    0,
    pending.monsterDamage,
  );
  return GameStepResult(
    state: _copyState(
      state,
      players: _replaceActivePlayer(
        state,
        (player) =>
            _copyPlayer(player, damage: player.damage + remainingDamage),
      ),
      clearPendingDecision: true,
      logEntry: 'dodge:${state.activePlayerId}:$remainingDamage',
    ),
  );
}

GameStepResult _resolveEventOption(
  GameState state,
  AwaitingEventOption pending,
  DecisionChoice choice,
) {
  if (choice is! EventOptionChoice ||
      !pending.options.contains(choice.option)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  return GameStepResult(
    state: _copyState(
      state,
      clearPendingDecision: true,
      logEntry: 'event-option:${state.activePlayerId}:${choice.option}',
    ),
  );
}

GameState _endTurn(GameState state) {
  final activeIndex = state.players.indexWhere(
    (player) => player.id == state.activePlayerId,
  );
  final nextIndex = _nextLivingPlayerIndex(state.players, activeIndex);
  if (nextIndex == null) {
    return _copyState(state, actionsLeft: 0);
  }
  final nextRound = activeIndex >= 0 && nextIndex <= activeIndex
      ? state.round + 1
      : state.round;
  return _copyState(
    state,
    activePlayerId: state.players[nextIndex].id,
    actionsLeft: 2,
    round: nextRound,
    logEntry: 'end-turn:${state.activePlayerId}',
  );
}

int? _nextLivingPlayerIndex(List<PlayerState> players, int activeIndex) {
  if (players.isEmpty) {
    return null;
  }
  final start = activeIndex < 0 ? 0 : (activeIndex + 1) % players.length;
  for (var offset = 0; offset < players.length; offset++) {
    final index = (start + offset) % players.length;
    if (players[index].alive) {
      return index;
    }
  }
  return null;
}

PlayerState? _activePlayer(GameState state) {
  final id = state.activePlayerId;
  if (id == null) {
    return null;
  }
  for (final player in state.players) {
    if (player.id == id) {
      return player;
    }
  }
  return null;
}

MonsterInstance? _monsterById(GameState state, String instanceId) {
  for (final monster in state.monsters) {
    if (monster.instanceId == instanceId) {
      return monster;
    }
  }
  return null;
}

List<PlayerState> _replaceActivePlayer(
  GameState state,
  PlayerState Function(PlayerState player) replace,
) => [
  for (final player in state.players)
    if (player.id == state.activePlayerId) replace(player) else player,
];

PlayerState _copyPlayer(PlayerState player, {HexCoord? coord, int? damage}) =>
    PlayerState(
      id: player.id,
      characterId: player.characterId,
      coord: coord ?? player.coord,
      damage: damage ?? player.damage,
      credits: player.credits,
      backpack: player.backpack,
      equipped: player.equipped,
      carriedMods: player.carriedMods,
      implanted: player.implanted,
      conditions: player.conditions,
      alive: player.alive,
    );

GameState _copyState(
  GameState state, {
  int? round,
  PlayerId? activePlayerId,
  int? actionsLeft,
  Iterable<HexTile>? board,
  Iterable<PlayerState>? players,
  PendingDecision? pendingDecision,
  bool clearPendingDecision = false,
  String? logEntry,
}) => GameState(
  schemaVersion: state.schemaVersion,
  seed: state.seed,
  round: round ?? state.round,
  phase: state.phase,
  activePlayerId: activePlayerId ?? state.activePlayerId,
  actionsLeft: actionsLeft ?? state.actionsLeft,
  board: board ?? state.board,
  players: players ?? state.players,
  monsters: state.monsters,
  decks: state.decks,
  quests: state.quests,
  log: [...state.log, if (logEntry != null) logEntry],
  pendingDecision: clearPendingDecision
      ? null
      : pendingDecision ?? state.pendingDecision,
);
