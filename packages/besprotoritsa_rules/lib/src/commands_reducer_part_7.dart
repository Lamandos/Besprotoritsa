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

GameState _startNextIncomingDamage(
  GameState state, {
  String? counterAttackMonsterInstanceId,
  PlayerId? counterAttackPlayerId,
}) {
  if (state.pendingDecision != null || state.pendingDamage.isEmpty) {
    return state;
  }
  final pending = state.pendingDamage.where(
    (damage) {
      final target = _playerById(state, damage.targetPlayerId);
      if (target == null || !target.alive) return false;
      if (target.damageImmuneThroughRound != null &&
          state.round <= target.damageImmuneThroughRound!) {
        return false;
      }
      if (damage.source == DamageSource.monster &&
          target.monsterDamageImmuneThroughRound != null &&
          state.round <= target.monsterDamageImmuneThroughRound!) {
        return false;
      }
      return true;
    },
  ).toList();
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
      counterAttackMonsterInstanceId: counterAttackMonsterInstanceId,
      counterAttackPlayerId: counterAttackPlayerId,
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
  if (choice.option.startsWith('market|')) {
    return _resolveEventMarketChoice(state, pending, playerId, choice.option);
  }
  final selected = _copyState(
    state,
    clearPendingDecision: true,
    activePlayerId: playerId,
    logEntry: 'event-option:$playerId:${choice.option}',
  );
  if (choice.option.startsWith('discard|')) {
    final cardId = choice.option.substring('discard|'.length);
    final definition = selected.cardDefinitions[cardId];
    final hero = _playerById(selected, playerId);
    if (definition == null ||
        hero == null ||
        !_ownedMarketCards(hero).contains(cardId)) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final deckId = _cardSourceDeck(selected, definition);
    final decks = Map<DeckId, DeckState>.of(selected.decks);
    final deck = deckId == null ? null : decks[deckId];
    if (deckId != null && deck != null) {
      decks[deckId] = DeckState(
        drawPile: deck.drawPile,
        discardPile: [...deck.discardPile, cardId],
      );
    }
    final discarded = _copyState(
      selected,
      decks: decks,
      players: _replacePlayer(
        selected,
        playerId,
        (current) => _removeOwnedMarketCard(current, cardId),
      ),
      logEntry: 'event-discard:$playerId:$cardId',
    );
    return GameStepResult(state: _resumeAutomaticPhase(discarded));
  }
  if (choice.option.startsWith('horde|')) {
    final hero = _playerById(selected, playerId);
    if (hero == null ||
        (choice.option != 'horde|discard' && choice.option != 'horde|keep')) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final decks = Map<DeckId, DeckState>.of(selected.decks);
    final players = choice.option == 'horde|discard'
        ? _replacePlayer(
            selected,
            playerId,
            (current) => _copyPlayer(current, backpack: const []),
          )
        : _replacePlayer(
            selected,
            playerId,
            (current) => _copyPlayer(
              current,
              damage:
                  current.damage +
                  (_ignoresAnyDamage(selected, current)
                      ? 0
                      : hero.backpack.length * 2),
            ),
          );
    if (choice.option == 'horde|discard') {
      for (final cardId in hero.backpack) {
        final definition = selected.cardDefinitions[cardId];
        if (definition == null) continue;
        final deckId = _cardSourceDeck(selected, definition);
        final deck = deckId == null ? null : decks[deckId];
        if (deckId != null && deck != null) {
          decks[deckId] = DeckState(
            drawPile: deck.drawPile,
            discardPile: [...deck.discardPile, cardId],
          );
        }
      }
    }
    final resolved = _copyState(
      selected,
      players: players,
      decks: decks,
      logEntry: choice.option == 'horde|discard'
          ? 'event-horde-discard:$playerId:${hero.backpack.length}'
          : 'event-horde-damage:$playerId:${hero.backpack.length * 2}',
    );
    return GameStepResult(
      state: _resumeAutomaticPhase(resolveHeroDeaths(resolved)),
    );
  }
  if (choice.option.startsWith('reveal:')) {
    final coord = _parseEventCoordChoice(choice.option, 'reveal');
    final target = coord == null ? null : selected.tileAt(coord);
    if (target == null || target.opened) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final revealed = _copyState(
      selected,
      board: _openTile(selected.board, target),
      logEntry: 'event-reveal:$playerId:$coord',
    );
    return GameStepResult(state: _resumeAutomaticPhase(revealed));
  }
  if (choice.option.startsWith('place:')) {
    final parts = choice.option.split(':');
    if (parts.length != 4) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final q = int.tryParse(parts[2]);
    final r = int.tryParse(parts[3]);
    final target = q == null || r == null
        ? null
        : selected.tileAt(HexCoord(q, r));
    final monster = selected.monsters
        .where((entry) => entry.instanceId == parts[1])
        .firstOrNull;
    final hero = _playerById(selected, playerId);
    if (target == null ||
        monster == null ||
        hero == null ||
        !target.opened ||
        target.isBlocked ||
        hero.coord.distanceTo(target.coord) != 1) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final placed = _copyState(
      selected,
      monsters: [
        for (final entry in selected.monsters)
          if (entry.instanceId == monster.instanceId)
            _copyMonster(entry, coord: target.coord)
          else
            entry,
      ],
      logEntry: 'event-monster-place:${monster.instanceId}:${target.coord}',
    );
    return GameStepResult(
      state: _resumeAutomaticPhase(
        resolveColocation(
          placed,
          coord: target.coord,
          monsterInstanceId: monster.instanceId,
        ),
      ),
    );
  }
  if (choice.option.startsWith('pick:')) {
    final parts = choice.option.split(':');
    if (parts.length != 3 || parts[1].isEmpty || parts[2].isEmpty) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final deckId = parts[1];
    final cardId = parts[2];
    final offered = [
      for (final option in pending.options)
        if (option.startsWith('pick:$deckId:'))
          option.substring(5 + deckId.length + 1),
    ];
    if (!offered.contains(cardId) || selected.decks[deckId] == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final hero = _playerById(selected, playerId)!;
    final returnedCards = List<String>.of(offered);
    final selectedIndex = returnedCards.indexOf(cardId);
    if (selectedIndex >= 0) returnedCards.removeAt(selectedIndex);
    var receivedHero = hero;
    try {
      receivedHero = InventoryRules.receive(
        hero,
        cardId,
        selected.cardDefinitions,
      );
    } on Object catch (error) {
      if (error is! BackpackCapacityExceeded &&
          error is! InventoryRuleViolation) {
        rethrow;
      }
      returnedCards.add(cardId);
    }
    final decks = Map<DeckId, DeckState>.of(selected.decks);
    if (returnedCards.isNotEmpty) {
      decks[deckId] = DeckRules.returnAndShuffle(
        decks[deckId]!,
        returnedCards,
        seed: _deckSeed(
          selected,
          'event-pick-rest:${pending.eventId}:$deckId',
        ),
      );
    }
    final picked = _copyState(
      selected,
      decks: decks,
      players: _replacePlayer(
        selected,
        playerId,
        (_) => receivedHero,
      ),
      logEntry: 'event-picked:$playerId:$cardId',
    );
    return GameStepResult(state: _resumeAutomaticPhase(picked));
  }
  if (choice.option.startsWith('kill:')) {
    final instanceId = choice.option.substring('kill:'.length);
    final monster = selected.monsters
        .where((candidate) => candidate.instanceId == instanceId)
        .firstOrNull;
    if (monster == null || monster.damage >= monster.health) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final decks = Map<DeckId, DeckState>.of(selected.decks);
    final monsterDeck = decks['monsters'];
    if (monster.returnsToMonsterDeck && monsterDeck != null) {
      decks['monsters'] = DeckState(
        drawPile: monsterDeck.drawPile,
        discardPile: [...monsterDeck.discardPile, monster.monsterId],
      );
    }
    var killer = _playerById(selected, playerId)!;
    var unclaimedLoot = const <CardId>[];
    var exhaustedTrophies = const <CardId>[];
    if (monster.monsterId == RestlessMonster.restlessMonsterId) {
      final loot = _awardRestlessTrophies(killer, monster, selected);
      killer = loot.player;
      unclaimedLoot = loot.unclaimed;
      exhaustedTrophies = loot.exhaustedRobots;
    }
    final unclaimedCount = unclaimedLoot.length;
    var killed = _copyState(
      selected,
      players: _restlessTrophyPlayers(
        selected,
        playerId,
        killer,
        exhaustedTrophies,
      ),
      monsters: selected.monsters.where(
        (candidate) => candidate.instanceId != monster.instanceId,
      ),
      decks: decks,
      logEntry:
          'event-kill:$playerId:${monster.monsterId}:unclaimed:$unclaimedCount',
    );
    if (killed.questDefinitions.isNotEmpty) {
      killed = _applyFullQuestEvent(
        killed,
        QuestMonsterKilled(monsterId: monster.monsterId),
        playerId: playerId,
      );
      killed = _applyFullQuestEvent(
        killed,
        const QuestCounterIncremented(metric: 'damage_tokens_collected'),
        playerId: playerId,
      );
    }
    killed = _recordPersonalTaskKillProgress(state, killed, playerId);
    return GameStepResult(state: _resumeAutomaticPhase(killed));
  }
  if (choice.option.startsWith('move:')) {
    final coord = _parseEventMoveOption(choice.option);
    final target = coord == null
        ? null
        : _eventMoveTargets(
            selected,
            playerId,
          ).where((tile) => tile.coord == coord).firstOrNull;
    if (target == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final moved = _copyState(
      selected,
      players: _replacePlayer(
        selected,
        playerId,
        (player) => _copyPlayer(player, coord: target.coord),
      ),
      logEntry: 'event-move:$playerId:${target.coord}',
    );
    final arrived = resolveColocation(
      moved,
      coord: target.coord,
      playerId: playerId,
    );
    final locationId = target.locationId;
    final withQuestEvent = locationId == null
        ? arrived
        : _applyFullQuestEvent(
            arrived,
            QuestArrived(locationId),
            playerId: playerId,
          );
    return GameStepResult(state: _resumeAutomaticPhase(withQuestEvent));
  }
  if (choice.option.startsWith('move_spawn:')) {
    final parts = choice.option.split(':');
    if (parts.length != 4) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final optionIndex = int.tryParse(parts[1]);
    final q = int.tryParse(parts[2]);
    final r = int.tryParse(parts[3]);
    final targetCoord = q == null || r == null ? null : HexCoord(q, r);
    final target = targetCoord == null
        ? null
        : _eventMoveTargets(
            selected,
            playerId,
          ).where((tile) => tile.coord == targetCoord).firstOrNull;
    final eventDefinition = pending.eventId == null
        ? null
        : selected.eventDefinitions[pending.eventId];
    if (optionIndex == null || target == null || eventDefinition == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final moved = _copyState(
      selected,
      players: _replacePlayer(
        selected,
        playerId,
        (hero) => _copyPlayer(hero, coord: target.coord),
      ),
      logEntry: 'event-move:$playerId:${target.coord}',
    );
    final afterColocation = resolveColocation(
      moved,
      coord: target.coord,
      playerId: playerId,
    );
    if (afterColocation.pendingDecision != null ||
        afterColocation.pendingDamage.isNotEmpty) {
      return GameStepResult(
        state: _copyState(
          afterColocation,
          pendingEventMonsterSpawn: PendingEventMonsterSpawn(
            eventId: pending.eventId!,
            playerId: playerId,
            optionIndex: optionIndex,
            coord: target.coord,
          ),
        ),
      );
    }
    final locationId = target.locationId;
    final arrived = locationId == null
        ? afterColocation
        : _applyFullQuestEvent(
            afterColocation,
            QuestArrived(locationId),
            playerId: playerId,
          );
    final spawned = _spawnEventOptionMonster(
      arrived,
      eventDefinition,
      playerId,
      optionIndex,
      target.coord,
      dice,
    );
    return GameStepResult(state: _resumeAutomaticPhase(spawned));
  }
  if (pending.eventId == null) {
    return GameStepResult(state: _resumeAutomaticPhase(selected));
  }
  final definition = selected.eventDefinitions[pending.eventId];
  if (definition != null) {
    if (choice.option.startsWith('sector:')) {
      final coord = _parseEventSectorOption(choice.option);
      final spawn = definition['spawn'];
      if (coord == null ||
          spawn is! Map<String, Object?> ||
          !(_eventSpawnChoiceSectors(selected, definition, spawn)?.contains(
                coord,
              ) ??
              false)) {
        return GameStepResult(
          state: state,
          rejection: const ActionBlockedByPendingDecision(),
        );
      }
      final resolved = _resolveEventMonsterSpawn(
        selected,
        definition,
        playerId,
        dice,
        spawnCoord: coord,
      );
      return GameStepResult(state: _resumeAutomaticPhase(resolved));
    }
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
      final spawn = definition['spawn'];
      if (rawOption['behaviorId'] == 'monster.spawn' &&
          rawOption['resolution'] == 'immediate' &&
          spawn is Map<String, Object?>) {
        final withNarrative = _copyState(
          selected,
          logEntry: 'event-result:${definition['id']}:$optionIndex:success',
        );
        final sectors = _eventSpawnChoiceSectors(
          withNarrative,
          definition,
          spawn,
        );
        if (sectors != null && sectors.length > 1) {
          return GameStepResult(
            state: _copyState(
              withNarrative,
              pendingDecision: AwaitingEventOption(
                options: sectors.map(_eventSectorOption),
                playerId: playerId,
                eventId: pending.eventId,
              ),
            ),
          );
        }
        if (sectors != null) {
          if (sectors.isEmpty) return GameStepResult(state: withNarrative);
          final resolved = _resolveEventMonsterSpawn(
            withNarrative,
            definition,
            playerId,
            dice,
            spawnCoord: sectors.single,
          );
          return GameStepResult(state: _resumeAutomaticPhase(resolved));
        }
      }
      final automaticOutcome = _eventAutomaticOutcome(
        rawOption,
        _playerById(selected, playerId)!,
      );
      if (automaticOutcome == null &&
          !_sameEventEffectPlan(
            rawOption['successEffects'],
            rawOption['failureEffects'],
          )) {
        return GameStepResult(
          state: _resumeAutomaticPhase(
            _copyState(
              selected,
              logEntry:
                  'event-result-unresolved:${definition['id']}:$optionIndex',
            ),
          ),
        );
      }
      final resolved =
          rawOption['behaviorId'] == 'monster.spawn' &&
              rawOption['resolution'] == 'immediate'
          ? _resolveEventMonsterSpawn(
              _copyState(
                selected,
                logEntry:
                    'event-result:${definition['id']}:$optionIndex:success',
              ),
              definition,
              playerId,
              dice,
            )
          : _resolveEventOutcome(
              selected,
              definition,
              playerId,
              optionIndex,
              succeeded: automaticOutcome ?? true,
              dice: dice,
            );
      return GameStepResult(state: _resumeAutomaticPhase(resolved));
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
        eventBehaviorId: rawOption['behaviorId'] as String?,
        eventOptionIndex: optionIndex,
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

GameState _spawnEventOptionMonster(
  GameState state,
  Map<String, Object?> event,
  PlayerId playerId,
  int optionIndex,
  HexCoord coord,
  DiceRoller dice,
) {
  final deck = state.decks['monsters'];
  if (deck == null) return state;
  final draw = DeckRules.draw(
    deck,
    seed: _deckSeed(
      state,
      'event-move-monster:${event['id']}:$optionIndex:$playerId',
    ),
  );
  if (draw.cards.isEmpty) return state;
  final monsterId = draw.cards.single;
  final definition = state.monsterDefinitions[monsterId];
  if (definition == null) return state;
  final monster = MonsterInstance(
    instanceId:
        'event-${state.round}-${state.eventTurnIndex}-'
        '${event['id']}-$optionIndex-$monsterId',
    monsterId: monsterId,
    coord: coord,
    damage: 0,
    health: _scaledMonsterStat(state, definition, 'health'),
    defense: definition['defense']! as int,
    attack: _scaledMonsterStat(state, definition, 'attack'),
    movement: definition['movement']! as int,
    returnsToMonsterDeck: true,
  );
  final spawned = _copyState(
    state,
    monsters: [...state.monsters, monster],
    decks: Map<DeckId, DeckState>.of(state.decks)..['monsters'] = draw.deck,
    logEntry: 'event-monster-spawn:${event['id']}:$monsterId:$coord',
  );
  return _startImmediateMonsterAttack(spawned, playerId, monster, dice);
}

bool? _eventAutomaticOutcome(
  Map<String, dynamic> option,
  PlayerState player,
) {
  final automatic = option['autoOutcome'];
  if (automatic == 'success') return true;
  if (automatic == 'failure') return false;
  if (automatic != 'condition') return null;
  final condition = option['condition'];
  if (condition is! Map<String, dynamic>) return null;
  switch (condition['type']) {
    case 'equipped_slot':
      return switch (condition['slot']) {
        'robot' => player.equipped.robot != null,
        'weapon' => player.equipped.weapon != null,
        'armor' => player.equipped.armor != null,
        'clothing' => player.equipped.clothing != null,
        _ => false,
      };
    case 'owns_card':
      final cardId = condition['cardId'];
      return cardId is String && _ownedMarketCards(player).contains(cardId);
    default:
      return null;
  }
}

bool _sameEventEffectPlan(Object? left, Object? right) {
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameEventEffectPlan(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map<String, dynamic> && right is Map<String, dynamic>) {
    if (left.length != right.length ||
        !left.keys.toSet().containsAll(right.keys)) {
      return false;
    }
    for (final key in left.keys) {
      if (!_sameEventEffectPlan(left[key], right[key])) return false;
    }
    return true;
  }
  return left == right;
}

GameState _resolveEventMonsterSpawn(
  GameState state,
  Map<String, Object?> event,
  PlayerId playerId,
  DiceRoller dice, {
  HexCoord? spawnCoord,
}) {
  final spawn = event['spawn'];
  final monsterDeck = state.decks['monsters'];
  if (spawn is! Map<String, Object?> || monsterDeck == null) return state;
  final draw = DeckRules.draw(
    monsterDeck,
    seed: _deckSeed(state, 'event-monster:${event['id']}:$playerId'),
  );
  if (draw.cards.isEmpty) return state;
  final monsterId = draw.cards.single;
  final definition = state.monsterDefinitions[monsterId];
  final coord = spawnCoord ?? _eventMonsterSpawnCoord(state, event, spawn);
  if (definition == null || coord == null) return state;

  final monsters = Map<DeckId, DeckState>.of(state.decks)
    ..['monsters'] = draw.deck;
  final eventId = event['id'];
  final monster = MonsterInstance(
    instanceId:
        'event-${state.round}-${state.eventTurnIndex}-'
        '$eventId-$monsterId',
    monsterId: monsterId,
    coord: coord,
    damage: 0,
    health: _scaledMonsterStat(state, definition, 'health'),
    defense: definition['defense']! as int,
    attack: _scaledMonsterStat(state, definition, 'attack'),
    movement: definition['movement']! as int,
    returnsToMonsterDeck: true,
  );
  final spawned = _copyState(
    state,
    monsters: [...state.monsters, monster],
    decks: monsters,
    logEntry: 'event-monster-spawn:${event['id']}:$monsterId:$coord',
  );
  final arrived = _resolveTripwireArrival(spawned, monster);
  if (!arrived.monsters.any(
    (candidate) => candidate.instanceId == monster.instanceId,
  )) {
    return arrived;
  }
  final immediateCombat = event['immediateCombat'] == true;
  if (!immediateCombat) return arrived;
  final occupants = arrived.players
      .where((player) => player.alive && player.coord == coord)
      .toList();
  if (occupants.isEmpty) return arrived;
  final combatant = occupants.firstWhere(
    (player) => player.id == playerId,
    orElse: () => occupants.first,
  );
  return _startImmediateMonsterAttack(
    arrived,
    combatant.id,
    monster,
    dice,
  );
}

HexCoord? _eventMonsterSpawnCoord(
  GameState state,
  Map<String, Object?> event,
  Map<String, Object?> spawn,
) {
  final target = spawn['target'];
  if (target == 'openSector') {
    final sectors = _eventOpenSectors(state);
    if (sectors.isNotEmpty) return sectors.first;
  } else if (target == 'location') {
    final locationId = event['locationId'];
    if (locationId is String) {
      for (final tile in state.board) {
        if (tile.locationId == locationId && tile.opened && !tile.isBlocked) {
          return tile.coord;
        }
      }
    }
  }
  if (spawn['fallback'] == 'closedSector') {
    for (final tile in state.board) {
      if (tile.type == HexTileType.compartment &&
          !tile.opened &&
          !tile.isBlocked) {
        return tile.coord;
      }
    }
  }
  return null;
}

List<HexCoord> _eventOpenSectors(GameState state) => [
  for (final tile in state.board)
    if (tile.opened && !tile.isBlocked) tile.coord,
];

List<HexCoord> _eventClosedSectors(GameState state) => [
  for (final tile in state.board)
    if (!tile.opened && !tile.isBlocked) tile.coord,
];

List<HexCoord>? _eventSpawnChoiceSectors(
  GameState state,
  Map<String, Object?> event,
  Map<String, Object?> spawn,
) {
  if (spawn['target'] == 'openSector') {
    final open = _eventOpenSectors(state);
    if (open.isNotEmpty) return open;
    return spawn['fallback'] == 'closedSector'
        ? _eventClosedSectors(state)
        : open;
  }
  if (spawn['target'] != 'location') return null;
  final locationId = event['locationId'];
  if (locationId is String &&
      state.board.any(
        (tile) =>
            tile.locationId == locationId && tile.opened && !tile.isBlocked,
      )) {
    return null;
  }
  if (spawn['fallback'] == 'closedSector') {
    return _eventClosedSectors(state);
  }
  return null;
}

String _eventSectorOption(HexCoord coord) => 'sector:${coord.q}:${coord.r}';

HexCoord? _parseEventSectorOption(String option) {
  final parts = option.split(':');
  if (parts.length != 3 || parts.first != 'sector') return null;
  final q = int.tryParse(parts[1]);
  final r = int.tryParse(parts[2]);
  return q == null || r == null ? null : HexCoord(q, r);
}

GameState _startImmediateMonsterAttack(
  GameState state,
  PlayerId playerId,
  MonsterInstance monster,
  DiceRoller dice,
) {
  final target = _playerById(state, playerId);
  if (target != null &&
      ((target.damageImmuneThroughRound != null &&
              state.round <= target.damageImmuneThroughRound!) ||
          (target.monsterDamageImmuneThroughRound != null &&
              state.round <= target.monsterDamageImmuneThroughRound!))) {
    return _startImmediateCounterAttack(state, playerId, monster, dice);
  }
  if (_monsterSpawnsBoilInsteadOfAttack(state, monster)) {
    final withBoil = spawnBoil(
      state,
      BoilToken(
        instanceId: 'event-nest-boil-${monster.instanceId}',
        coord: monster.coord,
      ),
    );
    if (withBoil.pendingDecision case final AwaitingDodge pending) {
      return _copyState(
        withBoil,
        pendingDecision: AwaitingDodge(
          monsterDamage: pending.monsterDamage,
          requiredAgilitySuccesses: pending.requiredAgilitySuccesses,
          targetPlayerId: pending.targetPlayerId,
          source: pending.source,
          counterAttackMonsterInstanceId: monster.instanceId,
          counterAttackPlayerId: playerId,
        ),
      );
    }
    if (withBoil.pendingDamage.isNotEmpty) {
      return _startNextIncomingDamage(
        withBoil,
        counterAttackMonsterInstanceId: monster.instanceId,
        counterAttackPlayerId: playerId,
      );
    }
    return _startImmediateCounterAttack(withBoil, playerId, monster, dice);
  }
  final player = _playerById(state, playerId)!;
  final incoming =
      (monster.attack -
              (_monsterIgnoresDefense(state, monster)
                  ? 0
                  : _playerDefense(state, player)))
          .clamp(0, monster.attack);
  if (incoming == 0) {
    return _startImmediateCounterAttack(state, playerId, monster, dice);
  }
  return _copyState(
    state,
    pendingDecision: AwaitingDodge(
      monsterDamage: incoming,
      requiredAgilitySuccesses: _statDice(player, state, StatType.agility),
      targetPlayerId: playerId,
      counterAttackMonsterInstanceId: monster.instanceId,
    ),
    logEntry: 'event-monster-attack:${monster.instanceId}:$playerId:$incoming',
  );
}

GameState _startImmediateCounterAttack(
  GameState state,
  PlayerId playerId,
  MonsterInstance monster,
  DiceRoller dice,
) {
  final player = _playerById(state, playerId);
  final target = _monsterById(state, monster.instanceId);
  if (player == null || !player.alive || target == null) {
    return _resumeAutomaticPhase(state);
  }
  final hooks = _activeEffectHooks(state, player);
  final preAttackHooks = hooks.whereType<PreAttackDamageHook>();
  final preAttackDamage = preAttackHooks.isEmpty
      ? 0
      : const EffectEngine()
            .resolvePreAttackRoll(dice.rollDice(1), preAttackHooks)
            .targetDamage;
  final diceRoll = dice.rollDice(
    _heroAttackDice(player, state, target: monster),
  );
  final roll = const EffectEngine().resolveRoll(diceRoll, hooks);
  final rerollSources = _attackRerollSources(
    state,
    player,
    roll.rerollsAvailable,
  );
  if (rerollSources.isNotEmpty) {
    return _copyState(
      state,
      pendingDecision: AwaitingRerollChoice(
        dice: diceRoll,
        availableRerolls: rerollSources.length,
        maxDicePerReroll: _maxDicePerReroll(state, rerollSources.first),
        rerollSources: rerollSources,
        window: const DecisionWindow(remainingTicks: 1),
        context: AttackRollContext(
          playerId: playerId,
          targetInstanceId: monster.instanceId,
          preAttackDamage: preAttackDamage,
          resumeAutomaticPhase: true,
        ),
      ),
      logEntry: 'event-counterattack-roll:$playerId:${monster.instanceId}',
    );
  }
  return _resumeAutomaticPhase(
    _resolveAttackRoll(
      state,
      playerId,
      monster.instanceId,
      diceRoll,
      consumesAction: false,
      preAttackDamage: preAttackDamage,
    ),
  );
}

GameState _completeRoll(
  GameState state,
  AwaitingRerollChoice pending,
  DiceRoller dice,
) {
  final context = pending.context;
  if (context == null) return _resumeAutomaticPhase(state);
  if (context case AttackRollContext()) {
    final resolved = _resolveAttackRoll(
      state,
      context.playerId,
      context.targetInstanceId,
      pending.dice,
      consumesAction: false,
      preAttackDamage: context.preAttackDamage,
      bonusHits: context.bonusHits,
    );
    return context.resumeAutomaticPhase
        ? _resumeAutomaticPhase(resolved)
        : resolved;
  }
  if (context is! SkillCheckContext) return _resumeAutomaticPhase(state);
  final succeeded = countHits(pending.dice) >= context.difficulty;
  if (context.eventId != null && context.eventOptionIndex != null) {
    final definition = state.eventDefinitions[context.eventId];
    if (definition != null) {
      return _resumeAutomaticPhase(
        _resolveEventOutcome(
          state,
          definition,
          context.playerId,
          context.eventOptionIndex!,
          succeeded: succeeded,
          dice: dice,
        ),
      );
    }
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

bool _ignoresAnyDamage(GameState state, PlayerState player) =>
    player.damageImmuneThroughRound != null &&
    state.round <= player.damageImmuneThroughRound!;

/// Applies the machine-readable consequences attached to a verified event
/// branch. An unmapped outcome is recorded for the journal and left visible in
/// the coverage registry; consequences are never guessed from prose.
GameState _resolveEventOutcome(
  GameState state,
  Map<String, Object?> definition,
  PlayerId playerId,
  int optionIndex, {
  required bool succeeded,
  required DiceRoller dice,
}) {
  final rawEventId = definition['id'];
  final eventId = rawEventId is String ? rawEventId : 'unknown-event';
  final rawOptions = definition['options'];
  if (rawOptions is! List<Object?> ||
      optionIndex < 1 ||
      optionIndex > rawOptions.length) {
    return state;
  }
  final rawOption = rawOptions[optionIndex - 1];
  if (rawOption is! Map<String, dynamic>) return state;
  final outcomeName = succeeded ? 'success' : 'failure';
  final resolvedState = _copyState(
    state,
    logEntry: 'event-result:${definition['id']}:$optionIndex:$outcomeName',
  );
  final rawEffects = rawOption[succeeded ? 'successEffects' : 'failureEffects'];
  if (rawEffects is! List<Object?>) return resolvedState;
  var current = resolvedState;
  for (final rawEffect in rawEffects) {
    if (rawEffect is! Map<String, dynamic>) continue;
    final amount = rawEffect['amount'] is int ? rawEffect['amount']! as int : 0;
    final player = _playerById(current, playerId);
    if (player == null || !player.alive) continue;
    switch (rawEffect['type']) {
      case 'no_effect':
        continue;
      case 'seal_monster_access':
        current = _copyState(
          current,
          board: [
            for (final tile in current.board)
              if (tile.coord == player.coord)
                _copyTile(tile, monsterAccessBlocked: true)
              else
                tile,
          ],
          logEntry: 'event-door-welded:${player.coord}',
        );
      case 'asteroid_alert':
        final corridors = current.board
            .where((tile) => tile.type == HexTileType.corridor)
            .map((tile) => tile.coord)
            .toSet();
        var damaged = current;
        final corridorHeroes = current.players
            .where((hero) => hero.alive && corridors.contains(hero.coord))
            .toList();
        for (final hero in corridorHeroes) {
          final rolled = dice.rollDice(1).single;
          final ignoresDamage = _ignoresAnyDamage(damaged, hero);
          damaged = _copyState(
            damaged,
            players: _replacePlayer(
              damaged,
              hero.id,
              (currentHero) => _copyPlayer(
                currentHero,
                damage: currentHero.damage + (ignoresDamage ? 0 : rolled),
              ),
            ),
            logEntry: ignoresDamage
                ? 'event-asteroid-damage-ignored:${hero.id}:$rolled'
                : 'event-asteroid-damage:${hero.id}:$rolled',
          );
        }
        damaged = resolveHeroDeaths(damaged);
        final closedBoard = [
          for (final tile in damaged.board)
            if (tile.type == HexTileType.corridor)
              _copyTile(tile, isBlocked: true)
            else
              tile,
        ];
        final movedPlayers = [
          for (final hero in damaged.players)
            if (corridors.contains(hero.coord) && hero.alive)
              _copyPlayer(
                hero,
                coord:
                    _eventDisplacementTarget(damaged, hero.coord) ?? hero.coord,
              )
            else
              hero,
        ];
        final movedMonsters = <MonsterInstance>[];
        final arrivingMonsters = <MonsterInstance>[];
        for (final monster in damaged.monsters) {
          if (!corridors.contains(monster.coord)) {
            movedMonsters.add(monster);
            continue;
          }
          final destination =
              _eventDisplacementTarget(damaged, monster.coord) ?? monster.coord;
          final moved = _copyMonster(monster, coord: destination);
          movedMonsters.add(moved);
          if (destination != monster.coord) arrivingMonsters.add(moved);
        }
        current = _copyState(
          damaged,
          board: closedBoard,
          players: movedPlayers,
          monsters: movedMonsters,
          logEntry: 'event-asteroid-corridors-closed',
        );
        for (final monster in arrivingMonsters) {
          current = _resolveTripwireArrival(current, monster);
        }
        current = resolveColocation(current);
      case 'destroy_nest':
        final nests = current.monsters
            .where(
              (monster) =>
                  monster.monsterId == 'nest' && monster.coord == player.coord,
            )
            .toList();
        if (nests.isNotEmpty) {
          final monsterDeck = current.decks['monsters'];
          final decks = Map<DeckId, DeckState>.of(current.decks);
          if (monsterDeck != null) {
            decks['monsters'] = DeckState(
              drawPile: monsterDeck.drawPile,
              discardPile: [
                ...monsterDeck.discardPile,
                for (final nest in nests) nest.monsterId,
              ],
            );
          }
          current = _copyState(
            current,
            decks: decks,
            monsters: current.monsters.where(
              (monster) => !nests.contains(monster),
            ),
            logEntry: 'event-nest-destroyed:${player.coord}',
          );
        }
      case 'discard_card_type':
        final typeName = rawEffect['itemType'];
        if (typeName is! String) continue;
        final matching = _ownedMarketCards(player)
            .where(
              (cardId) =>
                  current.cardDefinitions[cardId]?.type.name == typeName,
            )
            .toSet();
        if (matching.isNotEmpty) {
          return _copyState(
            current,
            pendingDecision: AwaitingEventOption(
              options: matching.map((cardId) => 'discard|$cardId'),
              playerId: playerId,
              eventId: definition['id'] as String?,
            ),
          );
        }
      case 'horde_backpack_choice':
        if (player.backpack.isEmpty) continue;
        return _copyState(
          current,
          pendingDecision: AwaitingEventOption(
            options: const ['horde|discard', 'horde|keep'],
            playerId: playerId,
            eventId: eventId,
          ),
        );
      case 'monster_damage_immunity':
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(
              hero,
              monsterDamageImmuneThroughRound: current.round + 1,
            ),
          ),
          logEntry: 'event-monster-immunity:$playerId:${current.round + 1}',
        );
      case 'discard_equipped':
        final slot = rawEffect['slot'];
        final cardId = switch (slot) {
          'robot' => player.equipped.robot,
          'weapon' => player.equipped.weapon,
          'armor' => player.equipped.armor,
          'clothing' => player.equipped.clothing,
          _ => null,
        };
        if (cardId == null) continue;
        final card = current.cardDefinitions[cardId];
        if (card == null) continue;
        final deckId = _cardSourceDeck(current, card);
        final deck = deckId == null ? null : current.decks[deckId];
        final decks = Map<DeckId, DeckState>.of(current.decks);
        if (deckId != null && deck != null) {
          decks[deckId] = DeckState(
            drawPile: deck.drawPile,
            discardPile: [...deck.discardPile, cardId],
          );
        }
        current = _copyState(
          current,
          decks: decks,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _removeOwnedMarketCard(hero, cardId),
          ),
          logEntry: 'event-discard:$playerId:$cardId',
        );
      case 'discard_card_id':
        final cardId = rawEffect['cardId'];
        final deckId = rawEffect['deckId'];
        if (cardId is! String ||
            deckId is! String ||
            !_ownedMarketCards(player).contains(cardId)) {
          continue;
        }
        final deck = current.decks[deckId];
        final decks = Map<DeckId, DeckState>.of(current.decks);
        if (deck != null) {
          decks[deckId] = DeckState(
            drawPile: deck.drawPile,
            discardPile: [...deck.discardPile, cardId],
          );
        }
        current = _copyState(
          current,
          decks: decks,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _removeOwnedMarketCard(hero, cardId),
          ),
          logEntry: 'event-discard:$playerId:$cardId',
        );
      case 'market':
        final count = rawEffect['offers'] is int
            ? rawEffect['offers']! as int
            : 0;
        final deck = current.decks['supplies'];
        final draw = deck == null || count == 0
            ? null
            : DeckRules.draw(
                deck,
                count: count,
                seed: _deckSeed(
                  current,
                  'event-market:${definition['id']}:$optionIndex',
                ),
              );
        if (deck != null && draw != null && draw.cards.isNotEmpty) {
          current = _copyState(
            current,
            decks: Map<DeckId, DeckState>.of(current.decks)
              ..['supplies'] = draw.deck,
          );
        }
        final marketOptions = _eventMarketOptions(
          current,
          playerId,
          eventId: eventId,
          optionIndex: optionIndex,
          offers: draw?.cards ?? const <String>[],
          remainingPurchases: rawEffect['maxPurchases'] is int
              ? rawEffect['maxPurchases']! as int
              : 0,
          discount: rawEffect['discount'] is int
              ? rawEffect['discount']! as int
              : 0,
          allowSell: rawEffect['allowSell'] == true,
        );
        if (marketOptions.isNotEmpty) {
          return _copyState(
            current,
            pendingDecision: AwaitingEventOption(
              options: marketOptions,
              playerId: playerId,
              eventId: eventId,
            ),
          );
        }
      case 'heal':
        final conditionDeck = current.decks['conditions'];
        final decks = Map<DeckId, DeckState>.of(current.decks);
        if (conditionDeck != null && player.conditions.isNotEmpty) {
          decks['conditions'] = DeckState(
            drawPile: conditionDeck.drawPile,
            discardPile: [...conditionDeck.discardPile, ...player.conditions],
          );
        }
        current = _copyState(
          current,
          decks: decks,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(
              hero,
              damage: (hero.damage - amount).clamp(0, hero.health),
              conditions: const [],
            ),
          ),
          logEntry: 'event-heal:$playerId:$amount',
        );
      case 'heal_all':
        final conditionDeck = current.decks['conditions'];
        final decks = Map<DeckId, DeckState>.of(current.decks);
        if (conditionDeck != null && player.conditions.isNotEmpty) {
          decks['conditions'] = DeckState(
            drawPile: conditionDeck.drawPile,
            discardPile: [...conditionDeck.discardPile, ...player.conditions],
          );
        }
        current = _copyState(
          current,
          decks: decks,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(
              hero,
              damage: 0,
              conditions: const [],
            ),
          ),
          logEntry: 'event-heal-all:$playerId',
        );
      case 'ready_robots':
        current = _copyState(
          current,
          players: [
            for (final hero in current.players)
              _copyPlayer(hero, exhaustedRobots: const <CardId>[]),
          ],
          logEntry: 'event-robots-ready:$playerId',
        );
      case 'damage':
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _ignoresAnyDamage(current, hero)
                ? hero
                : _copyPlayer(hero, damage: hero.damage + amount),
          ),
          logEntry: 'event-damage:$playerId:$amount',
        );
        current = resolveHeroDeaths(current);
      case 'damage_all_players':
        current = _copyState(
          current,
          players: [
            for (final hero in current.players)
              if (hero.alive && !_ignoresAnyDamage(current, hero))
                _copyPlayer(hero, damage: hero.damage + amount)
              else
                hero,
          ],
          logEntry: 'event-damage-all:$amount',
        );
        current = resolveHeroDeaths(current);
      case 'damage_roll_die':
        final rolledDamage = dice.rollDice(1).single;
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _ignoresAnyDamage(current, hero)
                ? hero
                : _copyPlayer(hero, damage: hero.damage + rolledDamage),
          ),
          logEntry: 'event-damage-roll:$playerId:$rolledDamage',
        );
        current = resolveHeroDeaths(current);
      case 'damage_each_player_roll_die':
        final living = current.players.where((hero) => hero.alive).toList();
        final rolls = dice.rollDice(living.length);
        var rollIndex = 0;
        current = _copyState(
          current,
          players: current.players.map((hero) {
            if (!hero.alive) return hero;
            final rolledDamage = rolls[rollIndex++];
            return _copyPlayer(
              hero,
              damage:
                  hero.damage +
                  (_ignoresAnyDamage(current, hero) ? 0 : rolledDamage),
            );
          }),
          logEntry: 'event-damage-each-roll:${rolls.join(',')}',
        );
        current = resolveHeroDeaths(current);
      case 'credits':
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(hero, credits: hero.credits + amount),
          ),
          logEntry: 'event-credits:$playerId:$amount',
        );
      case 'stat_bonus':
        final statName = rawEffect['stat'];
        if (statName is! String) continue;
        final stat = StatType.values.byName(statName);
        final retainEventCard = rawEffect['retainEventCard'] == true;
        final retainedEventDecks = Map<DeckId, DeckState>.of(current.decks);
        if (retainEventCard) {
          final eventDeck = retainedEventDecks['events'];
          if (eventDeck != null) {
            final discardPile = List<CardId>.of(eventDeck.discardPile);
            if (discardPile.remove(eventId)) {
              retainedEventDecks['events'] = DeckState(
                drawPile: eventDeck.drawPile,
                discardPile: discardPile,
              );
            }
          }
        }
        current = _copyState(
          current,
          decks: retainedEventDecks,
          players: _replacePlayer(current, playerId, (hero) {
            final stats = hero.stats;
            return _copyPlayer(
              hero,
              retainedEventCards: retainEventCard
                  ? [...hero.retainedEventCards, eventId]
                  : null,
              stats: PlayerStats(
                strength:
                    stats.strength + (stat == StatType.strength ? amount : 0),
                combatStrength:
                    stats.combatStrength +
                    (stat == StatType.combatStrength ? amount : 0),
                science:
                    stats.science + (stat == StatType.science ? amount : 0),
                repair: stats.repair + (stat == StatType.repair ? amount : 0),
                endurance:
                    stats.endurance + (stat == StatType.endurance ? amount : 0),
                agility:
                    stats.agility + (stat == StatType.agility ? amount : 0),
              ),
            );
          }),
          logEntry: 'event-stat-bonus:$playerId:$statName:$amount',
        );
      case 'next_turn_action_delta':
        final delta = rawEffect['delta'];
        if (delta is! int || delta == 0) continue;
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(
              hero,
              nextTurnActionDelta: hero.nextTurnActionDelta + delta,
            ),
          ),
          logEntry: 'event-next-turn-actions:$playerId:$delta',
        );
      case 'monster_defense_bonus_next_round':
        current = _copyState(
          current,
          players: _replacePlayer(
            current,
            playerId,
            (hero) => _copyPlayer(
              hero,
              monsterDefenseBonusRound: current.round + 1,
            ),
          ),
          logEntry: 'event-monster-defense-next-round:$playerId',
        );
      case 'draw':
        final deckId = rawEffect['deckId'];
        final deck = deckId is String ? current.decks[deckId] : null;
        if (deck == null || amount < 1) continue;
        final targetDeckId = deckId! as DeckId;
        final outcome = succeeded ? 'success' : 'failure';
        final draw = DeckRules.draw(
          deck,
          count: amount,
          seed: _deckSeed(
            current,
            'event-outcome:$eventId:$optionIndex:$outcome',
          ),
        );
        if (draw.cards.isEmpty) continue;
        final updatedDecks = Map<DeckId, DeckState>.of(current.decks)
          ..[targetDeckId] = draw.deck;
        final returned = <CardId>[];
        var receivedPlayer = player;
        for (final cardId in draw.cards) {
          try {
            receivedPlayer = InventoryRules.receive(
              receivedPlayer,
              cardId,
              current.cardDefinitions,
            );
          } on Object catch (error) {
            if (error is! BackpackCapacityExceeded &&
                error is! InventoryRuleViolation) {
              rethrow;
            }
            returned.add(cardId);
          }
        }
        if (returned.isNotEmpty) {
          updatedDecks[targetDeckId] = DeckRules.returnAndShuffle(
            updatedDecks[targetDeckId]!,
            returned,
            seed: _deckSeed(current, 'event-overflow:${definition['id']}'),
          );
        }
        final cardsKept = draw.cards.length - returned.length;
        current = _copyState(
          current,
          decks: updatedDecks,
          players: _replacePlayer(
            current,
            playerId,
            (_) => receivedPlayer,
          ),
          logEntry: 'event-draw:$playerId:$targetDeckId:$cardsKept',
        );
      case 'draw_supplies_all_players':
        for (final recipientId
            in current.players
                .where((hero) => hero.alive)
                .map((hero) => hero.id)
                .toList()) {
          final supplyDeck = current.decks['supplies'];
          if (supplyDeck == null || amount < 1) break;
          final recipient = _playerById(current, recipientId)!;
          final backpackCapacity = InventoryRules.backpackCapacity(
            recipient,
            current.cardDefinitions,
          );
          final draw = DeckRules.draw(
            supplyDeck,
            count: amount,
            seed: _deckSeed(
              current,
              'event-team-supplies:$eventId:$optionIndex:$recipientId',
            ),
          );
          final backpack = List<CardId>.of(recipient.backpack);
          final returned = <CardId>[];
          for (final cardId in draw.cards) {
            if (backpack.length < backpackCapacity) {
              backpack.add(cardId);
            } else {
              returned.add(cardId);
            }
          }
          final nextSupplyDeck = returned.isEmpty
              ? draw.deck
              : DeckRules.returnAndShuffle(
                  draw.deck,
                  returned,
                  seed: _deckSeed(
                    current,
                    'event-team-overflow:${definition['id']}:$recipientId',
                  ),
                );
          final cardsKept = draw.cards.length - returned.length;
          current = _copyState(
            current,
            decks: Map<DeckId, DeckState>.of(current.decks)
              ..['supplies'] = nextSupplyDeck,
            players: _replacePlayer(
              current,
              recipientId,
              (hero) => _copyPlayer(hero, backpack: backpack),
            ),
            logEntry: 'event-team-supplies:$recipientId:$cardsKept',
          );
        }
      case 'choose_from_top':
        final deckId = rawEffect['deckId'];
        final deck = deckId is String ? current.decks[deckId] : null;
        if (deck == null || amount < 1) continue;
        final draw = DeckRules.draw(
          deck,
          count: amount,
          seed: _deckSeed(
            current,
            'event-choose:${definition['id']}:$optionIndex:$deckId',
          ),
        );
        if (draw.cards.isEmpty) continue;
        final targetDeckId = deckId! as DeckId;
        return _copyState(
          current,
          decks: Map<DeckId, DeckState>.of(current.decks)
            ..[targetDeckId] = draw.deck,
          pendingDecision: AwaitingEventOption(
            options: draw.cards.map(
              (cardId) => _eventPickOption(targetDeckId, cardId),
            ),
            playerId: playerId,
            eventId: definition['id'] as String?,
          ),
        );
      case 'draw_filtered':
        final deckId = rawEffect['deckId'];
        final filterType = rawEffect['filterType'];
        final deck = deckId is String ? current.decks[deckId] : null;
        if (deck == null || filterType is! String) continue;
        final targetDeckId = deckId! as DeckId;
        final filtered = _drawEventFilteredCard(
          current,
          targetDeckId,
          filterType,
          seed: _deckSeed(
            current,
            'event-filtered:${definition['id']}:$optionIndex:$filterType',
          ),
        );
        if (filtered == null) continue;
        var receivedPlayer = player;
        var updatedDeck = filtered.deck;
        try {
          receivedPlayer = InventoryRules.receive(
            player,
            filtered.cardId,
            current.cardDefinitions,
          );
        } on Object catch (error) {
          if (error is! BackpackCapacityExceeded &&
              error is! InventoryRuleViolation) {
            rethrow;
          }
          updatedDeck = DeckRules.returnAndShuffle(
            updatedDeck,
            [filtered.cardId],
            seed: _deckSeed(
              current,
              'event-filtered-overflow:${definition['id']}',
            ),
          );
        }
        current = _copyState(
          current,
          decks: Map<DeckId, DeckState>.of(current.decks)
            ..[targetDeckId] = updatedDeck,
          players: _replacePlayer(
            current,
            playerId,
            (_) => receivedPlayer,
          ),
          logEntry: 'event-draw-filtered:$playerId:$targetDeckId:$filterType',
        );
      case 'draw_specific':
        final deckId = rawEffect['deckId'];
        final cardId = rawEffect['cardId'];
        final deck = deckId is String ? current.decks[deckId] : null;
        if (deck == null || cardId is! String) continue;
        final targetDeckId = deckId! as DeckId;
        final draw = DeckRules.drawSpecific(
          deck,
          cardId,
          seed: _deckSeed(
            current,
            'event-specific:${definition['id']}:$cardId',
          ),
        );
        if (draw.cards.isEmpty) continue;
        final updatedDecks = Map<DeckId, DeckState>.of(current.decks)
          ..[targetDeckId] = draw.deck;
        var receivedPlayer = player;
        try {
          receivedPlayer = InventoryRules.receive(
            player,
            cardId,
            current.cardDefinitions,
          );
        } on Object catch (error) {
          if (error is! BackpackCapacityExceeded &&
              error is! InventoryRuleViolation) {
            rethrow;
          }
          updatedDecks[targetDeckId] = DeckRules.returnAndShuffle(
            updatedDecks[targetDeckId]!,
            [cardId],
            seed: _deckSeed(
              current,
              'event-specific-overflow:${definition['id']}',
            ),
          );
        }
        current = _copyState(
          current,
          decks: updatedDecks,
          players: _replacePlayer(
            current,
            playerId,
            (_) => receivedPlayer,
          ),
          logEntry: 'event-draw-specific:$playerId:$cardId',
        );
      case 'spawn_monster':
        final monsterDeck = current.decks['monsters'];
        if (monsterDeck == null) continue;
        final monsterId = rawEffect['monsterId'];
        final draw = monsterId is String
            ? DeckRules.drawSpecific(
                monsterDeck,
                monsterId,
                seed: _deckSeed(
                  current,
                  'event-monster:${definition['id']}:$optionIndex:$playerId',
                ),
              )
            : DeckRules.draw(
                monsterDeck,
                seed: _deckSeed(
                  current,
                  'event-monster:${definition['id']}:$optionIndex:$playerId',
                ),
              );
        if (draw.cards.isEmpty) continue;
        final drawnMonsterId = draw.cards.single;
        final monsterDefinition = current.monsterDefinitions[drawnMonsterId];
        if (monsterDefinition == null) continue;
        final coord = player.coord;
        final instanceId =
            'event-${current.round}-${current.eventTurnIndex}-'
            '$eventId-$optionIndex-$drawnMonsterId';
        final monster = MonsterInstance(
          instanceId: instanceId,
          monsterId: drawnMonsterId,
          coord: coord,
          damage: 0,
          health: _scaledMonsterStat(current, monsterDefinition, 'health'),
          defense: monsterDefinition['defense']! as int,
          attack: _scaledMonsterStat(current, monsterDefinition, 'attack'),
          movement: monsterDefinition['movement']! as int,
          returnsToMonsterDeck: true,
          defeatRewardDeckId: rawEffect['defeatRewardDeckId'] as String?,
        );
        final decks = Map<DeckId, DeckState>.of(current.decks)
          ..['monsters'] = draw.deck;
        current = _copyState(
          current,
          monsters: [...current.monsters, monster],
          decks: decks,
          logEntry:
              'event-monster-spawn:${definition['id']}:$drawnMonsterId:$coord',
        );
        current = _resolveTripwireArrival(current, monster);
        final survivingMonster = _monsterById(current, monster.instanceId);
        if (survivingMonster != null && rawEffect['immediateCombat'] != false) {
          current = _startImmediateMonsterAttack(
            current,
            playerId,
            survivingMonster,
            dice,
          );
        }
      case 'spawn_monster_adjacent':
        final placementTargets = current.board
            .where(
              (tile) =>
                  tile.opened &&
                  !tile.isBlocked &&
                  player.coord.distanceTo(tile.coord) == 1,
            )
            .toList();
        if (placementTargets.isEmpty) continue;
        final monsterDeck = current.decks['monsters'];
        if (monsterDeck == null) continue;
        final draw = DeckRules.draw(
          monsterDeck,
          seed: _deckSeed(
            current,
            'event-monster-adjacent:${definition['id']}:$optionIndex:$playerId',
          ),
        );
        if (draw.cards.isEmpty) continue;
        final monsterId = draw.cards.single;
        final monsterDefinition = current.monsterDefinitions[monsterId];
        if (monsterDefinition == null) continue;
        final instanceId =
            'event-${current.round}-${current.eventTurnIndex}-'
            '$eventId-$optionIndex-$monsterId';
        final monster = MonsterInstance(
          instanceId: instanceId,
          monsterId: monsterId,
          coord: player.coord,
          damage: 0,
          health: _scaledMonsterStat(current, monsterDefinition, 'health'),
          defense: monsterDefinition['defense']! as int,
          attack: _scaledMonsterStat(current, monsterDefinition, 'attack'),
          movement: monsterDefinition['movement']! as int,
          returnsToMonsterDeck: true,
        );
        final decks = Map<DeckId, DeckState>.of(current.decks)
          ..['monsters'] = draw.deck;
        current = _copyState(
          current,
          monsters: [...current.monsters, monster],
          decks: decks,
          logEntry: 'event-monster-drawn:${definition['id']}:$monsterId',
        );
        return _copyState(
          current,
          pendingDecision: AwaitingEventOption(
            options: placementTargets.map(
              (tile) => _eventPlaceOption(monster.instanceId, tile.coord),
            ),
            playerId: playerId,
            eventId: definition['id'] as String?,
          ),
        );
      case 'spawn_monsters_adjacent':
        final placementTargets =
            current.board
                .where(
                  (tile) =>
                      tile.opened &&
                      !tile.isBlocked &&
                      player.coord.distanceTo(tile.coord) == 1,
                )
                .toList()
              ..sort((left, right) {
                final q = left.coord.q.compareTo(right.coord.q);
                return q == 0 ? left.coord.r.compareTo(right.coord.r) : q;
              });
        final monsterDeck = current.decks['monsters'];
        if (placementTargets.isEmpty || monsterDeck == null) continue;
        final draw = DeckRules.draw(
          monsterDeck,
          count: placementTargets.length,
          seed: _deckSeed(
            current,
            'event-monsters-adjacent:${definition['id']}:$optionIndex:'
            '$playerId',
          ),
        );
        if (draw.cards.isEmpty) continue;
        final monsters = <MonsterInstance>[];
        for (var index = 0; index < draw.cards.length; index++) {
          final monsterId = draw.cards[index];
          final monsterDefinition = current.monsterDefinitions[monsterId];
          if (monsterDefinition == null) continue;
          final coord = placementTargets[index].coord;
          monsters.add(
            MonsterInstance(
              instanceId:
                  'event-${current.round}-${current.eventTurnIndex}-'
                  '$eventId-$optionIndex-$index-$monsterId',
              monsterId: monsterId,
              coord: coord,
              damage: 0,
              health: _scaledMonsterStat(current, monsterDefinition, 'health'),
              defense: monsterDefinition['defense']! as int,
              attack: _scaledMonsterStat(current, monsterDefinition, 'attack'),
              movement: monsterDefinition['movement']! as int,
              returnsToMonsterDeck: true,
            ),
          );
        }
        current = _copyState(
          current,
          monsters: [...current.monsters, ...monsters],
          decks: Map<DeckId, DeckState>.of(current.decks)
            ..['monsters'] = draw.deck,
          logEntry:
              'event-monsters-adjacent:${definition['id']}:${monsters.length}',
        );
      case 'move_to_neighbor':
      case 'move_to_neighbor_and_spawn_monster':
        final targets = _eventMoveTargets(current, playerId);
        if (targets.isEmpty) continue;
        final moveAndFight =
            rawEffect['type'] == 'move_to_neighbor_and_spawn_monster';
        return _copyState(
          current,
          pendingDecision: AwaitingEventOption(
            options: targets.map(
              (tile) => moveAndFight
                  ? _eventMoveSpawnOption(optionIndex, tile.coord)
                  : _eventMoveOption(tile.coord),
            ),
            playerId: playerId,
            eventId: definition['id'] as String?,
          ),
        );
      case 'reveal_fragment':
        final candidates = current.board.where((tile) => !tile.opened).toList();
        if (candidates.isEmpty) continue;
        final scope = rawEffect['scope'];
        final targets = scope == 'nearest'
            ? _nearestEventRevealTargets(current, player, candidates)
            : candidates;
        return _copyState(
          current,
          pendingDecision: AwaitingEventOption(
            options: targets.map(
              (tile) => _eventCoordOption('reveal', tile.coord),
            ),
            playerId: playerId,
            eventId: definition['id'] as String?,
          ),
        );
      case 'kill_monster':
        final scope = rawEffect['scope'];
        final requiredMonsterId = rawEffect['monsterId'];
        final candidates = current.monsters.where((monster) {
          if (requiredMonsterId is String &&
              monster.monsterId != requiredMonsterId) {
            return false;
          }
          if (monster.damage >= monster.health) return false;
          final definition = current.monsterDefinitions[monster.monsterId];
          final features = definition?['features'];
          final isBoss = features is List<Object?> && features.contains('boss');
          if (scope == 'any_non_boss' && isBoss) return false;
          if (scope == 'any_non_boss') return true;
          return player.coord.distanceTo(monster.coord) <= 1;
        }).toList();
        if (candidates.isEmpty) continue;
        return _copyState(
          current,
          pendingDecision: AwaitingEventOption(
            options: candidates.map(
              (monster) => 'kill:${monster.instanceId}',
            ),
            playerId: playerId,
            eventId: definition['id'] as String?,
          ),
        );
    }
  }
  return current;
}

