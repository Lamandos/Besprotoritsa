// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'game_state.dart';

sealed class PendingDecision {
  const PendingDecision();
}

sealed class RollContext {
  const RollContext();
}

/// A roll which may still be kept or rerolled by the active player.
@immutable
final class AwaitingRerollChoice extends PendingDecision {
  AwaitingRerollChoice({
    required Iterable<int> dice,
    required this.availableRerolls,
    required this.window,
    this.context,
    this.maxDicePerReroll = 999,
  }) : dice = List.unmodifiable(dice) {
    _requireNonNegative(availableRerolls, 'availableRerolls');
    if (maxDicePerReroll < 1) {
      throw ArgumentError.value(
        maxDicePerReroll,
        'maxDicePerReroll',
        'Must be at least one.',
      );
    }
    for (final die in this.dice) {
      if (die < 1 || die > 6) {
        throw ArgumentError.value(die, 'dice', 'Dice values must be in 1..6.');
      }
    }
  }

  final List<int> dice;
  final int availableRerolls;
  final DecisionWindow window;
  final RollContext? context;
  final int maxDicePerReroll;

  /// Alias retained for UI code which calls these values rolls.
  List<int> get rolls => dice;
}

/// What should happen after a skill check is accepted by its player.
@immutable
final class SkillCheckContext extends RollContext {
  const SkillCheckContext({
    required this.playerId,
    required this.stat,
    this.difficulty = 1,
    this.eventId,
    this.questId,
  }) : assert(difficulty >= 1, 'difficulty must be positive.'),
       super();

  final PlayerId playerId;
  final StatType stat;
  final int difficulty;
  final CardId? eventId;
  final QuestId? questId;
}

/// Deferred attack resolution, retained while a weapon grants rerolls.
@immutable
final class AttackRollContext extends RollContext {
  const AttackRollContext({
    required this.playerId,
    required this.targetInstanceId,
    this.preAttackDamage = 0,
  }) : super();

  final PlayerId playerId;
  final String targetInstanceId;
  final int preAttackDamage;
}

/// A pending attempt to prevent incoming monster damage with agility hits.
@immutable
final class AwaitingDodge extends PendingDecision {
  const AwaitingDodge({
    required this.monsterDamage,
    required this.requiredAgilitySuccesses,
    this.targetPlayerId,
    this.source = DamageSource.monster,
  }) : assert(monsterDamage >= 0, 'monsterDamage must not be negative.'),
       assert(
         requiredAgilitySuccesses >= 0,
         'requiredAgilitySuccesses must not be negative.',
       );

  final int monsterDamage;
  final int requiredAgilitySuccesses;
  final PlayerId? targetPlayerId;
  final DamageSource source;

  /// Short name convenient for generic decision views.
  int get requiredSuccesses => requiredAgilitySuccesses;
}

/// A pending choice between event branches, normally the A and B options.
@immutable
final class AwaitingEventOption extends PendingDecision {
  AwaitingEventOption({
    required Iterable<String> options,
    this.playerId,
    this.eventId,
  }) : options = List.unmodifiable(options) {
    if (this.options.isEmpty) {
      throw ArgumentError.value(
        options,
        'options',
        'At least one option is required.',
      );
    }
  }

  final List<String> options;
  final PlayerId? playerId;
  final CardId? eventId;
}

/// A terminal has revealed supply cards and awaits either one purchase or a
/// decline. The cards are temporarily out of the deck until this is resolved.
@immutable
final class AwaitingTerminalPick extends PendingDecision {
  AwaitingTerminalPick({
    required Iterable<CardId> offeredCards,
    required this.playerId,
    this.deckId = 'supplies',
  }) : offeredCards = List.unmodifiable(offeredCards) {
    if (this.offeredCards.isEmpty) {
      throw ArgumentError.value(
        offeredCards,
        'offeredCards',
        'A terminal must offer at least one card.',
      );
    }
  }

  final List<CardId> offeredCards;
  final PlayerId playerId;
  final DeckId deckId;

  /// Alias used by generic decision views.
  List<CardId> get cards => offeredCards;
}

/// The owner of a fallen hero must choose one unused reserve character.
@immutable
final class AwaitingHeroReplacement extends PendingDecision {
  AwaitingHeroReplacement({
    required this.playerId,
    required Iterable<CharacterId> characterIds,
  }) : characterIds = List.unmodifiable(characterIds) {
    _requireId(playerId, 'playerId');
    if (this.characterIds.isEmpty) {
      throw ArgumentError.value(
        characterIds,
        'characterIds',
        'At least one reserve character is required.',
      );
    }
  }

  final PlayerId playerId;
  final List<CharacterId> characterIds;
}

/// A privacy-preserving projection that another hero must make a decision.
///
/// This is used only by clients that are not entitled to receive the decision
/// details. It still blocks local commands while the authoritative room waits.
@immutable
final class AwaitingOtherPlayerDecision extends PendingDecision {
  const AwaitingOtherPlayerDecision({required this.awaitingPlayerId});

  final PlayerId awaitingPlayerId;
}

/// The authoritative, complete game state. Collections are copied on input.
