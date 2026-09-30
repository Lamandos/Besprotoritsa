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
  final definition = selected.eventDefinitions[pending.eventId];
  if (definition != null) {
    final optionIndex = int.tryParse(choice.option.replaceFirst('option-', ''));
    final rawOptions = definition['options'];
    if (optionIndex == null ||
        rawOptions is! List<Object?> ||
        optionIndex < 1 ||
        optionIndex > rawOptions.length) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final rawOption = rawOptions[optionIndex - 1];
    if (rawOption is! Map<String, dynamic>) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final check = rawOption['skillCheck'];
    if (check == null) {
      return GameStepResult(state: _resumeAutomaticPhase(selected));
    }
    if (check is! Map<String, dynamic> ||
        check['skill'] is! String ||
        check['difficulty'] is! int) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final skill = StatType.values.byName(check['skill']! as String);
    final difficulty = check['difficulty']! as int;
    return _startRoll(
      selected,
      dice,
      'event-skill:$playerId:${pending.eventId}:$optionIndex',
      diceCount: _statDice(_playerById(selected, playerId)!, selected, skill),
      context: SkillCheckContext(
        playerId: playerId,
        stat: skill,
        difficulty: difficulty,
        eventId: pending.eventId,
      ),
      consumesAction: false,
    );
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
      difficulty: selected.difficulty,
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
  if (context.eventId == 'cabin-noise') {
    return _resolveCabinNoise(state, context, succeeded);
  }
  if (context.questId != null && succeeded) {
    return _completeMvpQuest(state, context);
  }
  final stateAfterCounters =
      context.eventId == null &&
          succeeded &&
          context.stat == StatType.agility &&
          state.questDefinitions.isNotEmpty &&
          state
                  .tileAt(_playerById(state, context.playerId)!.coord)
                  ?.ventColor !=
              null &&
          state
                  .tileAt(_playerById(state, context.playerId)!.coord)!
                  .ventColor !=
              VentColor.none
      ? _applyFullQuestEvent(
          state,
          const QuestCounterIncremented(metric: 'agility_check_in_ventilation'),
          playerId: context.playerId,
        )
      : state;
  if (context.eventId == null &&
      stateAfterCounters.questDefinitions.isNotEmpty) {
    final player = _playerById(stateAfterCounters, context.playerId)!;
    final locationId = stateAfterCounters.tileAt(player.coord)?.locationId;
    if (locationId != null) {
      return _resumeAutomaticPhase(
        _applyFullQuestEvent(
          stateAfterCounters,
          QuestSkillChecked(
            skill: context.stat,
            locationId: locationId,
            success: succeeded,
          ),
          playerId: context.playerId,
        ),
      );
    }
  }
  return _resumeAutomaticPhase(stateAfterCounters);
}

