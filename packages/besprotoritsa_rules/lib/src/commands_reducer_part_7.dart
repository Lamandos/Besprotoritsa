// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

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
