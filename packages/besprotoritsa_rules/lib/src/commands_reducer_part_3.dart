// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

bool _isInventoryCommand(GameCommand command) =>
    command is EquipCommand ||
    command is UnequipCommand ||
    command is ReceiveCardCommand ||
    command is ImplantModificationCommand;

bool _isActionCommand(GameCommand command) =>
    command is MoveCommand ||
    command is AirlockMoveCommand ||
    command is CloseCorridorCommand ||
    command is AttackCommand ||
    command is SkillCheckCommand ||
    command is HealCommand ||
    command is UseTerminalCommand ||
    command is ExchangeCommand;

GameState _applyInventoryCommand(GameState state, GameCommand command) {
  final player = _activePlayer(state);
  if (player == null) {
    throw const InventoryRuleViolation('There is no active player.');
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
    ReceiveCardCommand(:final cardId, :final implantImmediately) =>
      _receiveCard(player, cardId, definitions, implantImmediately),
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

PlayerState _receiveCard(
  PlayerState player,
  CardId cardId,
  Map<CardId, CardDefinition> definitions,
  bool implantImmediately,
) {
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
      players: _replacePlayer(
        state,
        player.id,
        (current) => InventoryRules.discard(current, cardId),
      ),
      chestCards: [...state.chestCards, cardId],
      logEntry: 'chest-deposit:${player.id}:$cardId',
    ),
    WithdrawFromChestCommand(:final cardId) => _copyState(
      state,
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
    _ => throw ArgumentError.value(
      command,
      'command',
      'Not a chest command.',
    ),
  };
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
  if (command.giveCardId case final cardId?) {
    final transfer = InventoryRules.transfer(
      from,
      to,
      cardId,
      state.cardDefinitions,
    );
    from = transfer.from;
    to = transfer.to;
  }
  if (command.receiveCardId case final cardId?) {
    final transfer = InventoryRules.transfer(
      to,
      from,
      cardId,
      state.cardDefinitions,
    );
    from = transfer.to;
    to = transfer.from;
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
