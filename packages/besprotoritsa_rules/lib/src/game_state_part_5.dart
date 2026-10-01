// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

// Preserve model constructor parameter order while splitting this library.
// ignore_for_file: always_put_required_named_parameters_first

part of 'game_state.dart';

@immutable
final class GameState {
  GameState({
    this.schemaVersion = 1,
    required this.seed,
    this.difficulty = 1,
    required this.round,
    required this.phase,
    required this.activePlayerId,
    required this.actionsLeft,
    required Iterable<HexTile> board,
    required Iterable<PlayerState> players,
    required Iterable<MonsterInstance> monsters,
    required Map<DeckId, DeckState> decks,
    required this.quests,
    Iterable<CardId> chestCards = const [],
    Iterable<BoilToken> boils = const [],
    Iterable<ReserveHero> reserveHeroes = const [],
    Map<PlayerId, ReserveHero> queuedReplacements = const {},
    Map<CardId, ConditionCard> conditionCards = const {},
    Map<CardId, CardDefinition> cardDefinitions = const {},
    Map<CardId, Map<String, Object?>> eventDefinitions = const {},
    Map<CardId, Map<String, Object?>> questDefinitions = const {},
    Map<CardId, Map<String, Object?>> taskDefinitions = const {},
    Map<CardId, Map<String, Object?>> monsterDefinitions = const {},
    Map<String, String> contentTranslations = const {},
    Iterable<IncomingDamage> pendingDamage = const [],
    Iterable<String> log = const [],
    Iterable<GameEvent> gameEvents = const [],
    this.isComplete = false,
    this.monsterTurnIndex = 0,
    this.monsterStepsRemaining = 0,
    this.eventTurnIndex = 0,
    this.actionsTakenThisTurn = 0,
    this.pendingDecision,
    this.pendingEventMonsterSpawn,
  }) : board = List.unmodifiable(board),
       players = List.unmodifiable([
         for (final player in players)
           if (phase == GamePhase.playersTurn && player.id == activePlayerId)
             player.withActionPoints(actionsLeft)
           else
             player,
       ]),
       monsters = List.unmodifiable(monsters),
       boils = List.unmodifiable(boils),
       reserveHeroes = List.unmodifiable(reserveHeroes),
       queuedReplacements = UnmodifiableMapView(Map.of(queuedReplacements)),
       conditionCards = UnmodifiableMapView(Map.of(conditionCards)),
       cardDefinitions = UnmodifiableMapView(Map.of(cardDefinitions)),
       eventDefinitions = UnmodifiableMapView({
         for (final entry in eventDefinitions.entries)
           entry.key: Map<String, Object?>.unmodifiable(entry.value),
       }),
       questDefinitions = _freezeDefinitions(questDefinitions),
       taskDefinitions = _freezeDefinitions(taskDefinitions),
       monsterDefinitions = _freezeDefinitions(monsterDefinitions),
       contentTranslations = UnmodifiableMapView(Map.of(contentTranslations)),
       chestCards = List.unmodifiable(chestCards),
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
    if (difficulty < 1) {
      throw ArgumentError.value(difficulty, 'difficulty', 'Must be positive.');
    }
    _requireNonNegative(actionsLeft, 'actionsLeft');
    _requireNonNegative(monsterTurnIndex, 'monsterTurnIndex');
    _requireNonNegative(monsterStepsRemaining, 'monsterStepsRemaining');
    _requireNonNegative(eventTurnIndex, 'eventTurnIndex');
    _requireNonNegative(actionsTakenThisTurn, 'actionsTakenThisTurn');
    _ensureUnique(this.board.map((tile) => tile.coord), 'board coordinates');
    _ensureUnique(this.board.map((tile) => tile.id), 'tile ids');
    _ensureUnique(this.players.map((player) => player.id), 'player ids');
    _ensureUnique(
      this.reserveHeroes.map((hero) => hero.characterId),
      'reserve character ids',
    );
    final usedCharacterIds = this.players
        .map((player) => player.characterId)
        .toSet();
    if (this.reserveHeroes.any(
      (hero) => usedCharacterIds.contains(hero.characterId),
    )) {
      throw ArgumentError.value(
        reserveHeroes,
        'reserveHeroes',
        'A reserve character must not already be in use.',
      );
    }
    for (final entry in this.queuedReplacements.entries) {
      if (!this.players.any((player) => player.id == entry.key)) {
        throw ArgumentError.value(
          queuedReplacements,
          'queuedReplacements',
          'A queued replacement must belong to an existing player.',
        );
      }
    }
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

  /// Required successful hits for skill checks in this game.
  final int difficulty;
  final int round;
  final GamePhase phase;
  final PlayerId? activePlayerId;
  final int actionsLeft;
  final List<HexTile> board;
  final List<PlayerState> players;
  final List<MonsterInstance> monsters;
  final List<BoilToken> boils;
  final List<ReserveHero> reserveHeroes;
  final Map<PlayerId, ReserveHero> queuedReplacements;
  final Map<CardId, ConditionCard> conditionCards;
  final Map<CardId, CardDefinition> cardDefinitions;

  /// Static event card data available to this local content set.
  final Map<CardId, Map<String, Object?>> eventDefinitions;
  final Map<CardId, Map<String, Object?>> questDefinitions;
  final Map<CardId, Map<String, Object?>> taskDefinitions;
  final Map<CardId, Map<String, Object?>> monsterDefinitions;

  /// Localized full-set content strings indexed by their catalog key.
  final Map<String, String> contentTranslations;

  /// Shared storage in the start/anabiosis sector. Credits are deliberately
  /// not represented here: only cards can be placed in the chest.
  final List<CardId> chestCards;
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

  /// Completed regular actions by the active player in the current turn.
  /// It makes the "before the first action" implant window explicit rather
  /// than inferring it from a variable number of remaining actions.
  final int actionsTakenThisTurn;
  final PendingDecision? pendingDecision;
  final PendingEventMonsterSpawn? pendingEventMonsterSpawn;

  /// The immutable player list is also the saved turn order. The first player
  /// is the leader for setup and reads the opening prologue.
  List<PlayerId> get turnOrder => List.unmodifiable(players.map((p) => p.id));

  /// The first player in [turnOrder], or null for a state without players.
  PlayerId? get leaderPlayerId => players.isEmpty ? null : players.first.id;

  HexTile? tileAt(HexCoord coord) {
    for (final tile in board) {
      if (tile.coord == coord) {
        return tile;
      }
    }
    return null;
  }
}

Map<String, Map<String, Object?>> _freezeDefinitions(
  Map<String, Map<String, Object?>> definitions,
) => UnmodifiableMapView({
  for (final entry in definitions.entries)
    entry.key: Map<String, Object?>.unmodifiable(entry.value),
});

/// A board cell as seen by a particular player. A fogged cell contains no tile
/// metadata, exits, or location data.
