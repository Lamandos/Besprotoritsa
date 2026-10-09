// Active inventory abilities are validated and applied here so local and
// multiplayer turns use the same authoritative transition.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

bool _cardAbilityConsumesAction(
  GameState state,
  UseCardAbilityCommand command,
) {
  final definition = state.cardDefinitions[command.cardId];
  return command.cardId == 'medic-bag' ||
      (definition?.behaviorIds.contains('action.spend') ?? false);
}

CommandRejection? _validateCardAbility(
  GameState state,
  UseCardAbilityCommand command,
) {
  final player = _activePlayer(state);
  if (player == null) return const ActionUnavailableInPhase();
  final definition = state.cardDefinitions[command.cardId];
  if (definition == null) {
    return const InventoryCommandRejected('Карта больше недоступна.');
  }
  final owned =
      player.backpack.contains(command.cardId) ||
      InventoryRules.activeCardIds(player).contains(command.cardId);
  if (!owned) {
    return const InventoryCommandRejected('Карта должна быть у персонажа.');
  }
  if (command.cardId == 'power-cell') {
    if (!player.backpack.contains(command.cardId) ||
        command.targetCardId == null ||
        !player.exhaustedRobots.contains(command.targetCardId)) {
      return const InventoryCommandRejected(
        'Выберите повёрнутого робота, чтобы вернуть его в готовность.',
      );
    }
    return null;
  }
  if (command.cardId == 'air-canister') {
    final target = command.targetCoord == null
        ? null
        : state.tileAt(command.targetCoord!);
    final source = state.tileAt(player.coord);
    if (!player.backpack.contains(command.cardId) ||
        source?.type != HexTileType.airlock ||
        target == null ||
        target.type != HexTileType.airlock ||
        target.coord == source?.coord ||
        !target.opened ||
        (target.isBlocked) ||
        state.actionsLeft < 2) {
      return const InventoryCommandRejected(
        'Выберите открытый шлюз; для перехода нужны 2 действия.',
      );
    }
    return null;
  }
  if (command.cardId == 'door-remote') {
    final target = command.targetCoord == null
        ? null
        : state.tileAt(command.targetCoord!);
    if (!player.backpack.contains(command.cardId) ||
        target == null ||
        target.type != HexTileType.corridor ||
        !target.opened ||
        player.credits < 2 ||
        state.actionsLeft < 1) {
      return const InventoryCommandRejected(
        'Выберите коридор и проверьте, что у вас есть 2 кредита.',
      );
    }
    final occupied =
        state.players.any(
          (hero) => hero.alive && hero.coord == target.coord,
        ) ||
        state.monsters.any((monster) => monster.coord == target.coord) ||
        state.boils.any((boil) => boil.coord == target.coord);
    if (!target.isBlocked && occupied) {
      return const InventoryCommandRejected(
        'Занятый коридор закрыть нельзя.',
      );
    }
    return null;
  }
  final isRobotAbility = definition.behaviorIds.contains('robot.exhaust');
  if (isRobotAbility) {
    final supported =
        definition.behaviorIds.any(_isDirectlyUsableBehavior) ||
        command.cardId == 'prot2-ct';
    if (!supported ||
        player.equipped.robot != command.cardId ||
        player.exhaustedRobots.contains(command.cardId)) {
      return const InventoryCommandRejected(
        'Робот должен быть экипирован и находиться в готовности.',
      );
    }
    if (command.cardId == 'h3-al') {
      final target = _playerById(state, command.targetPlayerId ?? player.id);
      if (target == null || !target.alive || target.damage == 0) {
        return const InventoryCommandRejected(
          'Выберите живого персонажа, которому нужно лечение.',
        );
      }
    }
    if (command.cardId == 'sc0-u7') {
      final tile = command.targetCoord == null
          ? null
          : state.tileAt(command.targetCoord!);
      if (tile == null || tile.opened) {
        return const InventoryCommandRejected(
          'Выберите закрытый фрагмент карты.',
        );
      }
    }
    if (command.cardId == 'ghb-dtn') {
      final targetPlayer = _playerById(
        state,
        command.targetPlayerId ?? player.id,
      );
      final destination = command.targetCoord == null
          ? null
          : state.tileAt(command.targetCoord!);
      if (targetPlayer == null ||
          !targetPlayer.alive ||
          destination == null ||
          !destination.opened ||
          destination.isBlocked ||
          (_heroPathDistance(state, targetPlayer.coord, destination.coord) ??
                  3) >
              2) {
        return const InventoryCommandRejected(
          'Выберите открытый сектор не дальше двух шагов от союзника.',
        );
      }
    }
    return null;
  }
  if (!definition.behaviorIds.any(_isDirectlyUsableBehavior)) {
    return const InventoryCommandRejected(
      'Эта способность используется в подходящем окне действия.',
    );
  }
  if (_cardAbilityConsumesAction(state, command) && state.actionsLeft < 1) {
    return const NotEnoughActions();
  }

  if (command.cardId == 'medic-bag') {
    final target = _playerById(state, command.targetPlayerId ?? player.id);
    final amount = command.amount;
    if (target == null ||
        !target.alive ||
        target.coord.distanceTo(player.coord) > 1) {
      return const InventoryCommandRejected(
        'Цель должна быть живым персонажем в этой или соседней клетке.',
      );
    }
    if (amount == null ||
        amount < 1 ||
        amount > target.damage ||
        amount > player.credits) {
      return const InventoryCommandRejected(
        'Укажите лечение не больше недостающего здоровья и числа кредитов.',
      );
    }
    return null;
  }

  if (command.cardId == 'tripwire') {
    if (!player.backpack.contains(command.cardId) || state.actionsLeft < 1) {
      return const InventoryCommandRejected(
        'Растяжка должна находиться в рюкзаке.',
      );
    }
    return null;
  }

  if (command.cardId == 'gas-cylinder') {
    final monster = command.targetMonsterInstanceId == null
        ? null
        : _monsterById(state, command.targetMonsterInstanceId!);
    if (state.actionsLeft < 1 ||
        monster == null ||
        monster.coord != player.coord ||
        _isBossForAbility(state, monster)) {
      return const InventoryCommandRejected(
        'Выберите не-босса в своей клетке.',
      );
    }
    return null;
  }

  final hasKnownImmediateEffect = switch (command.cardId) {
    'nanobots' ||
    'dry-rations' ||
    'water' ||
    'ration' ||
    'medkit' ||
    'credits' ||
    'stash' ||
    'adrenaline-supply' ||
    'adrenaline-x' ||
    'proton-shield' => true,
    _ => false,
  };
  if (!hasKnownImmediateEffect) {
    return const InventoryCommandRejected(
      'Эта способность пока не может быть применена здесь.',
    );
  }
  if (!player.backpack.contains(command.cardId)) {
    return const InventoryCommandRejected(
      'Расходуемая карта должна находиться в рюкзаке.',
    );
  }
  if (_cardAbilityRestoresHealth(command.cardId) && player.damage == 0) {
    return const InventoryCommandRejected('Здоровье уже полностью.');
  }
  return null;
}

