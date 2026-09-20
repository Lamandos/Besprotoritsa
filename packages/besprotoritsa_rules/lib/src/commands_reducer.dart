// Commands and their reducer are deliberately kept dependency-free so an
// identical transition can run on a client, server, or replay verifier.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/board_generator.dart';
import 'package:besprotoritsa_rules/src/card_definition.dart';
import 'package:besprotoritsa_rules/src/combat_models.dart';
import 'package:besprotoritsa_rules/src/dice_roller.dart';
import 'package:besprotoritsa_rules/src/effect_engine.dart';
import 'package:besprotoritsa_rules/src/effect_hooks.dart';
import 'package:besprotoritsa_rules/src/effect_registry.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';
import 'package:besprotoritsa_rules/src/inventory_rules.dart';
import 'package:meta/meta.dart';

sealed class GameCommand {
  const GameCommand();
}

final class MoveCommand extends GameCommand {
  const MoveCommand(this.target);

  final HexCoord target;
}

/// Moves between any two opened airlocks using the supplied movement aid.
final class AirlockMoveCommand extends GameCommand {
  const AirlockMoveCommand(this.target, this.equipment);

  final HexCoord target;
  final AirlockEquipment equipment;
}

/// Seals an adjacent, empty corridor for the remainder of the game.
final class CloseCorridorCommand extends GameCommand {
  const CloseCorridorCommand(this.target);

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

/// Restores damage to the active hero and discards all of their conditions.
final class HealCommand extends GameCommand {
  const HealCommand(this.amount)
    : assert(amount > 0, 'amount must be positive');

  final int amount;
}

/// Equips a backpack card without spending an action.
final class EquipCommand extends GameCommand {
  const EquipCommand(this.cardId, {this.weaponSlot = 0});

  final CardId cardId;
  final int weaponSlot;
}

/// Unequips a visible equipment slot without spending an action.
final class UnequipCommand extends GameCommand {
  const UnequipCommand(this.slot, {this.weaponSlot = 0});

  final ItemSlot slot;
  final int weaponSlot;
}

/// Gives the active player a card. A received modification may be implanted
/// immediately, including after the player has already taken an action.
final class ReceiveCardCommand extends GameCommand {
  const ReceiveCardCommand(this.cardId, {this.implantImmediately = false});

  final CardId cardId;
  final bool implantImmediately;
}

/// Permanently implants an already carried modification before the active
/// player has taken their first action this turn.
final class ImplantModificationCommand extends GameCommand {
  const ImplantModificationCommand(this.cardId);

  final CardId cardId;
}

/// Spends one action to reveal the top supplies at a terminal.
final class UseTerminalCommand extends GameCommand {
  const UseTerminalCommand();
}

/// Places a carried card into the shared chest in the start sector.
final class DepositIntoChestCommand extends GameCommand {
  const DepositIntoChestCommand(this.cardId);

  final CardId cardId;
}

/// Takes one card from the shared chest in the start sector.
final class WithdrawFromChestCommand extends GameCommand {
  const WithdrawFromChestCommand(this.cardId);

  final CardId cardId;
}

/// Credits are currency, not chest contents. This explicit command exists so
/// clients can receive a rules rejection instead of modelling credits as cards.
final class DepositCreditsIntoChestCommand extends GameCommand {
  const DepositCreditsIntoChestCommand(this.amount)
    : assert(amount > 0, 'amount must be positive');

  final int amount;
}

/// Atomically exchanges optional cards and/or credits with a co-located hero.
/// At least one side must transfer something.
final class ExchangeCommand extends GameCommand {
  const ExchangeCommand({
    required this.partnerId,
    this.giveCardId,
    this.receiveCardId,
    this.giveCredits = 0,
    this.receiveCredits = 0,
  }) : assert(giveCredits >= 0, 'giveCredits must not be negative'),
       assert(receiveCredits >= 0, 'receiveCredits must not be negative');

  final PlayerId partnerId;
  final CardId? giveCardId;
  final CardId? receiveCardId;
  final int giveCredits;
  final int receiveCredits;
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

final class PathBlocked extends CommandRejection {
  const PathBlocked();
}

final class CorridorCannotBeClosed extends CommandRejection {
  const CorridorCannotBeClosed();
}

final class TargetOutOfRange extends CommandRejection {
  const TargetOutOfRange();
}

final class ActionBlockedByPendingDecision extends CommandRejection {
  const ActionBlockedByPendingDecision();
}

final class ActionUnavailableInPhase extends CommandRejection {
  const ActionUnavailableInPhase();
}

final class GameAlreadyCompleted extends CommandRejection {
  const GameAlreadyCompleted();
}

final class InventoryCommandRejected extends CommandRejection {
  const InventoryCommandRejected(this.reason);

  final String reason;
}

final class ImplantWindowClosed extends CommandRejection {
  const ImplantWindowClosed();
}

final class TerminalUnavailable extends CommandRejection {
  const TerminalUnavailable();
}

final class ChestUnavailable extends CommandRejection {
  const ChestUnavailable();
}

final class CreditsCannotBeStoredInChest extends CommandRejection {
  const CreditsCannotBeStoredInChest();
}

final class ExchangeUnavailable extends CommandRejection {
  const ExchangeUnavailable();
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

/// Buys one of the supplies currently offered by [AwaitingTerminalPick].
final class TerminalPickChoice extends DecisionChoice {
  const TerminalPickChoice(this.cardId);

  final CardId cardId;
}

/// Returns every currently offered terminal supply without buying one.
final class DeclineTerminalPickChoice extends DecisionChoice {
  const DeclineTerminalPickChoice();
}

/// Selects an unused character after this player's previous hero died.
final class SelectReplacementHeroChoice extends DecisionChoice {
  const SelectReplacementHeroChoice(this.characterId);

  final CharacterId characterId;
}

@immutable
final class GameStepResult {
  GameStepResult({
    required this.state,
    this.rejection,
    Iterable<GameEvent> events = const [],
  }) : events = List.unmodifiable(events);

  final GameState state;
  final CommandRejection? rejection;
  final List<GameEvent> events;

