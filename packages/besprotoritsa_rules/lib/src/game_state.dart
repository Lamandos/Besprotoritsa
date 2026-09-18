// This state model intentionally groups related public fields without
// per-field prose; the type documentation describes the field groups.
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: public_member_api_docs

import 'dart:collection';

import 'package:besprotoritsa_rules/src/combat_models.dart';
import 'package:meta/meta.dart';

/// Stable identifiers used by the game-state model.
typedef PlayerId = String;
typedef CharacterId = String;
typedef CardId = String;
typedef QuestId = String;
typedef DeckId = String;
typedef LocationId = String;

/// One of the six directed sides of an axial hex.
enum HexEdge {
  north(0, -1),
  northEast(1, -1),
  southEast(1, 0),
  south(0, 1),
  southWest(-1, 1),
  northWest(-1, 0);

  const HexEdge(this.deltaQ, this.deltaR);

  final int deltaQ;
  final int deltaR;

  /// Returns an edge from its persisted value (0 through 5).
  static HexEdge fromIndex(int index) {
    if (index < 0 || index >= values.length) {
      throw ArgumentError.value(index, 'index', 'Hex edge must be in 0..5.');
    }
    return values[index];
  }

  /// The side facing this edge on a neighbouring hex.
  HexEdge get opposite => values[(index + 3) % values.length];
}

/// An immutable axial coordinate.
@immutable
final class HexCoord {
  const HexCoord(this.q, this.r);

  final int q;
  final int r;

  /// The coordinate one step through [edge].
  HexCoord neighbor(HexEdge edge) => HexCoord(q + edge.deltaQ, r + edge.deltaR);

  /// All six adjacent coordinates, in [HexEdge] order.
  Iterable<HexCoord> get neighbors => HexEdge.values.map(neighbor);

  /// The axial/cube distance to [other].
  int distanceTo(HexCoord other) {
    final deltaQ = q - other.q;
    final deltaR = r - other.r;
    return (deltaQ.abs() + deltaR.abs() + (deltaQ + deltaR).abs()) ~/ 2;
  }

  /// Returns the edge leading to [other], or null when it is not adjacent.
  HexEdge? edgeTowardOrNull(HexCoord other) {
    for (final edge in HexEdge.values) {
      if (neighbor(edge) == other) {
        return edge;
      }
    }
    return null;
  }

  /// Returns the edge leading to an adjacent [other].
  ///
  /// A coordinate is not a direction. Passing this coordinate itself or a
  /// non-neighbour is rejected instead of silently choosing an arbitrary edge.
  HexEdge edgeToward(HexCoord other) {
    final edge = edgeTowardOrNull(other);
    if (edge == null) {
      throw ArgumentError.value(other, 'other', 'Target must be adjacent.');
    }
    return edge;
  }

  @override
  bool operator ==(Object other) =>
      other is HexCoord && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => 'HexCoord($q, $r)';
}

enum HexTileType { start, compartment, corridor, airlock }

enum VentColor { none, green, red }

/// An immutable tile laid on the board.
@immutable
final class HexTile {
  HexTile({
    required this.id,
    required this.coord,
    required this.type,
    required this.opened,
    required Iterable<HexEdge> exits,
    this.locationId,
    required this.hasTerminal,
    required this.ventColor,
  }) : exits = Set.unmodifiable(exits) {
    _requireId(id, 'id');
    if (locationId != null) {
      _requireId(locationId!, 'locationId');
    }
  }

  final String id;
  final HexCoord coord;
  final HexTileType type;
  final bool opened;
  final Set<HexEdge> exits;
  final LocationId? locationId;
  final bool hasTerminal;
  final VentColor ventColor;

  bool hasExit(HexEdge edge) => exits.contains(edge);
}

/// Gear occupying the four visible equipment slots of a player.
@immutable
final class EquippedGear {
  const EquippedGear({this.weapon, this.armor, this.clothing, this.robot});

  final CardId? weapon;
  final CardId? armor;
  final CardId? clothing;
  final CardId? robot;
}

/// An inert threat token which explodes when a player shares its cell.
@immutable
final class BoilToken {
  const BoilToken({required this.instanceId, required this.coord})
    : assert(instanceId != '', 'instanceId must not be empty');

  final String instanceId;
  final HexCoord coord;
}