bool _isDirectlyUsableBehavior(String id) => const {
  'health.restorePerCredit',
  'health.restore',
  'health.restoreAll',
  'economy.gainCredits',
  'action.grant',
  'damage.preventUntilRoundEnd',
  'damage.ignoreAnyUntilRoundEnd',
  'combat.addHit',
  'map.moveAirlock',
  'map.forceMove',
  'map.revealAnyFragment',
  'map.openCloseCorridor',
  'monster.trapOnEnter',
  'monster.killNonBoss',
  'robot.ready',
  'robot.ignoreEnemyFeatures',
}.contains(id);

bool _cardAbilityRestoresHealth(String cardId) => const {
  'nanobots',
  'dry-rations',
  'water',
  'ration',
  'medkit',
}.contains(cardId);

bool _isBossForAbility(GameState state, MonsterInstance monster) {
  final features = state.monsterDefinitions[monster.monsterId]?['features'];
  return features is List<Object?> && features.contains('boss');
}

GameState _useCardAbility(GameState state, UseCardAbilityCommand command) {
  final player = _activePlayer(state)!;
  if (const {'r69-nic3', 'alarm-bot'}.contains(command.cardId)) {
    return _exhaustRobot(
      _copyState(
        state,
        players: _replaceActivePlayer(
          state,
          (current) => _copyPlayer(
            current,
            enemyFeaturesIgnoredThroughRound: state.round,
          ),
        ),
        logEntry: 'robot-ignore-enemy-features:${player.id}:${state.round}',
      ),
      player,
      command.cardId,
    );
  }
  if (command.cardId == 'medic-bag') {
    final targetId = command.targetPlayerId ?? player.id;
    final amount = command.amount!;
    final medical = _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      players: [
        for (final current in state.players)
          if (current.id == player.id && current.id == targetId)
            _copyPlayer(
              current,
              credits: current.credits - amount,
              damage: current.damage - amount,
            )
          else if (current.id == player.id)
            _copyPlayer(current, credits: current.credits - amount)
          else if (current.id == targetId)
            _copyPlayer(current, damage: current.damage - amount)
          else
            current,
      ],
      logEntry: 'card-ability:medic-bag:${player.id}:$targetId:$amount',
    );
    return _clearPlayerConditions(medical, targetId);
  }

  if (command.cardId == 'tripwire') {
    final trap = TripwireTrap(
      instanceId: 'tripwire:${player.id}:${state.round}:${state.log.length}',
      coord: player.coord,
      ownerId: player.id,
      cardId: command.cardId,
    );
    return _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      players: _replaceActivePlayer(
        state,
        (current) => _copyPlayer(
          current,
          backpack: _removeOne(current.backpack, command.cardId),
        ),
      ),
      tripwires: [...state.tripwires, trap],
      logEntry: 'tripwire-placed:${player.id}:${player.coord}',
    );
  }

  if (command.cardId == 'air-canister') {
    final target = command.targetCoord!;
    final moved = _discardUsedCard(state, player, command.cardId);
    return _move(moved, target, 2).state;
  }

  if (command.cardId == 'door-remote') {
    final target = command.targetCoord!;
    final tile = state.tileAt(target)!;
    final playerAfterPayment = _copyPlayer(
      player,
      credits: player.credits - 2,
    );
    final paid = _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      players: _replacePlayer(state, player.id, (_) => playerAfterPayment),
    );
    final opened = tile.isBlocked;
    return _copyState(
      paid,
      board: [
        for (final candidate in paid.board)
          if (candidate.coord == target)
            _copyTile(candidate, isBlocked: !opened)
          else
            candidate,
      ],
      logEntry: 'door-remote:${player.id}:$target:${opened ? 'open' : 'close'}',
    );
  }

  if (command.cardId == 'ghb-dtn') {
    final targetId = command.targetPlayerId ?? player.id;
    final destination = command.targetCoord!;
    final moved = _copyState(
      state,
      players: _replacePlayer(
        state,
        targetId,
        (current) => _copyPlayer(current, coord: destination),
      ),
      logEntry: 'robot-move:${player.id}:$targetId:$destination',
    );
    final triggered = resolveColocation(
      moved,
      coord: destination,
      playerId: targetId,
    );
    return _exhaustRobot(triggered, player, command.cardId);
  }

  if (command.cardId == 'sc0-u7') {
    final target = state.tileAt(command.targetCoord!)!;
    return _exhaustRobot(
      _copyState(
        state,
        board: _openTile(state.board, target),
        logEntry: 'robot-reveal:${player.id}:${target.coord}',
      ),
      player,
      command.cardId,
    );
  }

  if (command.cardId == 'h3-al') {
    final targetId = command.targetPlayerId ?? player.id;
    final healed = _copyState(
      state,
      players: _replacePlayer(
        state,
        targetId,
        (current) => _copyPlayer(
          current,
          damage: (current.damage - 3).clamp(0, current.damage),
        ),
      ),
      logEntry: 'robot-heal:${player.id}:$targetId:3',
    );
    return _exhaustRobot(
      _clearPlayerConditions(healed, targetId),
      player,
      command.cardId,
    );
  }

  if (command.cardId == 'prot2-ct') {
    return _exhaustRobot(
      _copyState(
        state,
        players: _replaceActivePlayer(
          state,
          (current) => _copyPlayer(
            current,
            monsterDefenseBonusRound: state.round,
          ),
        ),
        logEntry: 'robot-defense:${player.id}:${state.round}',
      ),
      player,
      command.cardId,
    );
  }

  if (command.cardId == 'prot3-ct') {
    return _exhaustRobot(
      _copyState(
        state,
        players: _replaceActivePlayer(
          state,
          (current) => _copyPlayer(
            current,
            damageImmuneThroughRound: state.round,
          ),
        ),
        logEntry: 'robot-immunity:${player.id}:${state.round}',
      ),
      player,
      command.cardId,
    );
  }

  if (command.cardId == 'gtu-b1c4') {
    return _exhaustRobot(
      _copyState(
        state,
        players: _replaceActivePlayer(
          state,
          (current) => _copyPlayer(
            current,
            nextAttackBonusHits: current.nextAttackBonusHits + 1,
          ),
        ),
        logEntry: 'robot-next-hit:${player.id}',
      ),
      player,
      command.cardId,
    );
  }

  if (command.cardId == 'power-cell') {
    final consumed = _discardUsedCard(state, player, command.cardId);
    return _copyState(
      consumed,
      players: _replaceActivePlayer(
        consumed,
        (current) => _copyPlayer(
          current,
          exhaustedRobots: current.exhaustedRobots.where(
            (robotId) => robotId != command.targetCardId,
          ),
        ),
      ),
      logEntry: 'robot-ready:${player.id}:${command.targetCardId}',
    );
  }

  if (command.cardId == 'gas-cylinder') {
    final monster = _monsterById(state, command.targetMonsterInstanceId!)!;
    var killed = _discardUsedCard(state, player, command.cardId);
    final deck = killed.decks['monsters'];
    final decks = Map<DeckId, DeckState>.of(killed.decks);
    if (deck != null && monster.returnsToMonsterDeck) {
      decks['monsters'] = DeckState(
        drawPile: deck.drawPile,
        discardPile: [...deck.discardPile, monster.monsterId],
      );
    }
    killed = _copyState(
      killed,
      actionsLeft: state.actionsLeft - 1,
      monsters: killed.monsters.where(
        (candidate) => candidate.instanceId != monster.instanceId,
      ),
      decks: decks,
      logEntry: 'card-ability:gas-cylinder:${player.id}:${monster.monsterId}',
    );
    if (monster.monsterId == RestlessMonster.restlessMonsterId) {
      final killer = _playerById(killed, player.id)!;
      final loot = _awardRestlessTrophies(killer, monster, killed);
      killed = _copyState(
        killed,
        players: _restlessTrophyPlayers(
          killed,
          killer.id,
          loot.player,
          loot.exhaustedRobots,
        ),
        logEntry: loot.unclaimed.isEmpty
            ? null
            : 'restless-unclaimed:${monster.instanceId}:'
                  '${loot.unclaimed.join(',')}',
      );
    }
    if (killed.questDefinitions.isNotEmpty) {
      killed = _applyFullQuestEvent(
        killed,
        QuestMonsterKilled(monsterId: monster.monsterId),
        playerId: player.id,
      );
    }
    return _recordPersonalTaskKillProgress(state, killed, player.id);
  }

  final consumed = _discardUsedCard(state, player, command.cardId);
  final updatedPlayer = _activePlayer(consumed)!;
  final effect = switch (command.cardId) {
    'nanobots' => (heal: 1, credits: 0, actions: 0),
    'dry-rations' => (heal: 4, credits: 0, actions: 0),
    'water' => (heal: 3, credits: 0, actions: 0),
    'ration' => (heal: 5, credits: 0, actions: 0),
    'medkit' => (heal: updatedPlayer.damage, credits: 0, actions: 0),
    'credits' => (heal: 0, credits: 5, actions: 0),
    'stash' => (heal: 0, credits: 10, actions: 0),
    'adrenaline-supply' => (heal: 0, credits: 0, actions: 1),
    'adrenaline-x' => (heal: 0, credits: 0, actions: 2),
    'proton-shield' => (heal: 0, credits: 0, actions: 0),
    _ => throw StateError('Validated unsupported card ability.'),
  };
  final nextPlayer = _copyPlayer(
    updatedPlayer,
    damage: (updatedPlayer.damage - effect.heal).clamp(0, updatedPlayer.damage),
    credits: updatedPlayer.credits + effect.credits,
    monsterDefenseBonusRound: command.cardId == 'nanobots'
        ? state.round
        : updatedPlayer.monsterDefenseBonusRound,
    damageImmuneThroughRound: command.cardId == 'proton-shield'
        ? state.round
        : updatedPlayer.damageImmuneThroughRound,
  );
  final resolved = _copyState(
    consumed,
    actionsLeft: consumed.actionsLeft + effect.actions,
    players: _replacePlayer(consumed, updatedPlayer.id, (_) => nextPlayer),
    logEntry: 'card-ability:${command.cardId}:${player.id}',
  );
  return effect.heal > 0
      ? _clearPlayerConditions(resolved, updatedPlayer.id)
      : resolved;
}

