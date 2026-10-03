// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

bool _isInventoryCommand(GameCommand command) =>
    command is EquipCommand ||
    command is UnequipCommand ||
    command is DiscardCardCommand ||
    command is ReceiveCardCommand ||
    command is ImplantModificationCommand;

bool _isActionCommand(GameCommand command) =>
    command is MoveCommand ||
    command is RevealTileCommand ||
    command is AirlockMoveCommand ||
    command is CloseCorridorCommand ||
    command is OpenCorridorCommand ||
    command is AttackCommand ||
    command is SkillCheckCommand ||
    command is HealCommand ||
    command is UseTerminalCommand ||
    command is DepositIntoChestCommand ||
    command is WithdrawFromChestCommand ||
    command is TransferChestCardsCommand ||
    command is ExchangeCommand;

GameState _applyInventoryCommand(GameState state, GameCommand command) {
  final player = _activePlayer(state);
  if (player == null) {
    throw const InventoryRuleViolation('There is no active player.');
  }
  if (command case DiscardCardCommand(:final cardId)) {
    return _discardCard(state, player, cardId);
  }
  final definitions = state.cardDefinitions;
  final updated = switch (command) {
    EquipCommand(:final cardId, :final weaponSlot) => InventoryRules.equip(
      player,
      cardId,
      definitions,
      weaponSlot: weaponSlot,
    ),
    UnequipCommand(:final slot, :final weaponSlot) => InventoryRules.unequip(
      player,
      slot,
      definitions,
      weaponSlot: weaponSlot,
    ),
    ReceiveCardCommand(
      :final cardId,
      :final implantImmediately,
      :final equipImmediately,
      :final weaponSlot,
    ) =>
      _receiveCard(
        player,
        cardId,
        definitions,
        implantImmediately,
        equipImmediately,
        weaponSlot,
      ),
    ImplantModificationCommand(:final cardId) => InventoryRules.implant(
      player,
      cardId,
      definitions,
    ),
    _ => throw ArgumentError.value(
      command,
      'command',
      'Not an inventory command.',
    ),
  };
  return _copyState(
    state,
    players: _replacePlayer(state, player.id, (_) => updated),
    logEntry: 'inventory:${player.id}:${command.runtimeType}',
  );
}

GameState _discardCard(GameState state, PlayerState player, CardId cardId) {
  final definition = state.cardDefinitions[cardId];
  if (definition == null || definition.type == ItemType.modification) {
    throw const InventoryRuleViolation(
      'Only ordinary items and supplies may be discarded.',
    );
  }
  final deckId = _cardSourceDeck(state, definition);
  final deck = deckId == null ? null : state.decks[deckId];
  if (deckId != null && deck == null) {
    throw const InventoryRuleViolation('The card has no discard deck.');
  }
  final updatedDecks = Map<DeckId, DeckState>.of(state.decks);
  if (deckId != null && deck != null) {
    updatedDecks[deckId] = DeckState(
      drawPile: deck.drawPile,
      discardPile: [...deck.discardPile, cardId],
    );
  }
  return _copyState(
    state,
    players: _replacePlayer(
      state,
      player.id,
      (current) => InventoryRules.discard(
        current,
        cardId,
        state.cardDefinitions,
      ),
    ),
    decks: updatedDecks,
    logEntry: 'discard:${player.id}:$cardId',
  );
}

PlayerState _receiveCard(
  PlayerState player,
  CardId cardId,
  Map<CardId, CardDefinition> definitions,
  bool implantImmediately,
  bool equipImmediately,
  int? weaponSlot,
) {
  if (implantImmediately && equipImmediately) {
    throw const InventoryRuleViolation(
      'A received card cannot be implanted and equipped at once.',
    );
  }
  if (equipImmediately) {
    return InventoryRules.equipOnReceive(
      player,
      cardId,
      definitions,
      weaponSlot: weaponSlot,
    );
  }
  final received = InventoryRules.receive(player, cardId, definitions);
  return implantImmediately
      ? InventoryRules.implant(received, cardId, definitions)
      : received;
}

