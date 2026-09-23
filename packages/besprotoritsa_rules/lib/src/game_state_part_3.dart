// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'game_state.dart';

@immutable
final class QuestState {
  QuestState({
    Iterable<QuestId> storyQuestIds = const [],
    Map<PlayerId, Iterable<QuestId>> personalTasksByPlayer = const {},
    Map<QuestId, QuestStatus> statuses = const {},
  }) : storyQuestIds = List.unmodifiable(storyQuestIds),
       personalTasksByPlayer = UnmodifiableMapView({
         for (final entry in personalTasksByPlayer.entries)
           entry.key: List<QuestId>.unmodifiable(entry.value),
       }),
       statuses = UnmodifiableMapView(Map.of(statuses));

  final List<QuestId> storyQuestIds;
  final Map<PlayerId, List<QuestId>> personalTasksByPlayer;
  final Map<QuestId, QuestStatus> statuses;

  /// Story quests start active unless an explicit status was recorded.
  QuestStatus statusOf(QuestId questId) =>
      statuses[questId] ?? QuestStatus.active;
}

enum QuestStatus { active, completed }

/// The three deterministic parts of one round.
enum GamePhase {
  playersTurn,
  monstersTurn,
  eventsPhase;

  /// Compatibility aliases for states written before the round loop existed.
  static const GamePhase players = playersTurn;
  static const GamePhase monsters = monstersTurn;
  static const GamePhase events = eventsPhase;
}

/// A durable fact emitted by the rules engine, suitable for an animation queue.
sealed class GameEvent {
  const GameEvent();
}

/// A hero entered a new hex during a command transition.
@immutable
final class HexEntered extends GameEvent {
  const HexEntered({
    required this.playerId,
    required this.from,
    required this.to,
  });

  final PlayerId playerId;
  final HexCoord from;
  final HexCoord to;
}

/// A hero shares a hex with a threat and its consequences are being resolved.
@immutable
final class ColocationTriggered extends GameEvent {
  const ColocationTriggered({required this.playerId, required this.coord});

  final PlayerId playerId;
  final HexCoord coord;
}

/// Damage was applied to a hero after a combat or hazard resolution.
@immutable
final class DamageDealt extends GameEvent {
  const DamageDealt({required this.playerId, required this.amount});

  final PlayerId playerId;
  final int amount;
}

/// A condition card was drawn and attached to a hero.
@immutable
final class ConditionDrawn extends GameEvent {
  const ConditionDrawn({required this.playerId, required this.conditionId});

  final PlayerId playerId;
  final CardId conditionId;
}

/// The terminal event of the demonstration scenario.
@immutable
final class MvpDemonstrationCompleted extends GameEvent {
  const MvpDemonstrationCompleted({
    required this.questId,
    required this.playerId,
  });

  final QuestId questId;
  final PlayerId playerId;
}

/// A hero died and became a Restless monster in their former sector.
@immutable
final class HeroDied extends GameEvent {
  const HeroDied({
    required this.playerId,
    required this.restlessInstanceId,
    required this.coord,
  });

  final PlayerId playerId;
  final String restlessInstanceId;
  final HexCoord coord;
}

/// A deterministic window in which the active player may make a micro-decision.
///
/// The reducer advances this counter rather than consulting wall-clock time, so
/// the state remains reproducible in tests, replays, and networked games.
@immutable
final class DecisionWindow {
  const DecisionWindow({required this.remainingTicks})
    : assert(remainingTicks >= 0, 'remainingTicks must not be negative.');

  final int remainingTicks;
}

/// Base type for a game state waiting for a player response.