GameState _clearPlayerConditions(GameState state, PlayerId playerId) {
  final player = _playerById(state, playerId);
  if (player == null || player.conditions.isEmpty) return state;

  final decks = Map<DeckId, DeckState>.of(state.decks);
  final conditionDeck = decks['conditions'];
  if (conditionDeck != null) {
    decks['conditions'] = DeckState(
      drawPile: conditionDeck.drawPile,
      discardPile: [...conditionDeck.discardPile, ...player.conditions],
    );
  }
  return _copyState(
    state,
    players: _replacePlayer(
      state,
      playerId,
      (current) => _copyPlayer(current, conditions: const []),
    ),
    decks: decks,
  );
}

GameState _exhaustRobot(
  GameState state,
  PlayerState player,
  CardId cardId,
) => _copyState(
  state,
  players: _replacePlayer(
    state,
    player.id,
    (current) => _copyPlayer(
      current,
      exhaustedRobots: [...current.exhaustedRobots, cardId],
    ),
  ),
  logEntry: 'robot-exhausted:${player.id}:$cardId',
);

int? _heroPathDistance(GameState state, HexCoord start, HexCoord target) {
  if (start == target) return 0;
  final distances = <HexCoord, int>{start: 0};
  final queue = <HexCoord>[start];
  for (var index = 0; index < queue.length; index++) {
    final current = queue[index];
    final tile = state.tileAt(current);
    if (tile == null || !tile.opened || tile.isBlocked) continue;
    for (final edge in tile.exits) {
      final next = current.neighbor(edge);
      final neighbor = state.tileAt(next);
      if (neighbor == null ||
          !neighbor.opened ||
          neighbor.isBlocked ||
          !neighbor.hasExit(edge.opposite) ||
          distances.containsKey(next)) {
        continue;
      }
      final distance = distances[current]! + 1;
      if (next == target) return distance;
      distances[next] = distance;
      queue.add(next);
    }
  }
  return null;
}

