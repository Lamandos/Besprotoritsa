// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

/// Returns living heroes sorted by a monster's deterministic target priority.
///
/// The path calculation traverses only opened tiles with mutually matching
/// exits.  Equal distances are then broken by current HP and saved player
/// order, which is the turn order of the round.
List<PlayerState> nearestTargets(GameState state, MonsterInstance monster) {
  final distances = _openPathDistances(state, monster, monster.coord);
  final targets =
      state.players
          .where(
            (player) => player.alive && distances.containsKey(player.coord),
          )
          .toList()
        ..sort((left, right) {
          final distanceOrder = distances[left.coord]!.compareTo(
            distances[right.coord]!,
          );
          if (distanceOrder != 0) return distanceOrder;
          final leftHp = _currentHp(left);
          final rightHp = _currentHp(right);
          final hpOrder = leftHp.compareTo(rightHp);
          if (hpOrder != 0) return hpOrder;
          return state.players
              .indexOf(left)
              .compareTo(state.players.indexOf(right));
        });
  return List.unmodifiable(targets);
}

int _currentHp(PlayerState player) => player.health - player.damage;

Map<HexCoord, int> _openPathDistances(
  GameState state,
  MonsterInstance monster,
  HexCoord start,
) {
  final startTile = state.tileAt(start);
  if (startTile == null || !startTile.opened || startTile.isBlocked) {
    return const {};
  }
  final distances = <HexCoord, int>{start: 0};
  final queue = <HexCoord>[start];
  for (var index = 0; index < queue.length; index++) {
    final current = queue[index];
    for (final next in _monsterPathNeighbors(state, monster, current)) {
      if (distances.containsKey(next)) continue;
      distances[next] = distances[current]! + 1;
      queue.add(next);
    }
  }
  return distances;
}

HexCoord? _nextPathStep(
  GameState state,
  MonsterInstance monster,
  HexCoord target,
) {
  final start = monster.coord;
  final distancesToTarget = _openPathDistances(state, monster, target);
  final startDistance = distancesToTarget[start];
  if (startDistance == null || startDistance == 0) return null;
  for (final next in _monsterPathNeighbors(state, monster, start)) {
    if (distancesToTarget[next] == startDistance - 1) {
      return next;
    }
  }
  return null;
}

GameState _runMonstersTurn(GameState state) {
  var current = state;
  while (current.pendingDecision == null) {
    if (current.monsterTurnIndex >= current.monsters.length) {
      return _startEventsPhase(current);
    }
    final monster = current.monsters[current.monsterTurnIndex];
    if (current.monsterStepsRemaining == 0) {
      current = _copyState(
        current,
        monsterStepsRemaining: monster.movement,
      );
      if (monster.movement == 0) {
        current = _copyState(
          current,
          monsterTurnIndex: current.monsterTurnIndex + 1,
        );
        continue;
      }
    }
    final targets = nearestTargets(current, monster);
    final stepTarget = targets.isEmpty
        ? null
        : _nextPathStep(current, monster, targets.first.coord);
    if (stepTarget == null) {
      current = _copyState(
        current,
        monsterTurnIndex: current.monsterTurnIndex + 1,
        monsterStepsRemaining: 0,
      );
      continue;
    }
    current = _copyState(
      current,
      monsterStepsRemaining: current.monsterStepsRemaining - 1,
    );
    current = moveMonsterOneStep(current, monster.instanceId, stepTarget);
    if (!current.monsters.any(
      (candidate) => candidate.instanceId == monster.instanceId,
    )) {
      current = _copyState(current, monsterStepsRemaining: 0);
      if (current.pendingDecision != null) return current;
      continue;
    }
    if (current.pendingDecision != null) return current;
    if (current.monsterStepsRemaining == 0) {
      current = _copyState(
        current,
        monsterTurnIndex: current.monsterTurnIndex + 1,
      );
    }
  }
  return current;
}

GameState _startEventsPhase(GameState state) => _advanceEvents(
  _copyState(
    state,
    phase: GamePhase.eventsPhase,
    eventTurnIndex: 0,
    actionsLeft: 0,
    clearActivePlayerId: true,
    logEntry: 'monsters-turn-complete:${state.round}',
  ),
);

