// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

/// Returns living heroes sorted by a monster's deterministic target priority.
///
/// The path calculation traverses only opened tiles with mutually matching
/// exits.  Equal distances are then broken by current HP and saved player
/// order, which is the turn order of the round.
List<PlayerState> nearestTargets(GameState state, MonsterInstance monster) {
  final distances = _openPathDistances(state, monster.coord);
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

Map<HexCoord, int> _openPathDistances(GameState state, HexCoord start) {
  final startTile = state.tileAt(start);
  if (startTile == null || !startTile.opened) return const {};
  final distances = <HexCoord, int>{start: 0};
  final queue = <HexCoord>[start];
  for (var index = 0; index < queue.length; index++) {
    final current = queue[index];
    final currentTile = state.tileAt(current)!;
    for (final edge in currentTile.exits) {
      final next = current.neighbor(edge);
      final nextTile = state.tileAt(next);
      if (nextTile == null ||
          !nextTile.opened ||
          !nextTile.hasExit(edge.opposite) ||
          distances.containsKey(next)) {
        continue;
      }
      distances[next] = distances[current]! + 1;
      queue.add(next);
    }
  }
  return distances;
}

HexCoord? _nextPathStep(GameState state, HexCoord start, HexCoord target) {
  final distancesToTarget = _openPathDistances(state, target);
  final startDistance = distancesToTarget[start];
  if (startDistance == null || startDistance == 0) return null;
  final tile = state.tileAt(start)!;
  for (final edge in HexEdge.values) {
    if (!tile.hasExit(edge)) continue;
    final next = start.neighbor(edge);
    final nextTile = state.tileAt(next);
    if (nextTile != null &&
        nextTile.opened &&
        nextTile.hasExit(edge.opposite) &&
        distancesToTarget[next] == startDistance - 1) {
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
        : _nextPathStep(current, monster.coord, targets.first.coord);
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
        options: const ['investigate'],
        playerId: player.id,
        eventId: eventId,
      ),
      logEntry: 'event:$eventId:${player.id}',
    );
  }
  return current;
}

bool _hasAggressiveMonster(GameState state, PlayerState player) => state
    .monsters
    .any((monster) => monster.attack > 0 && monster.coord == player.coord);

GameState _startNextPlayersTurn(GameState state) {
  final withReplacements = _activateQueuedReplacements(state);
  PlayerState? first;
  for (final player in withReplacements.players) {
    if (player.alive) {
      first = player;
      break;
    }
  }
  if (first == null) {
    return _copyState(
      withReplacements,
      actionsLeft: 0,
      clearActivePlayerId: true,
      isComplete: true,
    );
  }
  return _copyState(
    withReplacements,
    round: withReplacements.round + 1,
    phase: GamePhase.playersTurn,
    activePlayerId: first.id,
    actionsLeft: 2,
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