HexCoord? _eventDisplacementTarget(GameState state, HexCoord source) {
  final tile = state.tileAt(source);
  if (tile == null) return null;
  final choices =
      tile.exits
          .map((edge) => source.neighbor(edge))
          .map(state.tileAt)
          .whereType<HexTile>()
          .where(
            (candidate) =>
                candidate.opened &&
                !candidate.isBlocked &&
                candidate.type != HexTileType.corridor,
          )
          .toList()
        ..sort((left, right) {
          final q = left.coord.q.compareTo(right.coord.q);
          return q == 0 ? left.coord.r.compareTo(right.coord.r) : q;
        });
  return choices.firstOrNull?.coord;
}

List<String> _eventMarketOptions(
  GameState state,
  PlayerId playerId, {
  required String eventId,
  required int optionIndex,
  required Iterable<String> offers,
  required int remainingPurchases,
  required int discount,
  required bool allowSell,
}) {
  final offered = offers.toList();
  final hero = _playerById(state, playerId);
  if (hero == null) return const [];
  String token(String action, [String cardId = '']) =>
      'market|$eventId|$optionIndex|$remainingPurchases|$discount|'
      '${offered.join(',')}|${allowSell ? 1 : 0}|$action|$cardId';
  return [
    if (remainingPurchases > 0)
      for (var index = 0; index < offered.length; index++)
        for (final cardId in [offered[index]])
          if (state.cardDefinitions[cardId] case final definition?
              when hero.credits >= (definition.cost - discount).clamp(0, 999))
            token('buy', '$index:$cardId'),
    if (allowSell)
      for (final cardId in _ownedMarketCards(hero))
        if (state.cardDefinitions[cardId] case final definition?
            when _cardSourceDeck(state, definition) != null)
          token('sell', cardId),
    token('done'),
  ];
}

