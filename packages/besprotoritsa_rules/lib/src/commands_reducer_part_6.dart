// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

GameStepResult _startRoll(
  GameState state,
  DiceRoller dice,
  String logEntry, {
  int diceCount = 1,
  RollContext? context,
  bool consumesAction = true,
}) {
  final sources = context is SkillCheckContext
      ? skillRerollSources(
          state,
          _playerById(state, context.playerId)!,
          context.stat,
        )
      : const <CardId>[];
  return GameStepResult(
    state: _copyState(
      state,
      actionsLeft: consumesAction ? state.actionsLeft - 1 : state.actionsLeft,
      pendingDecision: AwaitingRerollChoice(
        dice: dice.rollDice(diceCount),
        availableRerolls: sources.length,
        maxDicePerReroll: sources.isEmpty
            ? 999
            : _maxDicePerReroll(state, sources.first),
        rerollSources: sources,
        window: const DecisionWindow(remainingTicks: 1),
        context: context,
      ),
      logEntry: logEntry,
    ),
  );
}

GameStepResult _resolveDecision(
  GameState state,
  DecisionChoice choice,
  DiceRoller dice,
) {
  final pending = state.pendingDecision!;
  return switch (pending) {
    AwaitingRerollChoice() => _resolveReroll(state, pending, choice, dice),
    AwaitingDodge() => _resolveDodge(state, pending, choice, dice),
    AwaitingEventOption() => _resolveEventOption(state, pending, choice, dice),
    AwaitingTerminalPick() => _resolveTerminalPick(state, pending, choice),
    AwaitingHeroReplacement() => _resolveHeroReplacement(
      state,
      pending,
      choice,
      dice,
    ),
    AwaitingOtherPlayerDecision() => GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    ),
  };
}

