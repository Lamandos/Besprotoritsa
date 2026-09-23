// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

// Preserve model constructor parameter order while splitting this library.
// ignore_for_file: always_put_required_named_parameters_first

part of 'game_state.dart';

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
    required this.health,
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
      health: state.health,
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
  final int health;
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
    // A token in an unopened sector would disclose both the contents and the
    // position of fogged map space.  Monsters become public only once their
    // sector has been opened, just like the tile that contains them.
    monsters: fullState.monsters.where(
      (monster) => fullState.tileAt(monster.coord)?.opened ?? false,
    ),
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