  GameState get nextState => state;
  bool get isAccepted => rejection == null;
}

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

bool _isInventoryCommand(GameCommand command) =>
    command is EquipCommand ||
    command is UnequipCommand ||
    command is ReceiveCardCommand ||
    command is ImplantModificationCommand;

bool _isActionCommand(GameCommand command) =>
    command is MoveCommand ||
    command is AirlockMoveCommand ||
    command is CloseCorridorCommand ||
    command is AttackCommand ||
    command is SkillCheckCommand ||
    command is HealCommand ||
    command is UseTerminalCommand ||
    command is ExchangeCommand;

GameState _applyInventoryCommand(GameState state, GameCommand command) {
  final player = _activePlayer(state);
  if (player == null) {
    throw InventoryRuleViolation('There is no active player.');
  }
  final definitions = state.cardDefinitions;
  final updated = switch (command) {
    EquipCommand(:final cardId, :final weaponSlot) => InventoryRules.equip(
      player,
      cardId,
      definitions,
      weaponSlot: weaponSlot,
    ),
    UnequipCommand(:final slot, :final weaponSlot) => InventoryRules.unequip(
      player,
      slot,
      definitions,
      weaponSlot: weaponSlot,
    ),
    ReceiveCardCommand(:final cardId, :final implantImmediately) =>
      _receiveCard(player, cardId, definitions, implantImmediately),
    ImplantModificationCommand(:final cardId) => InventoryRules.implant(
      player,
      cardId,
      definitions,
    ),
    _ => throw ArgumentError.value(
      command,
      'command',
      'Not an inventory command.',
    ),
  };
  return _copyState(
    state,
    players: _replacePlayer(state, player.id, (_) => updated),
    logEntry: 'inventory:${player.id}:${command.runtimeType}',
  );
}

PlayerState _receiveCard(
  PlayerState player,
  CardId cardId,
  Map<CardId, CardDefinition> definitions,
  bool implantImmediately,
) {
  final received = InventoryRules.receive(player, cardId, definitions);
  return implantImmediately
      ? InventoryRules.implant(received, cardId, definitions)
      : received;
}

GameStepResult _useTerminal(GameState state) {
  final player = _activePlayer(state)!;
  final draw = DeckRules.draw(
    state.decks['supplies']!,
    count: 3,
    seed: _deckSeed(state, 'supplies'),
  );
  final decks = Map<DeckId, DeckState>.of(state.decks)
    ..['supplies'] = draw.deck;
  return GameStepResult(
    state: _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      decks: decks,
      pendingDecision: AwaitingTerminalPick(
        offeredCards: draw.cards,
        playerId: player.id,
      ),
      logEntry: 'terminal:${player.id}:${draw.cards.join(',')}',
    ),
  );
}

GameState _applyChestCommand(GameState state, GameCommand command) {
  final player = _activePlayer(state)!;
  return switch (command) {
    DepositIntoChestCommand(:final cardId) => _copyState(
      state,
      players: _replacePlayer(
        state,
        player.id,
        (current) => InventoryRules.discard(current, cardId),
      ),
      chestCards: [...state.chestCards, cardId],
      logEntry: 'chest-deposit:${player.id}:$cardId',
    ),
    WithdrawFromChestCommand(:final cardId) => _copyState(
      state,
      players: _replacePlayer(
        state,
        player.id,
        (current) => InventoryRules.receive(
          current,
          cardId,
          state.cardDefinitions,
        ),
      ),
      chestCards: _removeOne(state.chestCards, cardId),
      logEntry: 'chest-withdraw:${player.id}:$cardId',
    ),
    _ => throw ArgumentError.value(
      command,
      'command',
      'Not a chest command.',
    ),
  };
}

GameState _exchange(GameState state, ExchangeCommand command) {
  final player = _activePlayer(state)!;
  final partner = _playerById(state, command.partnerId)!;
  final exchanged = _exchangePlayers(state, player, partner, command);
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: [
      for (final current in state.players)
        if (current.id == player.id)
          exchanged.from
        else if (current.id == partner.id)
          exchanged.to
        else
          current,
    ],
    logEntry: 'exchange:${player.id}:${partner.id}',
  );
}

InventoryTransfer _exchangePlayers(
  GameState state,
  PlayerState player,
  PlayerState partner,
  ExchangeCommand command,
) {
  var from = player;
  var to = partner;
  if (command.giveCardId case final cardId?) {
    final transfer = InventoryRules.transfer(
      from,
      to,
      cardId,
      state.cardDefinitions,
    );
    from = transfer.from;
    to = transfer.to;
  }
  if (command.receiveCardId case final cardId?) {
    final transfer = InventoryRules.transfer(
      to,
      from,
      cardId,
      state.cardDefinitions,
    );
    from = transfer.to;
    to = transfer.from;
  }
  return InventoryTransfer(
    from: _copyPlayer(
      from,
      credits: from.credits - command.giveCredits + command.receiveCredits,
    ),
    to: _copyPlayer(
      to,
      credits: to.credits + command.giveCredits - command.receiveCredits,
    ),
  );
}

List<CardId> _removeOne(Iterable<CardId> cards, CardId cardId) {
  final remaining = List<CardId>.of(cards);
  if (!remaining.remove(cardId)) {
    throw StateError('Expected card "$cardId" to be present.');
  }
  return remaining;
}

int _deckSeed(GameState state, DeckId deckId) {
  var value = (state.seed ^ state.round ^ state.log.length) & 0x7fffffff;
  for (final codeUnit in deckId.codeUnits) {
    value = ((value * 31) ^ codeUnit) & 0x7fffffff;
  }
  return value;
}

List<GameEvent> _eventsForTransition(GameState before, GameState after) {
  final events = <GameEvent>[];
  for (final player in after.players) {
    final previous = _playerById(before, player.id);
    if (previous == null) continue;
    final enteredHex = previous.coord != player.coord;
    if (enteredHex) {
      events.add(
        HexEntered(playerId: player.id, from: previous.coord, to: player.coord),
      );
    }
    if (enteredHex && after.pendingDecision is AwaitingDodge) {
      events.add(ColocationTriggered(playerId: player.id, coord: player.coord));
    }
    final damage = player.damage - previous.damage;
    if (damage > 0) {
      events.add(DamageDealt(playerId: player.id, amount: damage));
    }
    final previousConditions = List<CardId>.of(previous.conditions);
    for (final condition in player.conditions) {
      if (previousConditions.remove(condition)) continue;
      events.add(ConditionDrawn(playerId: player.id, conditionId: condition));
    }
  }
  return events;
}

GameStepResult _move(GameState state, HexCoord target, int cost) {
  final destination = state.tileAt(target)!;
  final opensSector = !destination.opened;
  final moved = _copyState(
    state,
    actionsLeft: state.actionsLeft - cost,
    board: opensSector ? _openTile(state.board, destination) : null,
    players: _replaceActivePlayer(
      state,
      (player) => _copyPlayer(player, coord: target),
    ),
    logEntry: 'move:${state.activePlayerId}:$target',
  );
  return GameStepResult(state: resolveColocation(moved));
}

GameStepResult _closeCorridor(GameState state, HexCoord target) =>
    GameStepResult(
      state: _copyState(
        state,
        actionsLeft: state.actionsLeft - 1,
        board: [
          for (final tile in state.board)
            if (tile.coord == target)
              _copyTile(tile, isBlocked: true)
            else
              tile,
        ],
        logEntry: 'corridor-closed:${state.activePlayerId}:$target',
      ),
    );

/// Resolves threats in shared cells, creating one dodge decision per hit.
///
/// Calls made while another dodge is open append their damage after the current
/// decision, preserving a deterministic order of monsters, then Boils.
GameState resolveColocation(GameState state) {
  final damage = <IncomingDamage>[];
  for (final monster in state.monsters) {
    if (monster.attack == 0) {
      continue;
    }
    for (final player in state.players) {
      if (player.alive && player.coord == monster.coord) {
        damage.add(
          IncomingDamage(
            targetPlayerId: player.id,
            amount: monster.attack,
            agilityDice: _statDice(player, state, StatType.agility),
            source: DamageSource.monster,
          ),
        );
      }
    }
  }
  final exploding = state.boils
      .where(
        (boil) => state.players.any(
          (player) => player.alive && player.coord == boil.coord,
        ),
      )
      .toList();
  for (final boil in exploding) {
    for (final player in state.players) {
      if (player.alive && player.coord == boil.coord) {
        damage.add(
          IncomingDamage(
            targetPlayerId: player.id,
            amount: 1,
            agilityDice: _statDice(player, state, StatType.agility),
            source: DamageSource.boil,
          ),
        );
      }
    }
  }
  final resolved = _copyState(
    state,
    boils: state.boils.where((boil) => !exploding.contains(boil)),
    pendingDamage: [...state.pendingDamage, ...damage],
  );
  return _startNextIncomingDamage(resolved);
}

/// Moves a monster one board step and immediately resolves shared-cell attacks.
GameState moveMonsterOneStep(
  GameState state,
  String instanceId,
  HexCoord target,
) {
  final monster = _monsterById(state, instanceId);
  if (monster == null || monster.coord.distanceTo(target) != 1) {
    throw ArgumentError.value(target, 'target', 'Monster must move one step.');
  }
  final source = state.tileAt(monster.coord);
  final destination = state.tileAt(target);
  final edge = monster.coord.edgeToward(target);
  if (source == null ||
      destination == null ||
      source.isBlocked ||
      destination.isBlocked ||
      !source.hasExit(edge) ||
      !destination.hasExit(edge.opposite)) {
    throw ArgumentError.value(target, 'target', 'Monster path is blocked.');
  }
  return resolveColocation(
    _copyState(
      state,
      monsters: [
        for (final current in state.monsters)
          if (current.instanceId == instanceId)
            _copyMonster(current, coord: target)
          else
            current,
      ],
      logEntry: 'monster-move:$instanceId:$target',
    ),
  );
}

/// Places a Boil and immediately checks whether it detonates under a hero.
GameState spawnBoil(GameState state, BoilToken boil) => resolveColocation(
  _copyState(
    state,
    boils: [...state.boils, boil],
    logEntry: 'boil-spawn:${boil.instanceId}:${boil.coord}',
  ),
);

/// Places a monster and immediately resolves attacks in its arrival cell.
GameState spawnMonster(GameState state, MonsterInstance monster) =>
    resolveColocation(
      _copyState(
        state,
        monsters: [...state.monsters, monster],
        logEntry: 'monster-spawn:${monster.instanceId}:${monster.coord}',
      ),
    );

int _movementCost(HexTile destination) => destination.opened ? 1 : 2;

GameStepResult _attack(
  GameState state,
  String targetInstanceId,
  DiceRoller dice,
) {
  final player = _activePlayer(state)!;
  final hooks = _activeEffectHooks(state, player);
  final preAttackHooks = hooks.whereType<PreAttackDamageHook>();
  final preAttackDamage = preAttackHooks.isEmpty
      ? 0
      : const EffectEngine()
            .resolvePreAttackRoll(dice.rollDice(1), preAttackHooks)
            .targetDamage;
  final diceRoll = dice.rollDice(_heroAttackDice(player, state));
  final roll = const EffectEngine().resolveRoll(
    diceRoll,
    hooks,
  );
  if (roll.rerollsAvailable > 0) {
    return GameStepResult(
      state: _copyState(
        state,
        actionsLeft: state.actionsLeft - 1,
        pendingDecision: AwaitingRerollChoice(
          dice: diceRoll,
          availableRerolls: roll.rerollsAvailable,
          maxDicePerReroll: 1,
          window: const DecisionWindow(remainingTicks: 1),
          context: AttackRollContext(
            playerId: player.id,
            targetInstanceId: targetInstanceId,
            preAttackDamage: preAttackDamage,
          ),
        ),
        logEntry: 'attack-roll:${player.id}:$targetInstanceId',
      ),
    );
  }
  return GameStepResult(
    state: _resolveAttackRoll(
      state,
      player.id,
      targetInstanceId,
      diceRoll,
      consumesAction: true,
      preAttackDamage: preAttackDamage,
    ),
  );
}

GameState _resolveAttackRoll(
  GameState state,
  PlayerId playerId,
  String targetInstanceId,
  List<int> dice, {
  required bool consumesAction,
  int preAttackDamage = 0,
}) {
  final player = _playerById(state, playerId)!;
  final monster = _monsterById(state, targetInstanceId)!;
  final hooks = _activeEffectHooks(state, player);
  final roll = const EffectEngine().resolveRoll(dice, hooks);
  final damage =
      preAttackDamage + (roll.hits - monster.defense).clamp(0, roll.hits);
  final defeated = monster.damage + damage >= monster.health;
  final collateral = defeated
      ? const EffectEngine()
            .resolveKill(
              killedEnemyId: monster.instanceId,
              sectorId: monster.coord.toString(),
              enemySectors: {
                for (final enemy in state.monsters)
                  enemy.instanceId: enemy.coord.toString(),
              },
              hooks: hooks,
            )
            .damageByEnemyId
      : const <String, int>{};
  final monsters = <MonsterInstance>[];
  for (final current in state.monsters) {
    if (current.instanceId == monster.instanceId) continue;
    final totalDamage = current.damage + (collateral[current.instanceId] ?? 0);
    if (totalDamage < current.health) {
      monsters.add(_copyMonster(current, damage: totalDamage));
    }
  }
  var awardedPlayer = _copyPlayer(
    player,
    damage: player.damage + roll.ownerDamage,
  );
  if (defeated && monster.monsterId == RestlessMonster.restlessMonsterId) {
    awardedPlayer = _awardRestlessTrophies(awardedPlayer, monster, state);
  }
  return resolveHeroDeaths(
    _copyState(
      state,
      actionsLeft: consumesAction ? state.actionsLeft - 1 : state.actionsLeft,
      players: _replacePlayer(
        state,
        player.id,
        (_) => awardedPlayer,
      ),
      monsters: [
        if (!defeated) _copyMonster(monster, damage: monster.damage + damage),
        ...monsters,
      ],
      logEntry: _attackLog(player, monster, damage, defeated),
    ),
  );
}

PlayerState _awardRestlessTrophies(
  PlayerState player,
  MonsterInstance restless,
  GameState state,
) {
  var awarded = player;
  for (final cardId in restless.carriedGear) {
    awarded = InventoryRules.receive(awarded, cardId, state.cardDefinitions);
  }
  return awarded;
}

/// Converts every newly lethal hero into a Restless monster.
///
/// This function is public so non-combat damage effects can use the identical
/// death transition instead of reimplementing the loss of inventory and spawn.
GameState resolveHeroDeaths(GameState state) {
  final newlyDead = state.players
      .where((player) => player.alive && player.damage >= player.health)
      .toList();
  if (newlyDead.isEmpty) return state;

  final players = List<PlayerState>.of(state.players);
  final monsters = List<MonsterInstance>.of(state.monsters);
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final events = List<GameEvent>.of(state.gameEvents);
  AwaitingHeroReplacement? replacementDecision;
  var noReserve = false;

  for (final deceased in newlyDead) {
    final carriedGear = _restlessGear(deceased, state.cardDefinitions);
    final bonuses = _restlessBonuses(deceased, state.cardDefinitions);
    final instanceId = _nextRestlessInstanceId(state, deceased.id, monsters);
    monsters.add(
      RestlessMonster(
        instanceId: instanceId,
        coord: deceased.coord,
        attack: RestlessMonster.baseAttack + bonuses.strength,
        defense: RestlessMonster.baseDefense + bonuses.defense,
        carriedGear: carriedGear,
      ),
    );
    final deadIndex = players.indexWhere((player) => player.id == deceased.id);
    players[deadIndex] = _copyPlayer(
      deceased,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: false,
      weaponModifier: 0,
    );
    final conditionDeck = decks['conditions'];
    if (conditionDeck != null && deceased.conditions.isNotEmpty) {
      decks['conditions'] = DeckState(
        drawPile: conditionDeck.drawPile,
        discardPile: [...conditionDeck.discardPile, ...deceased.conditions],
      );
    }
    events.add(
      HeroDied(
        playerId: deceased.id,
        restlessInstanceId: instanceId,
        coord: deceased.coord,
      ),
    );
    if (state.reserveHeroes.isEmpty) {
      noReserve = true;
    } else {
      replacementDecision ??= AwaitingHeroReplacement(
        playerId: deceased.id,
        characterIds: state.reserveHeroes.map((hero) => hero.characterId),
      );
    }
  }

  return _copyState(
    state,
    players: players,
    monsters: monsters,
    decks: decks,
    pendingDamage: state.pendingDamage.where(
      (damage) => players.any(
        (player) => player.id == damage.targetPlayerId && player.alive,
      ),
    ),
    gameEvents: events,
    isComplete: noReserve || state.isComplete,
    pendingDecision: noReserve ? null : replacementDecision,
    clearPendingDecision: noReserve,
    logEntry: 'hero-died:${newlyDead.map((hero) => hero.id).join(',')}',
  );
}

List<CardId> _restlessGear(
  PlayerState deceased,
  Map<CardId, CardDefinition> definitions,
) => [
  for (final cardId in [
    ...deceased.backpack,
    ...deceased.equipped.weapons,
    deceased.equipped.armor,
    deceased.equipped.clothing,
    deceased.equipped.robot,
    ...deceased.carriedMods,
    ...deceased.implanted,
  ])
    if (cardId != null && definitions[cardId]?.type != ItemType.supply) cardId,
];

({int strength, int defense}) _restlessBonuses(
  PlayerState deceased,
  Map<CardId, CardDefinition> definitions,
) {
  var strength = 0;
  var defense = 0;
  for (final cardId in InventoryRules.activeCardIds(deceased)) {
    final effects = definitions[cardId]?.staticEffects;
    if (effects == null) continue;
    strength += effects[CardStat.strength].clamp(0, 999);
    defense += effects[CardStat.defense].clamp(0, 999);
  }
  return (strength: strength, defense: defense);
}

String _nextRestlessInstanceId(
  GameState state,
  PlayerId playerId,
  Iterable<MonsterInstance> monsters,
) {
  final prefix = 'restless-${state.round}-$playerId';
  var suffix = 1;
  var id = '$prefix-$suffix';
  while (monsters.any((monster) => monster.instanceId == id)) {
    id = '$prefix-${++suffix}';
  }
  return id;
}

GameStepResult _startPlayerSkillCheck(
  GameState state,
  StatType stat,
  DiceRoller dice,
) {
  final player = _activePlayer(state)!;
  final tile = state.tileAt(player.coord);
  final completesQuest =
      stat == StatType.science &&
      tile?.locationId == 'crew-mess' &&
      state.quests.storyQuestIds.contains('chapter-1-awakening') &&
      state.quests.statusOf('chapter-1-awakening') == QuestStatus.active;
  return _startRoll(
    state,
    dice,
    'skill-check:${player.id}:${stat.name}',
    diceCount: _statDice(player, state, stat),
    context: SkillCheckContext(
      playerId: player.id,
      stat: stat,
      questId: completesQuest ? 'chapter-1-awakening' : null,
    ),
  );
}

String _attackLog(
  PlayerState player,
  MonsterInstance monster,
  int damage,
  bool defeated,
) =>
    'attack:${player.id}:${monster.instanceId}:$damage'
    '${defeated ? ':defeated' : ''}';

int _heroAttackDice(PlayerState player, GameState state) =>
    _statDice(player, state, StatType.strength) + player.weaponModifier;

List<EffectHook> _activeEffectHooks(GameState state, PlayerState player) {
  final registry = EffectRegistry.standard();
  return [
    for (final cardId in _activeCardIds(player))
      for (final behaviorId
          in state.cardDefinitions[cardId]?.behaviorIds ?? const <String>[])
        if (registry[behaviorId] case final EffectHook hook) hook,
  ];
}

int _statDice(PlayerState player, GameState state, StatType stat) {
  final modifier = player.conditions.fold<int>(
    0,
    (total, conditionId) =>
        total + (state.conditionCards[conditionId]?.statModifiers[stat] ?? 0),
  );
  return (player.stats.valueFor(stat) +
          modifier +
          _cardStatModifier(
            state,
            player,
            stat,
          ))
      .clamp(1, 999);
}

int _cardStatModifier(GameState state, PlayerState player, StatType stat) {
  final cardStat = switch (stat) {
    StatType.strength || StatType.combatStrength => CardStat.strength,
    StatType.science => CardStat.science,
    StatType.repair => CardStat.repair,
    StatType.endurance => CardStat.endurance,
    StatType.agility => CardStat.agility,
  };
  return _activeCardIds(player).fold(
    0,
    (sum, id) =>
        sum + (state.cardDefinitions[id]?.staticEffects[cardStat] ?? 0),
  );
}

Iterable<String> _activeCardIds(PlayerState player) sync* {
  yield* InventoryRules.activeCardIds(player);
}

GameState _heal(GameState state, int amount) {
  final player = _activePlayer(state)!;
  final conditionDeck = state.decks['conditions'];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  if (conditionDeck != null && player.conditions.isNotEmpty) {
    decks['conditions'] = DeckState(
      drawPile: conditionDeck.drawPile,
      discardPile: [...conditionDeck.discardPile, ...player.conditions],
    );
  }
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: _replaceActivePlayer(
      state,
      (current) => _copyPlayer(
        current,
        damage: (current.damage - amount).clamp(0, current.damage),
        conditions: const [],
      ),
    ),
    decks: decks,
    logEntry: 'heal:${player.id}:$amount',
  );
}