List<CardId> _attackRerollSources(
  GameState state,
  PlayerState player,
  int hookRerolls,
) {
  final sources = <CardId>[];
  final registry = EffectRegistry.standard();
  for (final cardId in InventoryRules.activeCardIds(player)) {
    if (player.exhaustedRobots.contains(cardId)) continue;
    for (final behaviorId
        in state.cardDefinitions[cardId]?.behaviorIds ?? const <String>[]) {
      switch (registry[behaviorId]) {
        case ModifyRollHook(:final rerollsPerAttack) when rerollsPerAttack > 0:
          sources.addAll(List.filled(rerollsPerAttack, cardId));
        default:
          if (behaviorId == 'dice.reroll.anyCountPerAttack') {
            sources.add(cardId);
          }
      }
    }
  }
  final hookSourceCount = sources.length;
  if (hookSourceCount < hookRerolls) {
    sources.addAll(
      List.filled(hookRerolls - hookSourceCount, 'unknown-reroll'),
    );
  }
  if (state.phase == GamePhase.playersTurn &&
      player.backpack.contains('defibrillator')) {
    sources.add('defibrillator');
  }
  return sources;
}

int _maxDicePerReroll(GameState state, CardId source) {
  if (const {
    'science-stimulant',
    'agility-stimulant',
    'endurance-stimulant',
    'repair-stimulant',
    'strength-stimulant',
    'defibrillator',
    'pistol',
    'pipe',
    'circular-saw',
  }.contains(source)) {
    return source == 'defibrillator' ||
            (state.cardDefinitions[source]?.behaviorIds.contains(
                  'dice.reroll.anyCountPerAttack',
                ) ??
                false)
        ? 999
        : 1;
  }
  return 999;
}

