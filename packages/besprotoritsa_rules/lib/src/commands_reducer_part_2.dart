// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

/// Reports why [command] cannot be applied to [state], or null when it can.
CommandRejection? validate(GameState state, GameCommand command) {
  if (state.isComplete) {
    return const GameAlreadyCompleted();
  }
  if (state.pendingDecision != null &&
      command is! ResolvePendingDecisionCommand) {
    return const ActionBlockedByPendingDecision();
  }

  if (command is ResolvePendingDecisionCommand) {
    return state.pendingDecision == null
        ? const ActionBlockedByPendingDecision()
        : null;
  }

  if (state.phase != GamePhase.playersTurn) {
    return const ActionUnavailableInPhase();
  }

  if (command is EndTurnCommand) {
    return null;
  }

  // A fallen hero stays in the turn order until the replacement transition
  // reaches its normal end-turn boundary.  It may end that turn, but can
  // never issue another game action while dead.
  if (_activePlayer(state)?.alive != true) {
    return const ActionUnavailableInPhase();
  }

  if (command case HealCommand(:final amount) when amount <= 0) {
    return const InvalidCommandArguments();
  }

  if (command case ExchangeCommand(
    :final giveCredits,
    :final receiveCredits,
  ) when giveCredits < 0 || receiveCredits < 0) {
    return const InvalidCommandArguments();
  }

  if (command is ImplantModificationCommand && state.actionsTakenThisTurn > 0) {
    return const ImplantWindowClosed();
  }

  if (command is DepositCreditsIntoChestCommand) {
    return const CreditsCannotBeStoredInChest();
  }

  if (command is DepositIntoChestCommand ||
      command is WithdrawFromChestCommand) {
    final player = _activePlayer(state);
    if (player == null ||
        state.tileAt(player.coord)?.type != HexTileType.start) {
      return const ChestUnavailable();
    }
    try {
      if (command case DepositIntoChestCommand(:final cardId)) {
        InventoryRules.discard(player, cardId);
      } else if (command case WithdrawFromChestCommand(:final cardId)) {
        if (!state.chestCards.contains(cardId)) {
          throw InventoryRuleViolation('The card is not in the chest.');
        }
        InventoryRules.receive(player, cardId, state.cardDefinitions);
      }
    } on BackpackCapacityExceeded catch (error) {
      return InventoryCommandRejected(
        'Backpack capacity ${error.capacity} would be exceeded.',
      );
    } on InventoryRuleViolation catch (error) {
      return InventoryCommandRejected(error.message);
    }
    return null;
  }

  if (_isInventoryCommand(command)) {
    try {
      _applyInventoryCommand(state, command);
    } on BackpackCapacityExceeded catch (error) {
      return InventoryCommandRejected(
        'Backpack capacity ${error.capacity} would be exceeded.',
      );
    } on InventoryRuleViolation catch (error) {
      return InventoryCommandRejected(error.message);
    }
    return null;
  }

  if (state.actionsLeft == 0 || _activePlayer(state) == null) {
    return const NotEnoughActions();
  }

  if (command is UseTerminalCommand) {
    final player = _activePlayer(state)!;
    final tile = state.tileAt(player.coord);
    final supplies = state.decks['supplies'];
    if (tile == null ||
        tile.type != HexTileType.compartment ||
        !tile.hasTerminal ||
        state.monsters.any((monster) => monster.coord == player.coord) ||
        supplies == null ||
        (supplies.drawPile.isEmpty && supplies.discardPile.isEmpty)) {
      return const TerminalUnavailable();
    }
  }

  if (command is ExchangeCommand) {
    final player = _activePlayer(state)!;
    final partner = _playerById(state, command.partnerId);
    if (partner == null ||
        partner.id == player.id ||
        partner.coord != player.coord ||
        (command.giveCardId == null &&
            command.receiveCardId == null &&
            command.giveCredits == 0 &&
            command.receiveCredits == 0) ||
        command.giveCredits > player.credits ||
        command.receiveCredits > partner.credits) {
      return const ExchangeUnavailable();
    }
    try {
      _exchangePlayers(state, player, partner, command);
    } on BackpackCapacityExceeded catch (error) {
      return InventoryCommandRejected(
        'Backpack capacity ${error.capacity} would be exceeded.',
      );
    } on InventoryRuleViolation catch (error) {
      return InventoryCommandRejected(error.message);
    }
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
    if (source.isBlocked || destination.isBlocked) {
      return const PathBlocked();
    }
    if (state.actionsLeft < _movementCost(destination)) {
      return const NotEnoughActions();
    }
  }

  if (command case AirlockMoveCommand(:final target, :final equipment)) {
    final player = _activePlayer(state)!;
    final source = state.tileAt(player.coord);
    final destination = state.tileAt(target);
    if (source == null || destination == null) {
      return const InvalidTargetCoord();
    }
    final cost = airlockTransferCost(source, destination, equipment);
    if (cost == null) {
      return const TargetOutOfRange();
    }
    if (state.actionsLeft < cost) {
      return const NotEnoughActions();
    }
  }

  if (command case CloseCorridorCommand(:final target)) {
    final player = _activePlayer(state)!;
    final source = state.tileAt(player.coord);
    final corridor = state.tileAt(target);
    final edge = player.coord.edgeTowardOrNull(target);
    final occupied =
        state.players.any((hero) => hero.coord == target) ||
        state.monsters.any((monster) => monster.coord == target) ||
        state.boils.any((boil) => boil.coord == target);
    if (source == null ||
        corridor == null ||
        edge == null ||
        corridor.type != HexTileType.corridor ||
        corridor.isBlocked ||
        occupied ||
        !source.hasExit(edge) ||
        !corridor.hasExit(edge.opposite)) {
      return const CorridorCannotBeClosed();
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

  final result = switch (command) {
    MoveCommand(:final target) => _move(
      state,
      target,
      _movementCost(state.tileAt(target)!),
    ),
    AirlockMoveCommand(:final target, :final equipment) => _move(
      state,
      target,
      airlockTransferCost(
        state.tileAt(_activePlayer(state)!.coord)!,
        state.tileAt(target)!,
        equipment,
      )!,
    ),
    CloseCorridorCommand(:final target) => _closeCorridor(state, target),
    AttackCommand(:final targetInstanceId) => _attack(
      state,
      targetInstanceId,
      dice,
    ),
    SkillCheckCommand(:final stat) => _startPlayerSkillCheck(state, stat, dice),
    ResolvePendingDecisionCommand(:final choice) => _resolveDecision(
      state,
      choice,
      dice,
    ),
    EndTurnCommand() => GameStepResult(state: _endTurn(state)),
    HealCommand(:final amount) => GameStepResult(state: _heal(state, amount)),
    EquipCommand() ||
    UnequipCommand() ||
    ReceiveCardCommand() ||
    ImplantModificationCommand() => GameStepResult(
      state: _applyInventoryCommand(state, command),
    ),
    UseTerminalCommand() => _useTerminal(state),
    DepositIntoChestCommand() || WithdrawFromChestCommand() => GameStepResult(
      state: _applyChestCommand(state, command),
    ),
    DepositCreditsIntoChestCommand() => throw StateError(
      'Validated as rejected.',
    ),
    ExchangeCommand() => GameStepResult(state: _exchange(state, command)),
  };
  final didTakeAction = _isActionCommand(command) && result.rejection == null;
  final resultState = didTakeAction
      ? _copyState(
          result.state,
          actionsTakenThisTurn: state.actionsTakenThisTurn + 1,
        )
      : result.state;
  return GameStepResult(
    state: resultState,
    rejection: result.rejection,
    events: _eventsForTransition(state, resultState),
  );
}