List<HexTile> _openTile(List<HexTile> board, HexTile destination) => [
  for (final tile in board)
    if (tile.coord == destination.coord)
      _copyTile(tile, opened: true)
    else
      tile,
];

HexTile _copyTile(HexTile tile, {bool? opened, bool? isBlocked}) => HexTile(
  id: tile.id,
  coord: tile.coord,
  type: tile.type,
  opened: opened ?? tile.opened,
  exits: tile.exits,
  locationId: tile.locationId,
  hasTerminal: tile.hasTerminal,
  ventColor: tile.ventColor,
  isBlocked: isBlocked ?? tile.isBlocked,
);

GameStepResult _startRoll(
  GameState state,
  DiceRoller dice,
  String logEntry, {
  int diceCount = 1,
  RollContext? context,
  bool consumesAction = true,
}) => GameStepResult(
  state: _copyState(
    state,
    actionsLeft: consumesAction ? state.actionsLeft - 1 : state.actionsLeft,
    pendingDecision: AwaitingRerollChoice(
      dice: dice.rollDice(diceCount),
      availableRerolls: 1,
      window: const DecisionWindow(remainingTicks: 1),
      context: context,
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
    AwaitingEventOption() => _resolveEventOption(state, pending, choice, dice),
    AwaitingTerminalPick() => _resolveTerminalPick(state, pending, choice),
    AwaitingHeroReplacement() => _resolveHeroReplacement(
      state,
      pending,
      choice,
    ),
    AwaitingOtherPlayerDecision() => GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    ),
  };
}