GameState _consumeRerollSource(
  GameState state,
  AwaitingRerollChoice pending,
  CardId cardId,
) {
  final playerId = switch (pending.context) {
    SkillCheckContext(:final playerId) => playerId,
    AttackRollContext(:final playerId) => playerId,
    _ => state.activePlayerId,
  };
  final player = playerId == null ? null : _playerById(state, playerId);
  final definition = state.cardDefinitions[cardId];
  if (player == null || definition == null) return state;
  if (player.backpack.contains(cardId) &&
      definition.behaviorIds.contains('card.discardCost')) {
    return _discardUsedCard(state, player, cardId);
  }
  if (definition.behaviorIds.contains('robot.exhaust') &&
      player.equipped.robot == cardId &&
      !player.exhaustedRobots.contains(cardId)) {
    return _exhaustRobot(state, player, cardId);
  }
  return state;
}

bool _usesRemoteCourier(GameState state, ExchangeCommand command) {
  final player = _activePlayer(state);
  final partner = _playerById(state, command.partnerId);
  return player != null &&
      partner != null &&
      partner.coord != player.coord &&
      player.equipped.robot == 'c6-car-courier' &&
      !player.exhaustedRobots.contains('c6-car-courier');
}

bool _usesSmugglerMarkRemoteExchange(
  GameState state,
  ExchangeCommand command,
) {
  final player = _activePlayer(state);
  final partner = _playerById(state, command.partnerId);
  return player != null &&
      partner != null &&
      player.coord != partner.coord &&
      player.backpack.contains('smuggler-mark');
}

