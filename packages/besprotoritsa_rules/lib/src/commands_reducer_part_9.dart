// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

GameState _resumeAutomaticPhase(GameState state, [DiceRoller? dice]) {
  if (state.pendingDecision != null || state.isComplete) return state;
  if (state.pendingTeamEventResolution != null) {
    return _resumeTeamEventResolution(
      state,
      dice ?? SeededDiceRoller(state.seed, checkpoint: state.prngState),
    );
  }
  return switch (state.phase) {
    GamePhase.monstersTurn => _runMonstersTurn(state),
    GamePhase.eventsPhase => _advanceEvents(state),
    GamePhase.playersTurn => state,
  };
}

GameState _resumeTeamEventResolution(GameState state, DiceRoller dice) {
  var current = state;
  while (current.pendingDecision == null && !current.isComplete) {
    final resolution = current.pendingTeamEventResolution;
    if (resolution == null) return _resumeAutomaticPhase(current, dice);
    if (resolution.nextChoiceIndex >= resolution.choices.length) {
      var finished = current;
      for (final choice in resolution.choices) {
        finished = _copyState(
          finished,
          logEntry:
              'event-team-result:${resolution.eventId}:${choice.playerId}:'
              '${choice.option}:'
              '${resolution.outcomes[choice.playerId] ?? 'unresolved'}',
        );
      }
      finished = _copyState(
        finished,
        clearPendingTeamEventResolution: true,
      );
      return _advanceEvents(finished);
    }

    final choice = resolution.choices[resolution.nextChoiceIndex];
    final outcomes = Map<PlayerId, String>.of(resolution.outcomes);
    current = _copyState(
      current,
      activePlayerId: choice.playerId,
      pendingTeamEventResolution: resolution.advance(
        nextChoiceIndex: resolution.nextChoiceIndex + 1,
        outcomes: outcomes,
      ),
    );
    final player = _playerById(current, choice.playerId);
    if (player == null ||
        !player.alive ||
        player.characterId != choice.characterId) {
      outcomes[choice.playerId] = 'skipped';
      current = _updateTeamOutcome(current, choice.playerId, 'skipped');
      continue;
    }

    if (choice.option == 'horde|discard' || choice.option == 'horde|keep') {
      current = _resolveTeamHordeChoice(current, choice);
      current = _updateTeamOutcome(current, choice.playerId, 'success');
      current = resolveHeroDeaths(current);
      if (current.pendingDecision != null) return current;
      continue;
    }

    final definition = current.eventDefinitions[resolution.eventId];
    final optionIndex = int.tryParse(
      choice.option.replaceFirst('option-', ''),
    );
    final rawOptions = definition?['options'];
    if (definition == null ||
        optionIndex == null ||
        rawOptions is! List<Object?> ||
        optionIndex < 1 ||
        optionIndex > rawOptions.length) {
      current = _updateTeamOutcome(current, choice.playerId, 'unresolved');
      continue;
    }
    final rawOptionValue = rawOptions[optionIndex - 1];
    if (rawOptionValue is! Map<String, dynamic>) {
      current = _updateTeamOutcome(current, choice.playerId, 'unresolved');
      continue;
    }
    final rawOption = rawOptionValue;
    final check = rawOption['skillCheck'];
    if (check != null) {
      if (check is! Map<String, dynamic>) {
        current = _updateTeamOutcome(current, choice.playerId, 'unresolved');
        continue;
      }
      final skillName = check['skill'];
      final difficulty = check['difficulty'];
      if (skillName is! String || difficulty is! int) {
        current = _updateTeamOutcome(current, choice.playerId, 'unresolved');
        continue;
      }
      final skill = StatType.values.byName(skillName);
      return _startRoll(
        current,
        dice,
        'event-skill:${choice.playerId}:${resolution.eventId}:$optionIndex',
        diceCount: _statDice(player, current, skill),
        context: SkillCheckContext(
          playerId: choice.playerId,
          stat: skill,
          difficulty: difficulty,
          eventId: resolution.eventId,
          eventBehaviorId: rawOption['behaviorId'] as String?,
          eventOptionIndex: optionIndex,
        ),
        consumesAction: false,
      ).state;
    }

    final automaticOutcome = _eventAutomaticOutcome(rawOption, player);
    if (automaticOutcome == null &&
        !_sameEventEffectPlan(
          rawOption['successEffects'],
          rawOption['failureEffects'],
        )) {
      current = _updateTeamOutcome(current, choice.playerId, 'unresolved');
      continue;
    }
    current = _resolveEventOutcome(
      current,
      definition,
      choice.playerId,
      optionIndex,
      succeeded: automaticOutcome ?? true,
      dice: dice,
    );
    if (current.pendingDecision != null) return current;
  }
  return current;
}

GameState _updateTeamOutcome(
  GameState state,
  PlayerId playerId,
  String outcome,
) {
  final resolution = state.pendingTeamEventResolution;
  if (resolution == null) return state;
  return _copyState(
    state,
    pendingTeamEventResolution: resolution.advance(
      nextChoiceIndex: resolution.nextChoiceIndex,
      outcomes: {...resolution.outcomes, playerId: outcome},
    ),
  );
}