/// The private and public state of one participant's character.
@immutable
final class PlayerState {
  PlayerState({
    required this.id,
    required this.characterId,
    required this.coord,
    required this.damage,
    this.health = 3,
    required this.credits,
    required Iterable<CardId> backpack,
    required this.equipped,
    required Iterable<CardId> carriedMods,
    required Iterable<CardId> implanted,
    required Iterable<CardId> conditions,
    required this.alive,
    this.stats = const PlayerStats(),
    this.weaponModifier = 0,
  }) : backpack = List.unmodifiable(backpack),
       carriedMods = List.unmodifiable(carriedMods),
       implanted = List.unmodifiable(implanted),
       conditions = List.unmodifiable(conditions) {
    _requireId(id, 'id');
    _requireId(characterId, 'characterId');
    _requireNonNegative(damage, 'damage');
    if (health < 1) {
      throw ArgumentError.value(health, 'health', 'Health must be positive.');
    }
    _requireNonNegative(credits, 'credits');
    _requireNonNegative(weaponModifier, 'weaponModifier');
    if (this.backpack.length > 3) {
      throw ArgumentError.value(
        backpack,
        'backpack',
        'Backpack holds at most 3 cards.',
      );
    }
    if (this.implanted.length > 2) {
      throw ArgumentError.value(
        implanted,
        'implanted',
        'At most 2 modifications may be implanted.',
      );
    }
  }

  final PlayerId id;
  final CharacterId characterId;
  final HexCoord coord;
  final int damage;

  /// Maximum health; current HP is [health] minus [damage].
  final int health;
  final int credits;
  final List<CardId> backpack;
  final EquippedGear equipped;
  final List<CardId> carriedMods;
  final List<CardId> implanted;
  final List<CardId> conditions;
  final bool alive;
  final PlayerStats stats;

  /// The equipped weapon's bonus to the hero attack pool.
  final int weaponModifier;
}

/// A monster token on the board. [carriedGear] is used by a Restless monster.
@immutable
final class MonsterInstance {
  MonsterInstance({
    required this.instanceId,
    required this.monsterId,
    required this.coord,
    required this.damage,
    this.health = 1,
    this.defense = 0,
    this.attack = 0,
    this.movement = 1,
    Iterable<CardId> carriedGear = const [],
  }) : carriedGear = List.unmodifiable(carriedGear) {
    _requireId(instanceId, 'instanceId');
    _requireId(monsterId, 'monsterId');
    _requireNonNegative(damage, 'damage');
    _requireNonNegative(health, 'health');
    _requireNonNegative(defense, 'defense');
    _requireNonNegative(attack, 'attack');
    _requireNonNegative(movement, 'movement');
  }

  final String instanceId;
  final String monsterId;
  final HexCoord coord;
  final int damage;
  final int health;
  final int defense;
  final int attack;

  /// Number of connected, opened sectors this monster traverses per round.
  final int movement;
  final List<CardId> carriedGear;
}

/// Full deck state. Its card order is deliberately available only in GameState.
@immutable
final class DeckState {
  DeckState({
    required Iterable<CardId> drawPile,
    Iterable<CardId> discardPile = const [],
  }) : drawPile = List.unmodifiable(drawPile),
       discardPile = List.unmodifiable(discardPile);

  final List<CardId> drawPile;
  final List<CardId> discardPile;

  int get cardsRemaining => drawPile.length;
}

/// Story quests and private personal tasks.
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
  static const players = playersTurn;
  static const monsters = monstersTurn;
  static const events = eventsPhase;
}

/// A durable fact emitted by the rules engine, suitable for an animation queue.
sealed class GameEvent {
  const GameEvent();
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
sealed class PendingDecision {
  const PendingDecision();
}

/// A roll which may still be kept or rerolled by the active player.
@immutable
final class AwaitingRerollChoice extends PendingDecision {
  AwaitingRerollChoice({
    required Iterable<int> dice,
    required this.availableRerolls,
    required this.window,
    this.context,
  }) : dice = List.unmodifiable(dice) {
    _requireNonNegative(availableRerolls, 'availableRerolls');
    for (final die in this.dice) {
      if (die < 1 || die > 6) {
        throw ArgumentError.value(die, 'dice', 'Dice values must be in 1..6.');
      }
    }
  }

  final List<int> dice;
  final int availableRerolls;
  final DecisionWindow window;
  final SkillCheckContext? context;

  /// Alias retained for UI code which calls these values rolls.
  List<int> get rolls => dice;
}

/// What should happen after a skill check is accepted by its player.
@immutable
final class SkillCheckContext {
  const SkillCheckContext({
    required this.playerId,
    required this.stat,
    this.difficulty = 1,
    this.eventId,
    this.questId,
  }) : assert(difficulty >= 1, 'difficulty must be positive.');

