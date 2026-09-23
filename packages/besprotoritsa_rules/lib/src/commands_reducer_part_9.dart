// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

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
  difficulty: state.difficulty,
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