GameStepResult _resolveEventMarketChoice(
  GameState state,
  AwaitingEventOption pending,
  PlayerId playerId,
  String option,
) {
  final parts = option.split('|');
  if (parts.length != 9 || parts[0] != 'market') {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final eventId = parts[1];
  final optionIndex = int.tryParse(parts[2]);
  final remainingPurchases = int.tryParse(parts[3]);
  final discount = int.tryParse(parts[4]);
  final offers = parts[5].isEmpty ? <String>[] : parts[5].split(',');
  final allowSell = parts[6] == '1';
  final action = parts[7];
  final targetParts = parts[8].split(':');
  final offerIndex = action == 'buy' && targetParts.length == 2
      ? int.tryParse(targetParts[0])
      : null;
  final targetCardId = action == 'buy' && targetParts.length == 2
      ? targetParts[1]
      : parts[8];
  if (optionIndex == null ||
      remainingPurchases == null ||
      discount == null ||
      !pending.options.contains(option) ||
      pending.eventId != eventId) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  final hero = _playerById(state, playerId);
  if (hero == null) {
    return GameStepResult(
      state: state,
      rejection: const ActionBlockedByPendingDecision(),
    );
  }
  if (action == 'done') {
    final decks = Map<DeckId, DeckState>.of(state.decks);
    final supply = decks['supplies'];
    if (supply != null && offers.isNotEmpty) {
      decks['supplies'] = DeckRules.returnAndShuffle(
        supply,
        offers,
        seed: _deckSeed(state, 'event-market-return:$eventId:$optionIndex'),
      );
    }
    return GameStepResult(
      state: _resumeAutomaticPhase(
        _copyState(
          state,
          decks: decks,
          clearPendingDecision: true,
          logEntry: 'event-market-done:$playerId:$eventId',
        ),
      ),
    );
  }
  if (action == 'buy') {
    final definition = state.cardDefinitions[targetCardId];
    if (remainingPurchases < 1 ||
        offerIndex == null ||
        offerIndex < 0 ||
        offerIndex >= offers.length ||
        offers[offerIndex] != targetCardId ||
        definition == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final cost = (definition.cost - discount).clamp(0, 999);
    if (hero.credits < cost) {
      return GameStepResult(
        state: state,
        rejection: const InventoryCommandRejected('Недостаточно кредитов.'),
      );
    }
    PlayerState received;
    try {
      received = InventoryRules.receive(
        hero,
        targetCardId,
        state.cardDefinitions,
      );
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
    final remainingOffers = List<String>.of(offers)..removeAt(offerIndex);
    final purchased = _copyState(
      state,
      players: _replacePlayer(
        state,
        playerId,
        (current) => _copyPlayer(
          received,
          credits: current.credits - cost,
        ),
      ),
    );
    final nextOptions = _eventMarketOptions(
      purchased,
      playerId,
      eventId: eventId,
      optionIndex: optionIndex,
      offers: remainingOffers,
      remainingPurchases: remainingPurchases - 1,
      discount: discount,
      allowSell: allowSell,
    );
    return GameStepResult(
      state: _copyState(
        purchased,
        pendingDecision: AwaitingEventOption(
          options: nextOptions,
          playerId: playerId,
          eventId: eventId,
        ),
        logEntry: 'event-market-buy:$playerId:$targetCardId:$cost',
      ),
    );
  }
  if (action == 'sell' &&
      allowSell &&
      _ownedMarketCards(hero).contains(targetCardId)) {
    final definition = state.cardDefinitions[targetCardId];
    if (definition == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final sold = _removeOwnedMarketCard(hero, targetCardId);
    final deckId = _cardSourceDeck(state, definition);
    if (deckId == null) {
      return GameStepResult(
        state: state,
        rejection: const ActionBlockedByPendingDecision(),
      );
    }
    final decks = Map<DeckId, DeckState>.of(state.decks);
    final deck = decks[deckId];
    if (deck != null) {
      decks[deckId] = DeckState(
        drawPile: deck.drawPile,
        discardPile: [...deck.discardPile, targetCardId],
      );
    }
    final soldState = _copyState(
      state,
      decks: decks,
      players: _replacePlayer(
        state,
        playerId,
        (current) => _copyPlayer(
          sold,
          credits: current.credits + definition.cost,
        ),
      ),
    );
    final nextOptions = _eventMarketOptions(
      soldState,
      playerId,
      eventId: eventId,
      optionIndex: optionIndex,
      offers: offers,
      remainingPurchases: remainingPurchases,
      discount: discount,
      allowSell: allowSell,
    );
    return GameStepResult(
      state: _copyState(
        soldState,
        pendingDecision: AwaitingEventOption(
          options: nextOptions,
          playerId: playerId,
          eventId: eventId,
        ),
        logEntry:
            'event-market-sell:$playerId:$targetCardId:${definition.cost}',
      ),
    );
  }
  return GameStepResult(
    state: state,
    rejection: const ActionBlockedByPendingDecision(),
  );
}

List<String> _ownedMarketCards(PlayerState player) => [
  ...player.backpack,
  ...player.equipped.weapons,
  if (player.equipped.armor != null) player.equipped.armor!,
  if (player.equipped.clothing != null) player.equipped.clothing!,
  if (player.equipped.robot != null) player.equipped.robot!,
  ...player.carriedMods,
];

DeckId? _cardSourceDeck(GameState state, CardDefinition definition) {
  final sourceDeck = definition.sourceDeck;
  if (sourceDeck == 'starterItems') return null;
  if (sourceDeck != null &&
      const {'items', 'supplies', 'specialItems'}.contains(sourceDeck) &&
      state.decks.containsKey(sourceDeck)) {
    return sourceDeck;
  }
  return switch (definition.type) {
    ItemType.supply => 'supplies',
    ItemType.specialItem => 'specialItems',
    _ => 'items',
  };
}

PlayerState _removeOwnedMarketCard(PlayerState player, String cardId) {
  final backpack = List<String>.of(player.backpack);
  final mods = List<String>.of(player.carriedMods);
  final weapons = List<String>.of(player.equipped.weapons);
  final removedBackpack = backpack.remove(cardId);
  final removedMod = !removedBackpack && mods.remove(cardId);
  var gear = player.equipped;
  if (!removedBackpack && !removedMod) {
    if (weapons.remove(cardId)) {
      gear = EquippedGear.withWeapons(
        weapons: weapons,
        armor: gear.armor,
        clothing: gear.clothing,
        robot: gear.robot,
      );
    } else if (gear.armor == cardId) {
      gear = EquippedGear.withWeapons(
        weapons: weapons,
        clothing: gear.clothing,
        robot: gear.robot,
      );
    } else if (gear.clothing == cardId) {
      gear = EquippedGear.withWeapons(
        weapons: weapons,
        armor: gear.armor,
        robot: gear.robot,
      );
    } else if (gear.robot == cardId) {
      gear = EquippedGear.withWeapons(
        weapons: weapons,
        armor: gear.armor,
        clothing: gear.clothing,
      );
    }
  }
  return _copyPlayer(
    player,
    backpack: backpack,
    carriedMods: mods,
    equipped: gear,
  );
}

String _eventMoveOption(HexCoord coord) => 'move:${coord.q}:${coord.r}';

String _eventMoveSpawnOption(int optionIndex, HexCoord coord) =>
    'move_spawn:$optionIndex:${coord.q}:${coord.r}';

String _eventPlaceOption(String instanceId, HexCoord coord) =>
    'place:$instanceId:${coord.q}:${coord.r}';

String _eventPickOption(DeckId deckId, CardId cardId) => 'pick:$deckId:$cardId';

String _eventCoordOption(String action, HexCoord coord) =>
    '$action:${coord.q}:${coord.r}';

HexCoord? _parseEventCoordChoice(String option, String action) {
  final parts = option.split(':');
  if (parts.length != 3 || parts.first != action) return null;
  final q = int.tryParse(parts[1]);
  final r = int.tryParse(parts[2]);
  return q == null || r == null ? null : HexCoord(q, r);
}

List<HexTile> _nearestEventRevealTargets(
  GameState state,
  PlayerState player,
  List<HexTile> candidates,
) {
  final nearestDistance = candidates
      .map((tile) => tile.coord.distanceTo(player.coord))
      .reduce((left, right) => left < right ? left : right);
  return candidates
      .where((tile) => tile.coord.distanceTo(player.coord) == nearestDistance)
      .toList();
}

HexCoord? _parseEventMoveOption(String option) {
  final parts = option.split(':');
  if (parts.length != 3 || parts.first != 'move') return null;
  final q = int.tryParse(parts[1]);
  final r = int.tryParse(parts[2]);
  return q == null || r == null ? null : HexCoord(q, r);
}

List<HexTile> _eventMoveTargets(GameState state, PlayerId playerId) {
  final player = _playerById(state, playerId);
  if (player == null) return const [];
  final source = state.tileAt(player.coord);
  if (source == null || !source.opened || source.isBlocked) return const [];
  return [
    for (final tile in state.board)
      if (tile.opened && !tile.isBlocked)
        if (player.coord.edgeTowardOrNull(tile.coord) case final edge?)
          if (source.hasExit(edge) && tile.hasExit(edge.opposite)) tile,
  ];
}

({CardId cardId, DeckState deck})? _drawEventFilteredCard(
  GameState state,
  DeckId deckId,
  String filterType, {
  required int seed,
}) {
  final initialDeck = state.decks[deckId];
  if (initialDeck == null) return null;
  var deck = initialDeck;
  final skipped = <CardId>[];
  final cardCount = deck.drawPile.length + deck.discardPile.length;
  for (var index = 0; index < cardCount; index++) {
    final draw = DeckRules.draw(deck, seed: seed + index);
    if (draw.cards.isEmpty) return null;
    deck = draw.deck;
    final cardId = draw.cards.single;
    if (state.cardDefinitions[cardId]?.type.name == filterType) {
      if (skipped.isNotEmpty) {
        deck = DeckRules.returnAndShuffle(
          deck,
          skipped,
          seed: seed + cardCount,
        );
      }
      return (cardId: cardId, deck: deck);
    }
    skipped.add(cardId);
  }
  if (skipped.isNotEmpty) {
    deck = DeckRules.returnAndShuffle(deck, skipped, seed: seed + cardCount);
  }
  return null;
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
    if (!transition.progress.completedQuestIds.contains(id) &&
        !transition.progress.isActive(id)) {
      statuses[id] = QuestStatus.discarded;
    }
  }
  for (final id in transition.completedQuestIds) {
    statuses[id] = QuestStatus.completed;
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
  for (final grant in transition.rewards) {
    final count = grant.reward.drawSuppliesPerPlayer;
    if (count == 0) continue;
    for (final playerId
        in players
            .where((player) => player.alive)
            .map((player) => player.id)
            .toList(growable: false)) {
      final supplyDeck = decks['supplies'];
      if (supplyDeck == null) continue;
      final draw = DeckRules.draw(
        supplyDeck,
        count: count,
        seed: _deckSeed(state, 'quest-supplies:${grant.questId}:$playerId'),
      );
      decks['supplies'] = draw.deck;
      var player = players.firstWhere((candidate) => candidate.id == playerId);
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
        decks['supplies'] = DeckRules.returnAndShuffle(
          decks['supplies']!,
          unclaimed,
          seed: _deckSeed(
            state,
            'quest-supplies-return:${grant.questId}:$playerId',
          ),
        );
      }
      players = [
        for (final current in players)
          if (current.id == playerId) player else current,
      ];
    }
  }
  for (final questId in transition.completedQuestIds) {
    for (final effect in graph.quest(questId).completionEffects) {
      if (statuses[effect.questId] != QuestStatus.active) continue;
      players = [
        for (final player in players)
          if (player.alive)
            _copyPlayer(player, damage: player.damage + effect.amount)
          else
            player,
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
  final completedState = _copyState(
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
  var resolved = resolveHeroDeaths(completedState);
  for (final questId in transition.activatedQuestIds) {
    final activated = graph.quest(questId);
    for (final condition in activated.conditions.where(
      (candidate) => candidate.type == QuestConditionType.arrive,
    )) {
      final locationId = condition.locationId;
      if (locationId == null) continue;
      final occupants = resolved.players
          .where(
            (player) =>
                player.alive &&
                resolved.tileAt(player.coord)?.locationId == locationId,
          )
          .map((player) => player.id)
          .toList(growable: false);
      for (final occupantId in occupants) {
        resolved = _applyFullQuestEvent(
          resolved,
          QuestArrived(locationId),
          playerId: occupantId,
        );
      }
    }
  }
  return resolved;
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
  var current = state;
  final activePlayer = _activePlayer(state);
  if (activePlayer != null && activePlayer.nextAttackBonusHits > 0) {
    current = _copyState(
      state,
      players: _replacePlayer(
        state,
        activePlayer.id,
        (player) => _copyPlayer(player, nextAttackBonusHits: 0),
      ),
    );
  }
  final activeIndex = current.players.indexWhere(
    (player) => player.id == current.activePlayerId,
  );
  final nextIndex = _nextLivingPlayerIndex(current.players, activeIndex);
  if (nextIndex == null) {
    if (current.queuedReplacements.isNotEmpty) {
      return _startNextPlayersTurn(
        _copyState(current, actionsLeft: 0, clearActivePlayerId: true),
      );
    }
    return _copyState(current, actionsLeft: 0, clearActivePlayerId: true);
  }
  final lastPlayerOfRound = activeIndex >= 0 && nextIndex <= activeIndex;
  if (lastPlayerOfRound) {
    return _runMonstersTurn(
      _copyState(
        current,
        phase: GamePhase.monstersTurn,
        actionsLeft: 0,
        clearActivePlayerId: true,
        monsterTurnIndex: 0,
        monsterStepsRemaining: 0,
        logEntry: 'players-turn-complete:${current.round}',
      ),
    );
  }
  return _copyState(
    current,
    activePlayerId: current.players[nextIndex].id,
    actionsLeft: current.players[nextIndex].actionPoints,
    actionsTakenThisTurn: 0,
    logEntry: 'end-turn:${current.activePlayerId}',
  );
}