bool _canExchangeRemotely(GameState state, ExchangeCommand command) =>
    _usesRemoteCourier(state, command) ||
    _usesSmugglerMarkRemoteExchange(state, command);

GameState _exchangeWithRobotIfNeeded(
  GameState state,
  ExchangeCommand command,
) {
  final usedCourier = _usesRemoteCourier(state, command);
  final exchanged = _exchange(
    state,
    command,
    consumesAction: !usedCourier,
  );
  if (!usedCourier) return exchanged;
  final player = _activePlayer(state)!;
  return _exhaustRobot(exchanged, player, 'c6-car-courier');
}

GameState _discardUsedCard(
  GameState state,
  PlayerState player,
  CardId cardId,
) {
  final definition = state.cardDefinitions[cardId]!;
  final deckId = definition.sourceDeck;
  final deck = deckId == null ? null : state.decks[deckId];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  if (deckId != null && deck != null) {
    decks[deckId] = DeckState(
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
    decks: decks,
  );
}

GameState _triggerTripwire(
  GameState state,
  TripwireTrap trap,
  MonsterInstance monster,
) {
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final supplyDeck = decks['supplies'];
  if (supplyDeck != null) {
    decks['supplies'] = DeckState(
      drawPile: supplyDeck.drawPile,
      discardPile: [...supplyDeck.discardPile, trap.cardId],
    );
  }
  final monsterDeck = decks['monsters'];
  if (monsterDeck != null && monster.returnsToMonsterDeck) {
    decks['monsters'] = DeckState(
      drawPile: monsterDeck.drawPile,
      discardPile: [...monsterDeck.discardPile, monster.monsterId],
    );
  }
  var triggered = _copyState(
    state,
    tripwires: state.tripwires.where(
      (candidate) => candidate.instanceId != trap.instanceId,
    ),
    monsters: state.monsters.where(
      (candidate) => candidate.instanceId != monster.instanceId,
    ),
    decks: decks,
    logEntry: 'tripwire-triggered:${trap.ownerId}:${monster.monsterId}',
  );
  if (monster.monsterId == RestlessMonster.restlessMonsterId) {
    final killer = _playerById(triggered, trap.ownerId);
    if (killer != null) {
      final loot = _awardRestlessTrophies(killer, monster, triggered);
      triggered = _copyState(
        triggered,
        players: _restlessTrophyPlayers(
          triggered,
          killer.id,
          loot.player,
          loot.exhaustedRobots,
        ),
        logEntry: loot.unclaimed.isEmpty
            ? null
            : 'restless-unclaimed:${monster.instanceId}:'
                  '${loot.unclaimed.join(',')}',
      );
    }
  }
  if (triggered.questDefinitions.isNotEmpty) {
    triggered = _applyFullQuestEvent(
      triggered,
      QuestMonsterKilled(monsterId: monster.monsterId),
      playerId: trap.ownerId,
    );
  }
  return _recordPersonalTaskKillProgress(state, triggered, trap.ownerId);
}