  final PlayerId playerId;
  final StatType stat;
  final int difficulty;
  final CardId? eventId;
  final QuestId? questId;
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

/// The authoritative, complete game state. Collections are copied on input.
@immutable
final class GameState {
  GameState({
    this.schemaVersion = 1,
    required this.seed,
    required this.round,
    required this.phase,
    required this.activePlayerId,
    required this.actionsLeft,
    required Iterable<HexTile> board,
    required Iterable<PlayerState> players,
    required Iterable<MonsterInstance> monsters,
    required Map<DeckId, DeckState> decks,
    required this.quests,
    Iterable<BoilToken> boils = const [],
    Map<CardId, ConditionCard> conditionCards = const {},
    Iterable<IncomingDamage> pendingDamage = const [],
    Iterable<String> log = const [],
    Iterable<GameEvent> gameEvents = const [],
    this.isComplete = false,
    this.monsterTurnIndex = 0,
    this.monsterStepsRemaining = 0,
    this.eventTurnIndex = 0,
    this.pendingDecision,
  }) : board = List.unmodifiable(board),
       players = List.unmodifiable(players),
       monsters = List.unmodifiable(monsters),
       boils = List.unmodifiable(boils),
       conditionCards = UnmodifiableMapView(Map.of(conditionCards)),
       pendingDamage = List.unmodifiable(pendingDamage),
       decks = UnmodifiableMapView(Map.of(decks)),
       log = List.unmodifiable(log),
       gameEvents = List.unmodifiable(gameEvents) {
    if (schemaVersion != 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Only schema version 1 is supported.',
      );
    }
    if (round < 1) {
      throw ArgumentError.value(round, 'round', 'Round must be at least 1.');
    }
    _requireNonNegative(actionsLeft, 'actionsLeft');
    _requireNonNegative(monsterTurnIndex, 'monsterTurnIndex');
    _requireNonNegative(monsterStepsRemaining, 'monsterStepsRemaining');
    _requireNonNegative(eventTurnIndex, 'eventTurnIndex');
    _ensureUnique(this.board.map((tile) => tile.coord), 'board coordinates');
    _ensureUnique(this.board.map((tile) => tile.id), 'tile ids');
    _ensureUnique(this.players.map((player) => player.id), 'player ids');
    _ensureUnique(
      this.monsters.map((monster) => monster.instanceId),
      'monster instance ids',
    );
    _ensureUnique(
      this.boils.map((boil) => boil.instanceId),
      'boil instance ids',
    );
    if (activePlayerId != null &&
        !this.players.any((player) => player.id == activePlayerId)) {
      throw ArgumentError.value(
        activePlayerId,
        'activePlayerId',
        'Active player must be in players.',
      );
    }
  }

  final int schemaVersion;
  final int seed;
  final int round;
  final GamePhase phase;
  final PlayerId? activePlayerId;
  final int actionsLeft;
  final List<HexTile> board;
  final List<PlayerState> players;
  final List<MonsterInstance> monsters;
  final List<BoilToken> boils;
  final Map<CardId, ConditionCard> conditionCards;
  final List<IncomingDamage> pendingDamage;
  final Map<DeckId, DeckState> decks;
  final QuestState quests;
  final List<String> log;
  final List<GameEvent> gameEvents;
  final bool isComplete;

  /// Internal deterministic cursors. They make automatic phases resumable
  /// after a dodge decision without relying on a process-local call stack.
  final int monsterTurnIndex;
  final int monsterStepsRemaining;
  final int eventTurnIndex;
  final PendingDecision? pendingDecision;

  HexTile? tileAt(HexCoord coord) {
    for (final tile in board) {
      if (tile.coord == coord) {
        return tile;
      }
    }
    return null;
  }
}

/// A board cell as seen by a particular player. A fogged cell contains no tile
/// metadata, exits, or location data.
@immutable
final class ProjectedHexTile {
  ProjectedHexTile._visible(HexTile visibleTile)
    : tile = visibleTile,
      coord = visibleTile.coord,
      isFogged = false;

  const ProjectedHexTile._fog(this.coord) : tile = null, isFogged = true;

  final HexCoord coord;
  final bool isFogged;
  final HexTile? tile;

  bool get isVisible => !isFogged;
}

/// A deck view which reveals quantity, but never its contents or order.
@immutable
final class DeckSummary {
  const DeckSummary(this.cardsRemaining);

  final int cardsRemaining;

  int get remainingCards => cardsRemaining;
}

/// A player view with another player's non-public cards removed.
@immutable
final class ProjectedPlayerState {
  ProjectedPlayerState._({
    required this.id,
    required this.characterId,
    required this.coord,
    required this.damage,
    required this.credits,
    required this.equipped,
    required this.alive,
    required this.isViewer,
    required Iterable<CardId> backpack,
    required Iterable<CardId> carriedMods,
    required Iterable<CardId> implanted,
    required Iterable<CardId> conditions,
    required this.hiddenCardCount,
  }) : backpack = List.unmodifiable(backpack),
       carriedMods = List.unmodifiable(carriedMods),
       implanted = List.unmodifiable(implanted),
       conditions = List.unmodifiable(conditions);