GameState _advanceEvents(GameState state) {
  var current = state;
  while (current.pendingDecision == null) {
    if (current.eventTurnIndex >= current.players.length) {
      return _startNextPlayersTurn(current);
    }
    final player = current.players[current.eventTurnIndex];
    current = _copyState(current, eventTurnIndex: current.eventTurnIndex + 1);
    if (!player.alive || _hasAggressiveMonster(current, player)) continue;
    final eventDeck = current.decks['events'];
    if (eventDeck == null) continue;
    final draw = DeckRules.draw(
      eventDeck,
      seed: _deckSeed(current, 'events'),
    );
    if (draw.cards.isEmpty) continue;
    final eventId = draw.cards.single;
    final eventDefinition = current.eventDefinitions[eventId];
    final rawOptions = eventDefinition?['options'];
    final optionList = rawOptions is List<Object?> ? rawOptions : null;
    final optionCount = optionList?.length ?? 0;
    final options = optionCount > 0
        ? [
            for (var index = 0; index < optionCount; index++)
              if (_eventOptionIsAvailable(player, optionList![index]))
                'option-${index + 1}',
          ]
        : const ['investigate'];
    final decks = Map<DeckId, DeckState>.of(current.decks);
    decks['events'] = DeckState(
      drawPile: draw.deck.drawPile,
      discardPile: [...draw.deck.discardPile, eventId],
    );
    return _copyState(
      current,
      activePlayerId: player.id,
      decks: decks,
      pendingDecision: AwaitingEventOption(
        options: options,
        playerId: player.id,
        eventId: eventId,
      ),
      logEntry: 'event:$eventId:${player.id}',
    );
  }
  return current;
}

bool _hasAggressiveMonster(GameState state, PlayerState player) =>
    state.monsters.any(
      (monster) =>
          monster.coord == player.coord && _monsterIsActive(state, monster),
    );

bool _eventOptionIsAvailable(PlayerState player, Object? rawOption) {
  if (rawOption is! Map<String, dynamic>) return true;
  final requiredCard = rawOption['requiresCard'];
  return requiredCard is! String ||
      _ownedMarketCards(player).contains(requiredCard);
}

bool _monsterIsActive(GameState state, MonsterInstance monster) {
  final activity = state.monsterDefinitions[monster.monsterId]?['activity'];
  if (activity is String) return activity == 'active';
  // Compatibility for legacy saves and isolated callers without content.
  return monster.attack > 0;
}

GameState _startNextPlayersTurn(GameState state) {
  var withReplacements = _activateQueuedReplacements(state);
  for (final playerId in state.queuedReplacements.keys) {
    final player = withReplacements.players
        .where((candidate) => candidate.id == playerId && candidate.alive)
        .firstOrNull;
    final locationId = player == null
        ? null
        : withReplacements.tileAt(player.coord)?.locationId;
    if (locationId != null) {
      withReplacements = _applyFullQuestEvent(
        withReplacements,
        QuestArrived(locationId),
        playerId: playerId,
      );
    }
  }
  final refreshedPlayers = [
    for (final player in withReplacements.players)
      player
          .withActionPoints((2 + player.nextTurnActionDelta).clamp(0, 999))
          .withNextTurnActionDelta(0),
  ];
  PlayerState? first;
  for (final player in refreshedPlayers) {
    if (player.alive) {
      first = player;
      break;
    }
  }
  if (first == null) {
    return _copyState(
      withReplacements,
      players: refreshedPlayers,
      actionsLeft: 0,
      clearActivePlayerId: true,
      isComplete: true,
    );
  }
  return _copyState(
    withReplacements,
    players: refreshedPlayers,
    round: withReplacements.round + 1,
    phase: GamePhase.playersTurn,
    activePlayerId: first.id,
    actionsLeft: first.actionPoints,
    actionsTakenThisTurn: 0,
    eventTurnIndex: 0,
    logEntry: 'round-start:${withReplacements.round + 1}',
  );
}

GameState _activateQueuedReplacements(GameState state) {
  if (state.queuedReplacements.isEmpty) return state;
  HexCoord? anabiosis;
  for (final tile in state.board) {
    if (tile.type == HexTileType.start) {
      anabiosis = tile.coord;
      break;
    }
  }
  if (anabiosis == null) {
    throw StateError('A replacement hero requires an anabiosis start sector.');
  }
  return _copyState(
    state,
    players: [
      for (final player in state.players)
        if (state.queuedReplacements[player.id] case final replacement?)
          PlayerState(
            id: player.id,
            characterId: replacement.characterId,
            coord: anabiosis,
            damage: 0,
            health: replacement.health,
            credits: replacement.credits,
            backpack: replacement.backpack,
            equipped: replacement.equipped,
            carriedMods: replacement.carriedMods,
            implanted: replacement.implanted,
            conditions: const [],
            alive: true,
            stats: replacement.stats,
          )
        else
          player,
    ],
    queuedReplacements: const {},
    logEntry: 'replacement-arrived',
  );
}