GameStepResult _resolveHeroReplacement(
  GameState state,
  AwaitingHeroReplacement pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is! SelectReplacementHeroChoice ||
      !pending.characterIds.contains(choice.characterId)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  ReserveHero? reserve;
  for (final candidate in state.reserveHeroes) {
    if (candidate.characterId == choice.characterId) {
      reserve = candidate;
      break;
    }
  }
  if (reserve == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final selectedReserve = reserve;
  final deceased = _playerById(state, pending.playerId);
  final inherited = deceased == null
      ? (reserve: selectedReserve, unclaimed: const <CardId>[])
      : _reserveWithPosthumousInventory(
          state,
          selectedReserve,
          deceased,
        );
  final reserveForQueue = inherited.reserve;
  final queuedReplacements = Map<PlayerId, ReserveHero>.of(
    state.queuedReplacements,
  )..[pending.playerId] = reserveForQueue;
  final unclaimedLog = inherited.unclaimed.isEmpty
      ? ''
      : ':unclaimed:${inherited.unclaimed.join(',')}';
  final selected = _copyState(
    state,
    reserveHeroes: state.reserveHeroes.where(
      (hero) => hero.characterId != selectedReserve.characterId,
    ),
    queuedReplacements: queuedReplacements,
    clearPendingDecision: true,
    logEntry:
        'replacement-selected:'
        '${pending.playerId}:${selectedReserve.characterId}'
        '$unclaimedLog',
  );
  if (pending.remainingPlayerIds.isNotEmpty) {
    if (selected.reserveHeroes.isEmpty) {
      if (selected.queuedReplacements.isEmpty) {
        return GameStepResult(
          state: _copyState(
            selected,
            isComplete: true,
            pendingDamage: const <IncomingDamage>[],
            clearPendingDecision: true,
            logEntry: 'replacement-reserves-exhausted',
          ),
        );
      }
      // The selected reserve must still activate even if later simultaneous
      // deaths have no reserve available.
    } else {
      return GameStepResult(
        state: _copyState(
          selected,
          pendingDecision: AwaitingHeroReplacement(
            playerId: pending.remainingPlayerIds.first,
            characterIds: selected.reserveHeroes.map(
              (hero) => hero.characterId,
            ),
            remainingPlayerIds: pending.remainingPlayerIds.skip(1),
            counterAttackMonsterInstanceId:
                pending.counterAttackMonsterInstanceId,
            counterAttackPlayerId: pending.counterAttackPlayerId,
          ),
        ),
      );
    }
  }
  // A death can interrupt a queue of monster/boil damage.  Choosing a reserve
  // must return to that queue before any new player command becomes legal.
  final queued = _startNextIncomingDamage(
    selected,
    counterAttackMonsterInstanceId: pending.counterAttackMonsterInstanceId,
    counterAttackPlayerId: pending.counterAttackPlayerId,
  );
  if (queued.pendingDecision != null) return GameStepResult(state: queued);
  final counterAttackId = pending.counterAttackMonsterInstanceId;
  final counterAttackPlayerId = pending.counterAttackPlayerId;
  final monster = counterAttackId == null
      ? null
      : _monsterById(queued, counterAttackId);
  final counterAttacker = counterAttackPlayerId == null
      ? null
      : _playerById(queued, counterAttackPlayerId);
  final continued = monster != null && (counterAttacker?.alive ?? false)
      ? _startImmediateCounterAttack(
          queued,
          counterAttackPlayerId!,
          monster,
          dice,
        )
      : queued;
  return GameStepResult(
    state: _resumeAutomaticPhase(
      _resumePendingEventMonsterSpawn(continued, dice),
    ),
  );
}

({ReserveHero reserve, List<CardId> unclaimed}) _reserveWithPosthumousInventory(
  GameState state,
  ReserveHero reserve,
  PlayerState deceased,
) {
  var recipient = PlayerState(
    id: deceased.id,
    characterId: reserve.characterId,
    coord: deceased.coord,
    damage: 0,
    health: reserve.health,
    credits: reserve.credits + deceased.credits,
    backpack: reserve.backpack,
    equipped: reserve.equipped,
    carriedMods: reserve.carriedMods,
    implanted: reserve.implanted,
    conditions: const [],
    alive: true,
    stats: reserve.stats,
  );
  final unclaimed = <CardId>[];
  for (final cardId in deceased.backpack) {
    try {
      recipient = InventoryRules.receive(
        recipient,
        cardId,
        state.cardDefinitions,
      );
    } on BackpackCapacityExceeded {
      unclaimed.add(cardId);
    } on InventoryRuleViolation {
      unclaimed.add(cardId);
    }
  }
  return (
    reserve: ReserveHero(
      characterId: reserve.characterId,
      health: reserve.health,
      stats: reserve.stats,
      credits: recipient.credits,
      backpack: recipient.backpack,
      equipped: recipient.equipped,
      carriedMods: [...recipient.carriedMods, ...deceased.carriedMods],
      implanted: [...recipient.implanted, ...deceased.implanted],
    ),
    unclaimed: unclaimed,
  );
}

GameStepResult _resolveTerminalPick(
  GameState state,
  AwaitingTerminalPick pending,
  DecisionChoice choice,
) {
  if (state.activePlayerId != pending.playerId) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  CardId? purchased;
  if (choice is TerminalPickChoice) {
    if (!pending.offeredCards.contains(choice.cardId)) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final definition = state.cardDefinitions[choice.cardId];
    final player = _activePlayer(state)!;
    if (definition == null || player.credits < definition.cost) {
      return GameStepResult(
        state: state,
        rejection: const InventoryCommandRejected(
          'The selected supply cannot be purchased.',
        ),
      );
    }
    try {
      InventoryRules.receive(player, choice.cardId, state.cardDefinitions);
    } on BackpackCapacityExceeded catch (error) {
      return GameStepResult(
        state: state,
        rejection: InventoryCommandRejected(
          'Backpack capacity ${error.capacity} would be exceeded.',
        ),
      );
    } on InventoryRuleViolation catch (error) {
      return GameStepResult(
        state: state,
        rejection: InventoryCommandRejected(error.message),
      );
    }
    purchased = choice.cardId;
  } else if (choice is! DeclineTerminalPickChoice) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }

  final returned = [
    for (final card in pending.offeredCards)
      if (card != purchased) card,
  ];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final deck = decks[pending.deckId];
  if (deck == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  decks[pending.deckId] = DeckRules.returnAndShuffle(
    deck,
    returned,
    seed: _deckSeed(state, pending.deckId),
  );
  final player = _activePlayer(state)!;
  final next = purchased == null
      ? state
      : _copyState(
          state,
          players: _replacePlayer(
            state,
            player.id,
            (current) => _copyPlayer(
              InventoryRules.receive(
                current,
                purchased!,
                state.cardDefinitions,
              ),
              credits: current.credits - state.cardDefinitions[purchased]!.cost,
            ),
          ),
        );
  return GameStepResult(
    state: _copyState(
      next,
      decks: decks,
      clearPendingDecision: true,
      logEntry: 'terminal-pick:${player.id}:${purchased ?? 'decline'}',
    ),
  );
}

GameStepResult _resolveReroll(
  GameState state,
  AwaitingRerollChoice pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is KeepRollChoice) {
    final resolved = _copyState(state, clearPendingDecision: true);
    return GameStepResult(state: _completeRoll(resolved, pending, dice));
  }
  if (choice is! RerollChoice || pending.availableRerolls == 0) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }

  final indexes = choice.diceIndexes.isEmpty
      ? List<int>.generate(pending.dice.length, (index) => index)
      : choice.diceIndexes;
  if (indexes.any((index) => index < 0 || index >= pending.dice.length)) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  if (indexes.length > pending.maxDicePerReroll) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final rerolled = List<int>.of(pending.dice);
  final newRolls = dice.rollDice(indexes.length);
  for (var index = 0; index < indexes.length; index++) {
    rerolled[indexes[index]] = newRolls[index];
  }
  var rerolledState = state;
  final usedSource = pending.rerollSources.firstOrNull;
  if (usedSource != null) {
    rerolledState = _consumeRerollSource(rerolledState, pending, usedSource);
  }
  final remainingSources = pending.rerollSources.isEmpty
      ? const <CardId>[]
      : pending.rerollSources.skip(1).toList();
  return GameStepResult(
    state: _copyState(
      rerolledState,
      pendingDecision: AwaitingRerollChoice(
        dice: rerolled,
        availableRerolls: pending.availableRerolls - 1,
        maxDicePerReroll: remainingSources.isEmpty
            ? pending.maxDicePerReroll
            : _maxDicePerReroll(rerolledState, remainingSources.first),
        rerollSources: remainingSources,
        window: pending.window,
        context: pending.context,
      ),
    ),
  );
}