  factory ProjectedPlayerState.fromState(
    PlayerState state, {
    required bool isViewer,
  }) {
    final hiddenCards =
        state.backpack.length +
        state.carriedMods.length +
        state.implanted.length +
        state.conditions.length;
    return ProjectedPlayerState._(
      id: state.id,
      characterId: state.characterId,
      coord: state.coord,
      damage: state.damage,
      credits: state.credits,
      equipped: state.equipped,
      alive: state.alive,
      isViewer: isViewer,
      backpack: isViewer ? state.backpack : const [],
      carriedMods: isViewer ? state.carriedMods : const [],
      implanted: isViewer ? state.implanted : const [],
      conditions: isViewer ? state.conditions : const [],
      hiddenCardCount: isViewer ? 0 : hiddenCards,
    );
  }

  final PlayerId id;
  final CharacterId characterId;
  final HexCoord coord;
  final int damage;
  final int credits;
  final EquippedGear equipped;
  final bool alive;
  final bool isViewer;
  final List<CardId> backpack;
  final List<CardId> carriedMods;
  final List<CardId> implanted;
  final List<CardId> conditions;
  final int hiddenCardCount;
}

/// Quest information visible to one player.
@immutable
final class ProjectedQuestState {
  ProjectedQuestState({
    required Iterable<QuestId> storyQuestIds,
    required Iterable<QuestId> personalTasks,
    required Map<PlayerId, int> hiddenPersonalTaskCounts,
  }) : storyQuestIds = List.unmodifiable(storyQuestIds),
       personalTasks = List.unmodifiable(personalTasks),
       hiddenPersonalTaskCounts = UnmodifiableMapView(
         Map.of(hiddenPersonalTaskCounts),
       );

  final List<QuestId> storyQuestIds;
  final List<QuestId> personalTasks;
  final Map<PlayerId, int> hiddenPersonalTaskCounts;
}

/// The safe, player-specific projection of [GameState].
@immutable
final class PlayerGameState {
  PlayerGameState({
    required this.schemaVersion,
    required this.seed,
    required this.round,
    required this.phase,
    required this.activePlayerId,
    required this.actionsLeft,
    required Iterable<ProjectedHexTile> board,
    required Iterable<ProjectedPlayerState> players,
    required Iterable<MonsterInstance> monsters,
    required Map<DeckId, DeckSummary> decks,
    required this.quests,
    required Iterable<String> log,
    required this.pendingDecision,
  }) : board = List.unmodifiable(board),
       players = List.unmodifiable(players),
       monsters = List.unmodifiable(monsters),
       decks = UnmodifiableMapView(Map.of(decks)),
       log = List.unmodifiable(log);

  final int schemaVersion;
  final int seed;
  final int round;
  final GamePhase phase;
  final PlayerId? activePlayerId;
  final int actionsLeft;
  final List<ProjectedHexTile> board;
  final List<ProjectedPlayerState> players;
  final List<MonsterInstance> monsters;
  final Map<DeckId, DeckSummary> decks;
  final ProjectedQuestState quests;
  final List<String> log;
  final PendingDecision? pendingDecision;
}

/// Produces the information that [viewerId] is allowed to see.
PlayerGameState projectFor(GameState fullState, PlayerId viewerId) {
  if (!fullState.players.any((player) => player.id == viewerId)) {
    throw ArgumentError.value(
      viewerId,
      'viewerId',
      'Viewer must be in players.',
    );
  }

  final hiddenTaskCounts = <PlayerId, int>{
    for (final entry in fullState.quests.personalTasksByPlayer.entries)
      if (entry.key != viewerId) entry.key: entry.value.length,
  };
  final viewerTasks =
      fullState.quests.personalTasksByPlayer[viewerId] ?? const <QuestId>[];

  return PlayerGameState(
    schemaVersion: fullState.schemaVersion,
    seed: fullState.seed,
    round: fullState.round,
    phase: fullState.phase,
    activePlayerId: fullState.activePlayerId,
    actionsLeft: fullState.actionsLeft,
    board: fullState.board.map(
      (tile) => tile.opened
          ? ProjectedHexTile._visible(tile)
          : ProjectedHexTile._fog(tile.coord),
    ),
    players: fullState.players.map(
      (player) => ProjectedPlayerState.fromState(
        player,
        isViewer: player.id == viewerId,
      ),
    ),
    monsters: fullState.monsters,
    decks: {
      for (final entry in fullState.decks.entries)
        entry.key: DeckSummary(entry.value.cardsRemaining),
    },
    quests: ProjectedQuestState(
      storyQuestIds: fullState.quests.storyQuestIds,
      personalTasks: viewerTasks,
      hiddenPersonalTaskCounts: hiddenTaskCounts,
    ),
    log: fullState.log,
    pendingDecision: fullState.pendingDecision,
  );
}

void _requireId(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireNonNegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}

void _ensureUnique<T>(Iterable<T> values, String description) {
  final unique = values.toSet();
  if (unique.length != values.length) {
    throw ArgumentError.value(values, description, 'Values must be unique.');
  }
}