GameStepResult _useTerminal(GameState state) {
  final player = _activePlayer(state)!;
  final draw = DeckRules.draw(
    state.decks['supplies']!,
    count: 3,
    seed: _deckSeed(state, 'supplies'),
  );
  final decks = Map<DeckId, DeckState>.of(state.decks)
    ..['supplies'] = draw.deck;
  return GameStepResult(
    state: _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      decks: decks,
      pendingDecision: AwaitingTerminalPick(
        offeredCards: draw.cards,
        playerId: player.id,
      ),
      logEntry: 'terminal:${player.id}:${draw.cards.join(',')}',
    ),
  );
}

GameState _applyChestCommand(GameState state, GameCommand command) {
  final player = _activePlayer(state)!;
  return switch (command) {
    DepositIntoChestCommand(:final cardId) => _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      players: _replacePlayer(
        state,
        player.id,
        (current) => InventoryRules.discard(
          current,
          cardId,
          state.cardDefinitions,
        ),
      ),
      chestCards: [...state.chestCards, cardId],
      logEntry: 'chest-deposit:${player.id}:$cardId',
    ),
    WithdrawFromChestCommand(:final cardId) => _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      players: _replacePlayer(
        state,
        player.id,
        (current) => InventoryRules.receive(
          current,
          cardId,
          state.cardDefinitions,
        ),
      ),
      chestCards: _removeOne(state.chestCards, cardId),
      logEntry: 'chest-withdraw:${player.id}:$cardId',
    ),
    TransferChestCardsCommand(
      :final depositCards,
      :final depositCardIds,
      :final withdrawCardIds,
    ) =>
      _applyChestTransfer(
        state,
        player,
        depositCards,
        depositCardIds,
        withdrawCardIds,
      ),
    _ => throw ArgumentError.value(
      command,
      'command',
      'Not a chest command.',
    ),
  };
}

GameState _applyChestTransfer(
  GameState state,
  PlayerState player,
  List<InventoryCardSelection> depositCards,
  List<CardId> depositCardIds,
  List<CardId> withdrawCardIds,
) {
  var updatedPlayer = player;
  final chestCards = List<CardId>.of(state.chestCards);
  for (final selection in depositCards) {
    updatedPlayer = InventoryRules.removeForTransfer(
      updatedPlayer,
      selection,
      state.cardDefinitions,
    );
    chestCards.add(selection.cardId);
  }
  for (final cardId in depositCardIds) {
    updatedPlayer = InventoryRules.discard(
      updatedPlayer,
      cardId,
      state.cardDefinitions,
    );
    chestCards.add(cardId);
  }
  for (final cardId in withdrawCardIds) {
    final chestIndex = chestCards.indexOf(cardId);
    updatedPlayer = InventoryRules.receive(
      updatedPlayer,
      cardId,
      state.cardDefinitions,
    );
    chestCards.removeAt(chestIndex);
  }
  InventoryRules.requireWeaponCapacity(updatedPlayer, state.cardDefinitions);
  InventoryRules.requireBackpackFits(updatedPlayer, state.cardDefinitions);
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: _replacePlayer(state, player.id, (_) => updatedPlayer),
    chestCards: chestCards,
    logEntry: 'chest-transfer:${player.id}',
  );
}

GameState _exchange(GameState state, ExchangeCommand command) {
  final player = _activePlayer(state)!;
  final partner = _playerById(state, command.partnerId)!;
  final exchanged = _exchangePlayers(state, player, partner, command);
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: [
      for (final current in state.players)
        if (current.id == player.id)
          exchanged.from
        else if (current.id == partner.id)
          exchanged.to
        else
          current,
    ],
    logEntry: 'exchange:${player.id}:${partner.id}',
  );
}

