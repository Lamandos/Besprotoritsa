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
}) => GameStepResult(
  state: _copyState(
    state,
    actionsLeft: consumesAction ? state.actionsLeft - 1 : state.actionsLeft,
    pendingDecision: AwaitingRerollChoice(
      dice: dice.rollDice(diceCount),
      availableRerolls: 1,
      window: const DecisionWindow(remainingTicks: 1),
      context: context,
    ),
    logEntry: logEntry,
  ),
);

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
  final queued = Map<PlayerId, ReserveHero>.of(state.queuedReplacements)
    ..[pending.playerId] = selectedReserve;
  final selected = _copyState(
    state,
    reserveHeroes: state.reserveHeroes.where(
      (hero) => hero.characterId != selectedReserve.characterId,
    ),
    queuedReplacements: queued,
    clearPendingDecision: true,
    logEntry:
        'replacement-selected:'
        '${pending.playerId}:${selectedReserve.characterId}',
  );
  // A death can interrupt a queue of monster/boil damage.  Choosing a reserve
  // must return to that queue before any new player command becomes legal.
  return GameStepResult(
    state: _resumeAutomaticPhase(_startNextIncomingDamage(selected)),
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
    return GameStepResult(state: _completeRoll(resolved, pending));
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
  return GameStepResult(
    state: _copyState(
      state,
      pendingDecision: AwaitingRerollChoice(
        dice: rerolled,
        availableRerolls: pending.availableRerolls - 1,
        maxDicePerReroll: pending.maxDicePerReroll,
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
  final hits = countHits(dice.rollDice(pending.requiredAgilitySuccesses));
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
    ),
  );
  final targetStillLives = _playerById(withDamage, targetId!)?.alive ?? false;
  final withCondition =
      damaged && targetStillLives && pending.source == DamageSource.monster
      ? _drawCondition(withDamage, targetId)
      : withDamage;
  return GameStepResult(
    state: _resumeAutomaticPhase(
      _startNextIncomingDamage(
        _copyState(
          withCondition,
          logEntry: 'dodge:$targetId:$remainingDamage',
        ),
      ),
    ),
  );
}