GameStepResult _resolveHeroReplacement(
  GameState state,
  AwaitingHeroReplacement pending,
  DecisionChoice choice,
) {
  if (choice is! SelectReplacementHeroChoice ||
      !pending.characterIds.contains(choice.characterId)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  ReserveHero? reserve;
  for (final candidate in state.reserveHeroes) {
    if (candidate.characterId == choice.characterId) {
      reserve = candidate;
      break;
    }
  }
  if (reserve == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final selectedReserve = reserve;
  final queued = Map<PlayerId, ReserveHero>.of(state.queuedReplacements)
    ..[pending.playerId] = selectedReserve;
  return GameStepResult(
    state: _copyState(
      state,
      reserveHeroes: state.reserveHeroes.where(
        (hero) => hero.characterId != selectedReserve.characterId,
      ),
      queuedReplacements: queued,
      clearPendingDecision: true,
      logEntry:
          'replacement-selected:'
          '${pending.playerId}:${selectedReserve.characterId}',
    ),
  );
}

GameStepResult _resolveTerminalPick(
  GameState state,
  AwaitingTerminalPick pending,
  DecisionChoice choice,
) {
  if (state.activePlayerId != pending.playerId) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  CardId? purchased;
  if (choice is TerminalPickChoice) {
    if (!pending.offeredCards.contains(choice.cardId)) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final definition = state.cardDefinitions[choice.cardId];
    final player = _activePlayer(state)!;
    if (definition == null || player.credits < definition.cost) {
      return GameStepResult(
        state: state,
        rejection: const InventoryCommandRejected(
          'The selected supply cannot be purchased.',
        ),
      );
    }
    try {
      InventoryRules.receive(player, choice.cardId, state.cardDefinitions);
    } on BackpackCapacityExceeded catch (error) {
      return GameStepResult(
        state: state,
        rejection: InventoryCommandRejected(
          'Backpack capacity ${error.capacity} would be exceeded.',
        ),
      );
    } on InventoryRuleViolation catch (error) {
      return GameStepResult(
        state: state,
        rejection: InventoryCommandRejected(error.message),
      );
    }
    purchased = choice.cardId;
  } else if (choice is! DeclineTerminalPickChoice) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }

  final returned = [
    for (final card in pending.offeredCards)
      if (card != purchased) card,
  ];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final deck = decks[pending.deckId];
  if (deck == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  decks[pending.deckId] = DeckRules.returnAndShuffle(
    deck,
    returned,
    seed: _deckSeed(state, pending.deckId),
  );
  final player = _activePlayer(state)!;
  final next = purchased == null
      ? state
      : _copyState(
          state,
          players: _replacePlayer(
            state,
            player.id,
            (current) => _copyPlayer(
              InventoryRules.receive(
                current,
                purchased!,
                state.cardDefinitions,
              ),
              credits: current.credits - state.cardDefinitions[purchased]!.cost,
            ),
          ),
        );
  return GameStepResult(
    state: _copyState(
      next,
      decks: decks,
      clearPendingDecision: true,
      logEntry: 'terminal-pick:${player.id}:${purchased ?? 'decline'}',
    ),
  );
}

GameStepResult _resolveReroll(
  GameState state,
  AwaitingRerollChoice pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is KeepRollChoice) {
    final resolved = _copyState(state, clearPendingDecision: true);
    return GameStepResult(state: _completeRoll(resolved, pending));
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
  if (indexes.length > pending.maxDicePerReroll) {
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
        maxDicePerReroll: pending.maxDicePerReroll,
        window: pending.window,
        context: pending.context,
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
  final targetId = pending.targetPlayerId ?? state.activePlayerId;
  final damaged = remainingDamage > 0;
  final withDamage = resolveHeroDeaths(
    _copyState(
      state,
      players: _replacePlayer(
        state,
        targetId,
        (player) =>
            _copyPlayer(player, damage: player.damage + remainingDamage),
      ),
      clearPendingDecision: true,
    ),
  );
  final targetStillLives = _playerById(withDamage, targetId!)?.alive ?? false;
  final withCondition =
      damaged && targetStillLives && pending.source == DamageSource.monster
      ? _drawCondition(withDamage, targetId)
      : withDamage;
  return GameStepResult(
    state: _resumeAutomaticPhase(
      _startNextIncomingDamage(
        _copyState(
          withCondition,
          logEntry: 'dodge:$targetId:$remainingDamage',
        ),
      ),
    ),
  );
}

GameState _drawCondition(GameState state, PlayerId targetId) {
  final deck = state.decks['conditions'];
  if (deck == null) {
    return state;
  }
  final draw = DeckRules.draw(
    deck,
    seed: _deckSeed(state, 'conditions'),
  );
  if (draw.cards.isEmpty) return state;
  final condition = draw.cards.single;
  final decks = Map<DeckId, DeckState>.of(state.decks);
  // A condition remains attached to its hero until healing discards it.
  decks['conditions'] = draw.deck;
  return _copyState(
    state,
    players: _replacePlayer(
      state,
      targetId,
      (player) =>
          _copyPlayer(player, conditions: [...player.conditions, condition]),
    ),
    decks: decks,
    logEntry: 'condition:$targetId:$condition',
  );
}

GameState _startNextIncomingDamage(GameState state) {
  if (state.pendingDecision != null || state.pendingDamage.isEmpty) {
    return state;
  }
  final pending = state.pendingDamage
      .where(
        (damage) => _playerById(state, damage.targetPlayerId)?.alive ?? false,
      )
      .toList();
  if (pending.isEmpty) {
    return _copyState(state, pendingDamage: const []);
  }
  final next = pending.first;
  return _copyState(
    state,
    pendingDecision: AwaitingDodge(
      monsterDamage: next.amount,
      requiredAgilitySuccesses: next.agilityDice,
      targetPlayerId: next.targetPlayerId,
      source: next.source,
    ),
    pendingDamage: pending.skip(1),
  );
}

GameStepResult _resolveEventOption(
  GameState state,
  AwaitingEventOption pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is! EventOptionChoice ||
      !pending.options.contains(choice.option)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final playerId = pending.playerId ?? state.activePlayerId;
  if (playerId == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final selected = _copyState(
    state,
    clearPendingDecision: true,
    activePlayerId: playerId,
    logEntry: 'event-option:$playerId:${choice.option}',
  );
  if (pending.eventId == null) {
    return GameStepResult(state: _resumeAutomaticPhase(selected));
  }
  return _startRoll(
    selected,
    dice,
    'event-skill:$playerId:${pending.eventId ?? 'generic'}',
    diceCount: _statDice(
      _playerById(selected, playerId)!,
      selected,
      StatType.agility,
    ),
    context: SkillCheckContext(
      playerId: playerId,
      stat: StatType.agility,
      eventId: pending.eventId,
    ),
    consumesAction: false,
  );
}

GameState _completeRoll(
  GameState state,
  AwaitingRerollChoice pending,
) {
  final context = pending.context;
  if (context == null) return _resumeAutomaticPhase(state);
  if (context case AttackRollContext()) {
    return _resolveAttackRoll(
      state,
      context.playerId,
      context.targetInstanceId,
      pending.dice,
      consumesAction: false,
      preAttackDamage: context.preAttackDamage,
    );
  }
  if (context is! SkillCheckContext) return _resumeAutomaticPhase(state);
  final succeeded = countHits(pending.dice) >= context.difficulty;
  if (context.questId != null && succeeded) {
    return _completeMvpQuest(state, context);
  }
  if (context.eventId == 'cabin-noise') {
    return _resolveCabinNoise(state, context, succeeded);
  }
  return _resumeAutomaticPhase(state);
}

GameState _resolveCabinNoise(
  GameState state,
  SkillCheckContext context,
  bool succeeded,
) {
  if (succeeded) {
    final player = _playerById(state, context.playerId)!;
    final withSupply = player.backpack.length < 3
        ? _copyState(
            state,
            players: _replacePlayer(
              state,
              player.id,
              (current) => _copyPlayer(
                current,
                backpack: [...current.backpack, 'event-supply'],
              ),
            ),
            logEntry: 'event-success:cabin-noise:${player.id}:supply',
          )
        : _copyState(
            state,
            players: _replacePlayer(
              state,
              player.id,
              (current) => _copyPlayer(
                current,
                credits: current.credits + 1,
              ),
            ),
            logEntry: 'event-success:cabin-noise:${player.id}:credit',
          );
    return _resumeAutomaticPhase(withSupply);
  }
  final player = _playerById(state, context.playerId)!;
  return spawnMonster(
    _copyState(state, logEntry: 'event-failure:cabin-noise:${player.id}'),
    MonsterInstance(
      instanceId: 'ghoul-event-${state.round}-${player.id}',
      monsterId: 'ghoul',
      coord: player.coord,
      damage: 0,
      health: 2,
      attack: 2,
    ),
  );
}

GameState _completeMvpQuest(GameState state, SkillCheckContext context) {
  final statuses = Map<QuestId, QuestStatus>.of(state.quests.statuses)
    ..[context.questId!] = QuestStatus.completed;
  final quests = QuestState(
    storyQuestIds: state.quests.storyQuestIds,
    personalTasksByPlayer: state.quests.personalTasksByPlayer,
    statuses: statuses,
  );
  return _copyState(
    state,
    quests: quests,
    isComplete: true,
    actionsLeft: 0,
    gameEvents: [
      ...state.gameEvents,
      MvpDemonstrationCompleted(
        questId: context.questId!,
        playerId: context.playerId,
      ),
    ],
    logEntry: 'quest-completed:${context.questId}:${context.playerId}',
  );
}

GameState _endTurn(GameState state) {
  final activeIndex = state.players.indexWhere(
    (player) => player.id == state.activePlayerId,
  );
  final nextIndex = _nextLivingPlayerIndex(state.players, activeIndex);
  if (nextIndex == null) {
    if (state.queuedReplacements.isNotEmpty) {
      return _startNextPlayersTurn(
        _copyState(state, actionsLeft: 0, clearActivePlayerId: true),
      );
    }
    return _copyState(state, actionsLeft: 0, clearActivePlayerId: true);
  }
  final lastPlayerOfRound = activeIndex >= 0 && nextIndex <= activeIndex;
  if (lastPlayerOfRound) {
    return _runMonstersTurn(
      _copyState(
        state,
        phase: GamePhase.monstersTurn,
        actionsLeft: 0,
        clearActivePlayerId: true,
        monsterTurnIndex: 0,
        monsterStepsRemaining: 0,
        logEntry: 'players-turn-complete:${state.round}',
      ),
    );
  }
  return _copyState(
    state,
    activePlayerId: state.players[nextIndex].id,
    actionsLeft: 2,
    actionsTakenThisTurn: 0,
    logEntry: 'end-turn:${state.activePlayerId}',
  );
}

/// Returns living heroes sorted by a monster's deterministic target priority.
///
/// The path calculation traverses only opened tiles with mutually matching
/// exits.  Equal distances are then broken by current HP and saved player
/// order, which is the turn order of the round.
List<PlayerState> nearestTargets(GameState state, MonsterInstance monster) {
  final distances = _openPathDistances(state, monster.coord);
  final targets =
      state.players
          .where(
            (player) => player.alive && distances.containsKey(player.coord),
          )
          .toList()
        ..sort((left, right) {
          final distanceOrder = distances[left.coord]!.compareTo(
            distances[right.coord]!,
          );
          if (distanceOrder != 0) return distanceOrder;
          final leftHp = _currentHp(left);
          final rightHp = _currentHp(right);
          final hpOrder = leftHp.compareTo(rightHp);
          if (hpOrder != 0) return hpOrder;
          return state.players
              .indexOf(left)
              .compareTo(state.players.indexOf(right));
        });
  return List.unmodifiable(targets);
}

int _currentHp(PlayerState player) => player.health - player.damage;

Map<HexCoord, int> _openPathDistances(GameState state, HexCoord start) {
  final startTile = state.tileAt(start);
  if (startTile == null || !startTile.opened) return const {};
  final distances = <HexCoord, int>{start: 0};
  final queue = <HexCoord>[start];
  for (var index = 0; index < queue.length; index++) {
    final current = queue[index];
    final currentTile = state.tileAt(current)!;
    for (final edge in currentTile.exits) {
      final next = current.neighbor(edge);
      final nextTile = state.tileAt(next);
      if (nextTile == null ||
          !nextTile.opened ||
          !nextTile.hasExit(edge.opposite) ||
          distances.containsKey(next)) {
        continue;
      }
      distances[next] = distances[current]! + 1;
      queue.add(next);
    }
  }
  return distances;
}

HexCoord? _nextPathStep(GameState state, HexCoord start, HexCoord target) {
  final distancesToTarget = _openPathDistances(state, target);
  final startDistance = distancesToTarget[start];
  if (startDistance == null || startDistance == 0) return null;
  final tile = state.tileAt(start)!;
  for (final edge in HexEdge.values) {
    if (!tile.hasExit(edge)) continue;
    final next = start.neighbor(edge);
    final nextTile = state.tileAt(next);
    if (nextTile != null &&
        nextTile.opened &&
        nextTile.hasExit(edge.opposite) &&
        distancesToTarget[next] == startDistance - 1) {
      return next;
    }
  }
  return null;
}

GameState _runMonstersTurn(GameState state) {
  var current = state;
  while (current.pendingDecision == null) {
    if (current.monsterTurnIndex >= current.monsters.length) {
      return _startEventsPhase(current);
    }
    final monster = current.monsters[current.monsterTurnIndex];
    if (current.monsterStepsRemaining == 0) {
      current = _copyState(
        current,
        monsterStepsRemaining: monster.movement,
      );
      if (monster.movement == 0) {
        current = _copyState(
          current,
          monsterTurnIndex: current.monsterTurnIndex + 1,
        );
        continue;
      }
    }
    final targets = nearestTargets(current, monster);
    final stepTarget = targets.isEmpty
        ? null
        : _nextPathStep(current, monster.coord, targets.first.coord);
    if (stepTarget == null) {
      current = _copyState(
        current,
        monsterTurnIndex: current.monsterTurnIndex + 1,
        monsterStepsRemaining: 0,
      );
      continue;
    }
    current = _copyState(
      current,
      monsterStepsRemaining: current.monsterStepsRemaining - 1,
    );
    current = moveMonsterOneStep(current, monster.instanceId, stepTarget);
    if (current.pendingDecision != null) return current;
    if (current.monsterStepsRemaining == 0) {
      current = _copyState(
        current,
        monsterTurnIndex: current.monsterTurnIndex + 1,
      );
    }
  }
  return current;
}

GameState _startEventsPhase(GameState state) => _advanceEvents(
  _copyState(
    state,
    phase: GamePhase.eventsPhase,
    eventTurnIndex: 0,
    actionsLeft: 0,
    clearActivePlayerId: true,
    logEntry: 'monsters-turn-complete:${state.round}',
  ),
);

GameState _advanceEvents(GameState state) {
  var current = state;
  while (current.pendingDecision == null) {
    if (current.eventTurnIndex >= current.players.length) {
      return _startNextPlayersTurn(current);
    }
    final player = current.players[current.eventTurnIndex];
    current = _copyState(current, eventTurnIndex: current.eventTurnIndex + 1);
    if (!player.alive || _hasAggressiveMonster(current, player)) continue;
    final eventDeck = current.decks['events'];
    if (eventDeck == null) continue;
    final draw = DeckRules.draw(
      eventDeck,
      seed: _deckSeed(current, 'events'),
    );
    if (draw.cards.isEmpty) continue;
    final eventId = draw.cards.single;
    final decks = Map<DeckId, DeckState>.of(current.decks);
    decks['events'] = DeckState(
      drawPile: draw.deck.drawPile,
      discardPile: [...draw.deck.discardPile, eventId],
    );
    return _copyState(
      current,
      activePlayerId: player.id,
      decks: decks,
      pendingDecision: AwaitingEventOption(
        options: const ['investigate'],
        playerId: player.id,
        eventId: eventId,
      ),
      logEntry: 'event:$eventId:${player.id}',
    );
  }
  return current;
}

bool _hasAggressiveMonster(GameState state, PlayerState player) => state
    .monsters
    .any((monster) => monster.attack > 0 && monster.coord == player.coord);

GameState _startNextPlayersTurn(GameState state) {
  final withReplacements = _activateQueuedReplacements(state);
  PlayerState? first;
  for (final player in withReplacements.players) {
    if (player.alive) {
      first = player;
      break;
    }
  }
  if (first == null) {
    return _copyState(
      withReplacements,
      actionsLeft: 0,
      clearActivePlayerId: true,
      isComplete: true,
    );
  }
  return _copyState(
    withReplacements,
    round: withReplacements.round + 1,
    phase: GamePhase.playersTurn,
    activePlayerId: first.id,
    actionsLeft: 2,
    actionsTakenThisTurn: 0,
    eventTurnIndex: 0,
    logEntry: 'round-start:${withReplacements.round + 1}',
  );
}

GameState _activateQueuedReplacements(GameState state) {
  if (state.queuedReplacements.isEmpty) return state;
  HexCoord? anabiosis;
  for (final tile in state.board) {
    if (tile.type == HexTileType.start) {
      anabiosis = tile.coord;
      break;
    }
  }
  if (anabiosis == null) {
    throw StateError('A replacement hero requires an anabiosis start sector.');
  }
  return _copyState(
    state,
    players: [
      for (final player in state.players)
        if (state.queuedReplacements[player.id] case final replacement?)
          PlayerState(
            id: player.id,
            characterId: replacement.characterId,
            coord: anabiosis,
            damage: 0,
            health: replacement.health,
            credits: replacement.credits,
            backpack: replacement.backpack,
            equipped: replacement.equipped,
            carriedMods: replacement.carriedMods,
            implanted: replacement.implanted,
            conditions: const [],
            alive: true,
            stats: replacement.stats,
          )
        else
          player,
    ],
    queuedReplacements: const {},
    logEntry: 'replacement-arrived',
  );
}

GameState _resumeAutomaticPhase(GameState state) {
  if (state.pendingDecision != null || state.isComplete) return state;
  return switch (state.phase) {
    GamePhase.monstersTurn => _runMonstersTurn(state),
    GamePhase.eventsPhase => _advanceEvents(state),
    GamePhase.playersTurn => state,
  };
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

PlayerState? _playerById(GameState state, PlayerId playerId) {
  for (final player in state.players) {
    if (player.id == playerId) return player;
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

List<PlayerState> _replacePlayer(
  GameState state,
  PlayerId? playerId,
  PlayerState Function(PlayerState player) replace,
) => [
  for (final player in state.players)
    if (player.id == playerId) replace(player) else player,
];

PlayerState _copyPlayer(
  PlayerState player, {
  HexCoord? coord,
  int? damage,
  int? credits,
  Iterable<CardId>? backpack,
  EquippedGear? equipped,
  Iterable<CardId>? carriedMods,
  Iterable<CardId>? implanted,
  Iterable<CardId>? conditions,
  bool? alive,
  PlayerStats? stats,
  int? health,
  int? weaponModifier,
}) => PlayerState(
  id: player.id,
  characterId: player.characterId,
  coord: coord ?? player.coord,
  damage: damage ?? player.damage,
  health: health ?? player.health,
  credits: credits ?? player.credits,
  backpack: backpack ?? player.backpack,
  equipped: equipped ?? player.equipped,
  carriedMods: carriedMods ?? player.carriedMods,
  implanted: implanted ?? player.implanted,
  conditions: conditions ?? player.conditions,
  alive: alive ?? player.alive,
  stats: stats ?? player.stats,
  weaponModifier: weaponModifier ?? player.weaponModifier,
);

MonsterInstance _copyMonster(
  MonsterInstance monster, {
  HexCoord? coord,
  int? damage,
}) => MonsterInstance(
  instanceId: monster.instanceId,
  monsterId: monster.monsterId,
  coord: coord ?? monster.coord,
  damage: damage ?? monster.damage,
  health: monster.health,
  defense: monster.defense,
  attack: monster.attack,
  movement: monster.movement,
  carriedGear: monster.carriedGear,
);

GameState _copyState(
  GameState state, {
  int? round,
  GamePhase? phase,
  PlayerId? activePlayerId,
  bool clearActivePlayerId = false,
  int? actionsLeft,
  Iterable<HexTile>? board,
  Iterable<PlayerState>? players,
  Iterable<MonsterInstance>? monsters,
  Iterable<BoilToken>? boils,
  Iterable<ReserveHero>? reserveHeroes,
  Map<PlayerId, ReserveHero>? queuedReplacements,
  Iterable<CardId>? chestCards,
  Map<DeckId, DeckState>? decks,
  QuestState? quests,
  Iterable<IncomingDamage>? pendingDamage,
  Iterable<GameEvent>? gameEvents,
  bool? isComplete,
  int? monsterTurnIndex,
  int? monsterStepsRemaining,
  int? eventTurnIndex,
  int? actionsTakenThisTurn,
  PendingDecision? pendingDecision,
  bool clearPendingDecision = false,
  String? logEntry,
}) => GameState(
  schemaVersion: state.schemaVersion,
  seed: state.seed,
  round: round ?? state.round,
  phase: phase ?? state.phase,
  activePlayerId: clearActivePlayerId
      ? null
      : activePlayerId ?? state.activePlayerId,
  actionsLeft: actionsLeft ?? state.actionsLeft,
  board: board ?? state.board,
  players: players ?? state.players,
  monsters: monsters ?? state.monsters,
  boils: boils ?? state.boils,
  reserveHeroes: reserveHeroes ?? state.reserveHeroes,
  queuedReplacements: queuedReplacements ?? state.queuedReplacements,
  chestCards: chestCards ?? state.chestCards,
  conditionCards: state.conditionCards,
  cardDefinitions: state.cardDefinitions,
  pendingDamage: pendingDamage ?? state.pendingDamage,
  decks: decks ?? state.decks,
  quests: quests ?? state.quests,
  log: [...state.log, if (logEntry != null) logEntry],
  gameEvents: gameEvents ?? state.gameEvents,
  isComplete: isComplete ?? state.isComplete,
  monsterTurnIndex: monsterTurnIndex ?? state.monsterTurnIndex,
  monsterStepsRemaining: monsterStepsRemaining ?? state.monsterStepsRemaining,
  eventTurnIndex: eventTurnIndex ?? state.eventTurnIndex,
  actionsTakenThisTurn: actionsTakenThisTurn ?? state.actionsTakenThisTurn,
  pendingDecision: clearPendingDecision
      ? null
      : pendingDecision ?? state.pendingDecision,
);