InventoryTransfer _exchangePlayers(
  GameState state,
  PlayerState player,
  PlayerState partner,
  ExchangeCommand command,
) {
  var from = player;
  var to = partner;
  final givenCards = [
    if (command.giveCardId case final cardId?) cardId,
    ...command.giveCardIds,
    ...command.giveCards.map((selection) => selection.cardId),
  ];
  final receivedCards = [
    if (command.receiveCardId case final cardId?) cardId,
    ...command.receiveCardIds,
    ...command.receiveCards.map((selection) => selection.cardId),
  ];
  // Remove all selected cards first so a simultaneous swap still fits when
  // either backpack starts at capacity.
  for (final selection in command.giveCards) {
    from = InventoryRules.removeForTransfer(
      from,
      selection,
      state.cardDefinitions,
    );
  }
  for (final selection in command.receiveCards) {
    to = InventoryRules.removeForTransfer(
      to,
      selection,
      state.cardDefinitions,
    );
  }
  InventoryRules.requireWeaponCapacity(from, state.cardDefinitions);
  InventoryRules.requireWeaponCapacity(to, state.cardDefinitions);
  final legacyGivenCards = [
    if (command.giveCardId case final cardId?) cardId,
    ...command.giveCardIds,
  ];
  final legacyReceivedCards = [
    if (command.receiveCardId case final cardId?) cardId,
    ...command.receiveCardIds,
  ];
  for (final cardId in legacyGivenCards) {
    from = InventoryRules.discard(from, cardId, state.cardDefinitions);
  }
  for (final cardId in legacyReceivedCards) {
    to = InventoryRules.discard(to, cardId, state.cardDefinitions);
  }
  InventoryRules.requireBackpackFits(from, state.cardDefinitions);
  InventoryRules.requireBackpackFits(to, state.cardDefinitions);
  for (final cardId in givenCards) {
    to = InventoryRules.receive(to, cardId, state.cardDefinitions);
  }
  for (final cardId in receivedCards) {
    from = InventoryRules.receive(from, cardId, state.cardDefinitions);
  }
  return InventoryTransfer(
    from: _copyPlayer(
      from,
      credits: from.credits - command.giveCredits + command.receiveCredits,
    ),
    to: _copyPlayer(
      to,
      credits: to.credits + command.giveCredits - command.receiveCredits,
    ),
  );
}

List<CardId> _removeOne(Iterable<CardId> cards, CardId cardId) {
  final remaining = List<CardId>.of(cards);
  if (!remaining.remove(cardId)) {
    throw StateError('Expected card "$cardId" to be present.');
  }
  return remaining;
}

int _deckSeed(GameState state, DeckId deckId) {
  var value = (state.seed ^ state.round ^ state.log.length) & 0x7fffffff;
  for (final codeUnit in deckId.codeUnits) {
    value = ((value * 31) ^ codeUnit) & 0x7fffffff;
  }
  return value;
}

List<GameEvent> _eventsForTransition(GameState before, GameState after) {
  final events = <GameEvent>[];
  for (final player in after.players) {
    final previous = _playerById(before, player.id);
    if (previous == null) continue;
    final enteredHex = previous.coord != player.coord;
    if (enteredHex) {
      events.add(
        HexEntered(playerId: player.id, from: previous.coord, to: player.coord),
      );
    }
    if (enteredHex && after.pendingDecision is AwaitingDodge) {
      events.add(ColocationTriggered(playerId: player.id, coord: player.coord));
    }
    final damage = player.damage - previous.damage;
    if (damage > 0) {
      events.add(DamageDealt(playerId: player.id, amount: damage));
    }
    final previousConditions = List<CardId>.of(previous.conditions);
    for (final condition in player.conditions) {
      if (previousConditions.remove(condition)) continue;
      events.add(ConditionDrawn(playerId: player.id, conditionId: condition));
    }
  }
  return events;
}