GameStepResult _resolveDodge(
  GameState state,
  AwaitingDodge pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is! DodgeChoice) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final rolledDice = dice.rollDice(pending.requiredAgilitySuccesses);
  final hits = countHits(rolledDice);
  final remainingDamage = (pending.monsterDamage - hits).clamp(
    0,
    pending.monsterDamage,
  );
  final targetId = pending.targetPlayerId ?? state.activePlayerId;
  final damaged = remainingDamage > 0;
  final withDamage = resolveHeroDeaths(
    _copyState(
      state,
      players: _replacePlayer(
        state,
        targetId,
        (player) =>
            _copyPlayer(player, damage: player.damage + remainingDamage),
      ),
      clearPendingDecision: true,
      logEntry:
          'combat-roll:dodge:$targetId:${rolledDice.join(',')}:'
          '$hits:$remainingDamage',
    ),
  );
  final targetStillLives = _playerById(withDamage, targetId!)?.alive ?? false;
  final withCondition =
      damaged && targetStillLives && pending.source == DamageSource.monster
      ? _drawCondition(withDamage, targetId)
      : withDamage;
  final counterAttackId = pending.counterAttackMonsterInstanceId;
  final counterAttackPlayerId = pending.counterAttackPlayerId ?? targetId;
  final awaitingReplacement = withCondition.pendingDecision;
  final withContinuation =
      counterAttackId != null && awaitingReplacement is AwaitingHeroReplacement
      ? _copyState(
          withCondition,
          pendingDecision: AwaitingHeroReplacement(
            playerId: awaitingReplacement.playerId,
            characterIds: awaitingReplacement.characterIds,
            remainingPlayerIds: awaitingReplacement.remainingPlayerIds,
            counterAttackMonsterInstanceId: counterAttackId,
            counterAttackPlayerId: counterAttackPlayerId,
          ),
        )
      : withCondition;
  final counterAttackerLives =
      _playerById(withContinuation, counterAttackPlayerId)?.alive ?? false;
  if (counterAttackId != null && counterAttackerLives) {
    final queued = _startNextIncomingDamage(
      withContinuation,
      counterAttackMonsterInstanceId: counterAttackId,
      counterAttackPlayerId: counterAttackPlayerId,
    );
    if (queued.pendingDecision != null) {
      return GameStepResult(state: queued);
    }
    final monster = _monsterById(queued, counterAttackId);
    if (monster != null) {
      return GameStepResult(
        state: _startImmediateCounterAttack(
          queued,
          counterAttackPlayerId,
          monster,
          dice,
        ),
      );
    }
  }
  return GameStepResult(
    state: _resumeAutomaticPhase(
      _resumePendingEventMonsterSpawn(
        _startNextIncomingDamage(
          _copyState(
            withContinuation,
            logEntry: 'dodge:$targetId:$remainingDamage',
          ),
        ),
        dice,
      ),
    ),
  );
}