GameState _applyFullQuestEvent(
  GameState state,
  QuestEvent event, {
  required PlayerId playerId,
}) {
  if (state.questDefinitions.isEmpty) return state;
  final graph = QuestGraph(
    quests: state.questDefinitions.values.map(QuestDefinition.fromJson),
    initialQuestIds: state.quests.storyQuestIds.take(1),
  );
  final active = state.quests.storyQuestIds
      .where((id) => state.quests.statusOf(id) == QuestStatus.active)
      .toList(growable: false);
  if (active.isEmpty) return state;
  final progress = QuestProgress(
    activeQuestIds: active,
    completedQuestIds: state.quests.statuses.entries
        .where((entry) => entry.value == QuestStatus.completed)
        .map((entry) => entry.key),
    conditionProgress: state.quests.conditionProgress,
  );
  final transition = QuestEngine(graph).apply(progress, event);
  final statuses = Map<QuestId, QuestStatus>.of(state.quests.statuses);
  for (final id in active) {
    if (transition.progress.completedQuestIds.contains(id)) {
      statuses[id] = QuestStatus.completed;
    } else if (!transition.progress.isActive(id)) {
      statuses[id] = QuestStatus.discarded;
    }
  }
  for (final id in transition.progress.activeQuestIds) {
    statuses[id] = QuestStatus.active;
  }
  final storyIds = <QuestId>[
    ...state.quests.storyQuestIds,
    ...transition.activatedQuestIds,
  ];
  var players = state.players;
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final spawnedMonsters = <MonsterInstance>[];
  for (final grant in transition.rewards) {
    final reward = grant.reward;
    final targetLocation = graph.quest(grant.questId).targetLocation;
    final recipients = <({PlayerId id, int itemDraws})>[
      if (reward.drawItems > 0) (id: playerId, itemDraws: reward.drawItems),
      if (reward.drawItemsPerPlayerAtTargetLocation > 0)
        for (final player in players)
          if (player.alive &&
              targetLocation != null &&
              state.tileAt(player.coord)?.locationId == targetLocation)
            (
              id: player.id,
              itemDraws: reward.drawItemsPerPlayerAtTargetLocation,
            ),
    ];
    final creditRecipients = reward.creditRollDicePerPlayer > 0
        ? players.where((player) => player.alive).map((player) => player.id)
        : const <PlayerId>[];
    final affectedPlayers = <PlayerId>{
      playerId,
      ...recipients.map((recipient) => recipient.id),
      ...creditRecipients,
    };
    for (final recipientId in affectedPlayers) {
      var player = players.firstWhere(
        (candidate) => candidate.id == recipientId,
      );
      if (recipientId == playerId) {
        player = _copyPlayer(player, credits: player.credits + reward.credits);
      }
      if (creditRecipients.contains(recipientId)) {
        final random = Random(
          _deckSeed(state, 'quest-credit:${grant.questId}:$recipientId'),
        );
        final creditRoll = List<int>.generate(
          reward.creditRollDicePerPlayer,
          (_) => random.nextInt(6) + 1,
        ).fold<int>(0, (sum, face) => sum + face);
        player = _copyPlayer(player, credits: player.credits + creditRoll);
      }
      if (recipientId == playerId) {
        for (final cardId in reward.items) {
          final sourceDeck = decks.entries
              .where(
                (entry) =>
                    entry.value.drawPile.contains(cardId) ||
                    entry.value.discardPile.contains(cardId),
              )
              .firstOrNull;
          if (sourceDeck == null) continue;
          final draw = DeckRules.drawSpecific(
            sourceDeck.value,
            cardId,
            seed: _deckSeed(state, sourceDeck.key),
          );
          if (draw.cards.isEmpty) continue;
          try {
            player = InventoryRules.receive(
              player,
              cardId,
              state.cardDefinitions,
            );
            decks[sourceDeck.key] = draw.deck;
          } on BackpackCapacityExceeded {
            // The quest is complete even when its item reward cannot fit.
          } on InventoryRuleViolation {
            // Invalid reward references are ignored safely at runtime.
          }
        }
      }
      final drawCount = recipients
          .where((recipient) => recipient.id == recipientId)
          .fold<int>(0, (sum, recipient) => sum + recipient.itemDraws);
      final itemDeck = decks['items'];
      if (drawCount > 0 && itemDeck != null) {
        final draw = DeckRules.draw(
          itemDeck,
          count: drawCount,
          seed: _deckSeed(state, 'quest-items:${grant.questId}:$recipientId'),
        );
        decks['items'] = draw.deck;
        final unclaimed = <CardId>[];
        for (final cardId in draw.cards) {
          try {
            player = InventoryRules.receive(
              player,
              cardId,
              state.cardDefinitions,
            );
          } on BackpackCapacityExceeded {
            unclaimed.add(cardId);
          } on InventoryRuleViolation {
            unclaimed.add(cardId);
          }
        }
        if (unclaimed.isNotEmpty) {
          decks['items'] = DeckRules.returnAndShuffle(
            decks['items']!,
            unclaimed,
            seed: _deckSeed(
              state,
              'quest-items-return:${grant.questId}:$recipientId',
            ),
          );
        }
      }
      players = [
        for (final current in players)
          if (current.id == recipientId) player else current,
      ];
    }
  }
  for (final questId in transition.activatedQuestIds) {
    final definition = state.questDefinitions[questId];
    final monsterId = definition?['spawnMonsterId'];
    final locationId = definition?['spawnLocationId'];
    if (monsterId is! String || locationId is! String) continue;
    final monsterDefinition = state.monsterDefinitions[monsterId];
    final tile = state.board.cast<HexTile?>().firstWhere(
      (candidate) => candidate?.locationId == locationId,
      orElse: () => null,
    );
    if (monsterDefinition == null || tile == null) continue;
    spawnedMonsters.add(
      MonsterInstance(
        instanceId: '$questId:$monsterId',
        monsterId: monsterId,
        coord: tile.coord,
        damage: 0,
        health: _scaledMonsterStat(state, monsterDefinition, 'health'),
        defense: monsterDefinition['defense']! as int,
        attack: _scaledMonsterStat(state, monsterDefinition, 'attack'),
        movement: monsterDefinition['movement']! as int,
      ),
    );
  }
  final quests = QuestState(
    storyQuestIds: storyIds,
    personalTasksByPlayer: state.quests.personalTasksByPlayer,
    statuses: statuses,
    conditionProgress: transition.progress.conditionProgress,
  );
  return _copyState(
    state,
    players: players,
    monsters: [...state.monsters, ...spawnedMonsters],
    decks: decks,
    quests: quests,
    isComplete: state.isComplete || transition.gameWon,
    logEntry: [
      ...transition.completedQuestIds.map((id) => 'quest-completed:$id'),
      ...transition.activatedQuestIds.map((id) => 'quest-activated:$id'),
    ].join(','),
  );
}

int _scaledMonsterStat(
  GameState state,
  Map<String, Object?> definition,
  String stat,
) {
  final base = definition[stat]! as int;
  final scaling = definition['scaling'];
  if (scaling is! Map<String, Object?>) return base;
  final perHero = scaling['${stat}PerHero'];
  final perAliveMonster = scaling['${stat}PerAliveMonster'];
  final heroCount = state.players.length;
  final livingMonsters = state.monsters
      .where((monster) => monster.damage < monster.health)
      .length;
  return base +
      (perHero is int ? perHero * heroCount : 0) +
      (perAliveMonster is int ? perAliveMonster * livingMonsters : 0);
}

Map<CardId, int> _ownedCardCounts(PlayerState player) {
  final counts = <CardId, int>{};
  for (final cardId in [
    ...player.backpack,
    ...player.equipped.weapons,
    player.equipped.armor,
    player.equipped.clothing,
    player.equipped.robot,
    ...player.carriedMods,
    ...player.implanted,
  ]) {
    if (cardId != null) {
      counts.update(cardId, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return counts;
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
  return _resumeAutomaticPhase(
    spawnMonster(
      _copyState(state, logEntry: 'event-failure:cabin-noise:${player.id}'),
      MonsterInstance(
        instanceId: 'ghoul-event-${state.round}-${player.id}',
        monsterId: 'ghoul',
        coord: player.coord,
        damage: 0,
        health: 2,
        attack: 2,
      ),
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
    actionsLeft: state.players[nextIndex].actionPoints,
    actionsTakenThisTurn: 0,
    logEntry: 'end-turn:${state.activePlayerId}',
  );
}