GameState _resolveTeamHordeChoice(GameState state, TeamEventChoice choice) {
  final player = _playerById(state, choice.playerId);
  if (player == null || player.backpack.isEmpty) return state;
  final decks = Map<DeckId, DeckState>.of(state.decks);
  if (choice.option == 'horde|discard') {
    for (final cardId in player.backpack) {
      final definition = state.cardDefinitions[cardId];
      if (definition == null) continue;
      final deckId = _cardSourceDeck(state, definition);
      final deck = deckId == null ? null : decks[deckId];
      if (deckId != null && deck != null) {
        decks[deckId] = DeckState(
          drawPile: deck.drawPile,
          discardPile: [...deck.discardPile, cardId],
        );
      }
    }
    return _copyState(
      state,
      decks: decks,
      players: _replacePlayer(
        state,
        choice.playerId,
        (hero) => _copyPlayer(hero, backpack: const []),
      ),
      logEntry:
          'event-horde-discard:${choice.playerId}:${player.backpack.length}',
    );
  }
  final damage = player.backpack.length * 2;
  return _copyState(
    state,
    players: _replacePlayer(
      state,
      choice.playerId,
      (hero) => _ignoresAnyDamage(state, hero)
          ? hero
          : _copyPlayer(hero, damage: hero.damage + damage),
    ),
    logEntry: 'event-horde-damage:${choice.playerId}:$damage',
  );
}

GameState _resumePendingEventMonsterSpawn(GameState state, DiceRoller dice) {
  final pending = state.pendingEventMonsterSpawn;
  if (pending == null ||
      state.pendingDecision != null ||
      state.pendingDamage.isNotEmpty) {
    return state;
  }
  final cleared = _copyState(state, clearPendingEventMonsterSpawn: true);
  if (state.isComplete) return cleared;
  final locationId = cleared.tileAt(pending.coord)?.locationId;
  final arrived = locationId == null
      ? cleared
      : _applyFullQuestEvent(
          cleared,
          QuestArrived(locationId),
          playerId: pending.playerId,
        );
  if (arrived.isComplete) return arrived;
  final player = _playerById(arrived, pending.playerId);
  final definition = arrived.eventDefinitions[pending.eventId];
  if (player == null || !player.alive || definition == null) return arrived;
  return _spawnEventOptionMonster(
    arrived,
    definition,
    pending.playerId,
    pending.optionIndex,
    pending.coord,
    dice,
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
  Iterable<CardId>? retainedEventCards,
  bool? alive,
  PlayerStats? stats,
  int? health,
  int? weaponModifier,
  int? nextTurnActionDelta,
  int? monsterDamageImmuneThroughRound,
  int? monsterDefenseBonusRound,
  int? monsterDefenseBonus,
  int? damageImmuneThroughRound,
  int? enemyFeaturesIgnoredThroughRound,
  int? nextAttackBonusHits,
  Iterable<CardId>? exhaustedRobots,
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
  retainedEventCards: retainedEventCards ?? player.retainedEventCards,
  alive: alive ?? player.alive,
  stats: stats ?? player.stats,
  weaponModifier: weaponModifier ?? player.weaponModifier,
  actionPoints: player.actionPoints,
  nextTurnActionDelta: nextTurnActionDelta ?? player.nextTurnActionDelta,
  monsterDamageImmuneThroughRound:
      monsterDamageImmuneThroughRound ?? player.monsterDamageImmuneThroughRound,
  monsterDefenseBonusRound:
      monsterDefenseBonusRound ?? player.monsterDefenseBonusRound,
  monsterDefenseBonus: monsterDefenseBonus ?? player.monsterDefenseBonus,
  damageImmuneThroughRound:
      damageImmuneThroughRound ?? player.damageImmuneThroughRound,
  enemyFeaturesIgnoredThroughRound:
      enemyFeaturesIgnoredThroughRound ??
      player.enemyFeaturesIgnoredThroughRound,
  nextAttackBonusHits: coord != null && coord != player.coord
      ? 0
      : nextAttackBonusHits ?? player.nextAttackBonusHits,
  exhaustedRobots: exhaustedRobots ?? player.exhaustedRobots,
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
  exhaustedCarriedRobots: monster.exhaustedCarriedRobots,
  returnsToMonsterDeck: monster.returnsToMonsterDeck,
  defeatRewardDeckId: monster.defeatRewardDeckId,
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
  Iterable<TripwireTrap>? tripwires,
  Iterable<ReserveHero>? reserveHeroes,
  Map<PlayerId, ReserveHero>? queuedReplacements,
  Iterable<CardId>? chestCards,
  Iterable<CardId>? exhaustedChestRobots,
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
  PendingEventMonsterSpawn? pendingEventMonsterSpawn,
  bool clearPendingEventMonsterSpawn = false,
  PendingTeamEventResolution? pendingTeamEventResolution,
  bool clearPendingTeamEventResolution = false,
  String? logEntry,
}) => GameState(
  schemaVersion: state.schemaVersion,
  seed: state.seed,
  prngState: state.prngState,
  contentSetId: state.contentSetId,
  contentSetVersion: state.contentSetVersion,
  viewerPlayerId: state.viewerPlayerId,
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
  tripwires: tripwires ?? state.tripwires,
  reserveHeroes: reserveHeroes ?? state.reserveHeroes,
  queuedReplacements: queuedReplacements ?? state.queuedReplacements,
  chestCards: chestCards ?? state.chestCards,
  exhaustedChestRobots: exhaustedChestRobots ?? state.exhaustedChestRobots,
  conditionCards: state.conditionCards,
  cardDefinitions: state.cardDefinitions,
  eventDefinitions: state.eventDefinitions,
  questDefinitions: state.questDefinitions,
  taskDefinitions: state.taskDefinitions,
  monsterDefinitions: state.monsterDefinitions,
  contentTranslations: state.contentTranslations,
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
  pendingEventMonsterSpawn: clearPendingEventMonsterSpawn
      ? null
      : pendingEventMonsterSpawn ?? state.pendingEventMonsterSpawn,
  pendingTeamEventResolution: clearPendingTeamEventResolution
      ? null
      : pendingTeamEventResolution ?? state.pendingTeamEventResolution,
);
