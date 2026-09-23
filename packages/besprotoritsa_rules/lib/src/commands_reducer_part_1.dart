// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

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

/// A command carried invalid numeric input that must never rely on assertions.
final class InvalidCommandArguments extends CommandRejection {
  const InvalidCommandArguments();
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
