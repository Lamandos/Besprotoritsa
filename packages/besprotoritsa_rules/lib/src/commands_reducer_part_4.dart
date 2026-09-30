// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

GameStepResult _move(GameState state, HexCoord target, int cost) {
  final destination = state.tileAt(target)!;
  final opensSector = !destination.opened;
  final moved = _copyState(
    state,
    actionsLeft: state.actionsLeft - cost,
    board: opensSector ? _openTile(state.board, destination) : null,
    players: _replaceActivePlayer(
      state,
      (player) => _copyPlayer(player, coord: target),
    ),
    logEntry: 'move:${state.activePlayerId}:$target',
  );
  final resolved = resolveColocation(moved);
  final player = _activePlayer(state)!;
  final locationId = destination.locationId;
  return GameStepResult(
    state: locationId == null || state.questDefinitions.isEmpty
        ? resolved
        : _applyFullQuestEvent(
            resolved,
            QuestArrived(locationId),
            playerId: player.id,
          ),
  );
}

GameStepResult _closeCorridor(GameState state, HexCoord target) =>
    GameStepResult(
      state: _copyState(
        state,
        actionsLeft: state.actionsLeft - 1,
        board: [
          for (final tile in state.board)
            if (tile.coord == target)
              _copyTile(tile, isBlocked: true)
            else
              tile,
        ],
        logEntry: 'corridor-closed:${state.activePlayerId}:$target',
      ),
    );

/// Resolves threats in shared cells, creating one dodge decision per hit.
///
/// Calls made while another dodge is open append their damage after the current
/// decision, preserving a deterministic order of monsters, then Boils.
GameState resolveColocation(GameState state) {
  final damage = <IncomingDamage>[];
  for (final monster in state.monsters) {
    if (monster.attack == 0) {
      continue;
    }
    for (final player in state.players) {
      if (player.alive && player.coord == monster.coord) {
        final defense = _monsterIgnoresDefense(state, monster)
            ? 0
            : _playerDefense(state, player);
        final incoming = (monster.attack - defense).clamp(0, monster.attack);
        if (incoming == 0) continue;
        damage.add(
          IncomingDamage(
            targetPlayerId: player.id,
            amount: incoming,
            agilityDice: _statDice(player, state, StatType.agility),
            source: DamageSource.monster,
          ),
        );
      }
    }
  }
  final exploding = state.boils
      .where(
        (boil) => state.players.any(
          (player) => player.alive && player.coord == boil.coord,
        ),
      )
      .toList();
  for (final boil in exploding) {
    for (final player in state.players) {
      if (player.alive &&
          player.coord == boil.coord &&
          !_ignoresBoils(state, player)) {
        damage.add(
          IncomingDamage(
            targetPlayerId: player.id,
            amount: 1,
            agilityDice: _statDice(player, state, StatType.agility),
            source: DamageSource.boil,
          ),
        );
      }
    }
  }
  final resolved = _copyState(
    state,
    boils: state.boils.where((boil) => !exploding.contains(boil)),
    pendingDamage: [...state.pendingDamage, ...damage],
  );
  return _startNextIncomingDamage(resolved);
}

bool _ignoresBoils(GameState state, PlayerState player) =>
    InventoryRules.activeCardIds(player).any(
      (cardId) =>
          state.cardDefinitions[cardId]?.behaviorIds.contains(
            'damage.ignoreBoil',
          ) ??
          false,
    );

int _playerDefense(GameState state, PlayerState player) =>
    InventoryRules.activeCardIds(player).fold<int>(
      0,
      (total, cardId) {
        final definition = state.cardDefinitions[cardId];
        if (definition == null ||
            definition.behaviorIds.contains('robot.exhaust')) {
          return total;
        }
        return total + definition.staticEffects[CardStat.defense];
      },
    );

bool _monsterIgnoresDefense(GameState state, MonsterInstance monster) {
  final features = state.monsterDefinitions[monster.monsterId]?['features'];
  return features is List<Object?> && features.contains('ignores-defense');
}

bool _monsterSpawnsBoilInsteadOfAttack(
  GameState state,
  MonsterInstance monster,
) {
  final features = state.monsterDefinitions[monster.monsterId]?['features'];
  return features is List<Object?> &&
      features.contains('spawns-boil-instead-of-attack');
}

/// Moves a monster one board step and immediately resolves shared-cell attacks.
GameState moveMonsterOneStep(
  GameState state,
  String instanceId,
  HexCoord target,
) {
  final monster = _monsterById(state, instanceId);
  if (monster == null) {
    throw ArgumentError.value(target, 'target', 'Monster must move one step.');
  }
  final source = state.tileAt(monster.coord);
  final destination = state.tileAt(target);
  final edge = monster.coord.edgeTowardOrNull(target);
  final ventilationStep =
      monster.coord != target &&
      _monsterUsesVentilation(state, monster) &&
      source != null &&
      destination != null &&
      source.opened &&
      destination.opened &&
      source.ventColor != VentColor.none &&
      source.ventColor == destination.ventColor;
  if (monster.coord.distanceTo(target) != 1 && !ventilationStep) {
    throw ArgumentError.value(target, 'target', 'Monster must move one step.');
  }
  if (source == null ||
      destination == null ||
      !source.opened ||
      !destination.opened ||
      source.isBlocked ||
      destination.isBlocked ||
      (!ventilationStep &&
          (edge == null ||
              !source.hasExit(edge) ||
              !destination.hasExit(edge.opposite)))) {
    throw ArgumentError.value(target, 'target', 'Monster path is blocked.');
  }
  return resolveColocation(
    _copyState(
      state,
      monsters: [
        for (final current in state.monsters)
          if (current.instanceId == instanceId)
            _copyMonster(current, coord: target)
          else
            current,
      ],
      logEntry: 'monster-move:$instanceId:$target',
    ),
  );
}

bool _monsterUsesVentilation(GameState state, MonsterInstance monster) {
  // Capabilities are content data.  In particular, do not infer movement
  // rules from a localized name or from a particular card identifier.
  final definition = state.monsterDefinitions[monster.monsterId];
  final features = definition?['features'];
  return features is List<Object?> && features.contains('moves-through-vents');
}

Iterable<HexCoord> _monsterPathNeighbors(
  GameState state,
  MonsterInstance monster,
  HexCoord coord,
) sync* {
  final tile = state.tileAt(coord);
  if (tile == null || tile.isBlocked) return;
  for (final edge in tile.exits) {
    final next = coord.neighbor(edge);
    final nextTile = state.tileAt(next);
    if (nextTile != null &&
        nextTile.opened &&
        !nextTile.isBlocked &&
        nextTile.hasExit(edge.opposite)) {
      yield next;
    }
  }
  if (!_monsterUsesVentilation(state, monster) ||
      tile.ventColor == VentColor.none) {
    return;
  }
  for (final candidate in state.board) {
    if (candidate.coord != coord &&
        candidate.opened &&
        !candidate.isBlocked &&
        candidate.ventColor == tile.ventColor) {
      yield candidate.coord;
    }
  }
}

/// Places a Boil and immediately resolves only that token
/// if a hero is below it.
GameState spawnBoil(GameState state, BoilToken boil) {
  final spawned = _copyState(
    state,
    boils: [...state.boils, boil],
    logEntry: 'boil-spawn:${boil.instanceId}:${boil.coord}',
  );
  final occupants = spawned.players
      .where((player) => player.alive && player.coord == boil.coord)
      .toList();
  if (occupants.isEmpty) return spawned;

  final damage = <IncomingDamage>[
    for (final player in occupants)
      if (!_ignoresBoils(spawned, player))
        IncomingDamage(
          targetPlayerId: player.id,
          amount: 1,
          agilityDice: _statDice(player, spawned, StatType.agility),
          source: DamageSource.boil,
        ),
  ];
  return _startNextIncomingDamage(
    _copyState(
      spawned,
      boils: spawned.boils.where(
        (current) => current.instanceId != boil.instanceId,
      ),
      pendingDamage: [...spawned.pendingDamage, ...damage],
    ),
  );
}

/// Places a monster and immediately resolves attacks in its arrival cell.
GameState spawnMonster(GameState state, MonsterInstance monster) =>
    resolveColocation(
      _copyState(
        state,
        monsters: [...state.monsters, monster],
        logEntry: 'monster-spawn:${monster.instanceId}:${monster.coord}',
      ),
    );

int _movementCost(HexTile destination) => destination.opened ? 1 : 2;

GameStepResult _attack(
  GameState state,
  String targetInstanceId,
  DiceRoller dice,
) {
  final player = _activePlayer(state)!;
  final hooks = _activeEffectHooks(state, player);
  final preAttackHooks = hooks.whereType<PreAttackDamageHook>();
  final preAttackDamage = preAttackHooks.isEmpty
      ? 0
      : const EffectEngine()
            .resolvePreAttackRoll(dice.rollDice(1), preAttackHooks)
            .targetDamage;
  final diceRoll = dice.rollDice(_heroAttackDice(player, state));
  final roll = const EffectEngine().resolveRoll(
    diceRoll,
    hooks,
  );
  if (roll.rerollsAvailable > 0) {
    return GameStepResult(
      state: _copyState(
        state,
        actionsLeft: state.actionsLeft - 1,
        pendingDecision: AwaitingRerollChoice(
          dice: diceRoll,
          availableRerolls: roll.rerollsAvailable,
          maxDicePerReroll: 1,
          window: const DecisionWindow(remainingTicks: 1),
          context: AttackRollContext(
            playerId: player.id,
            targetInstanceId: targetInstanceId,
            preAttackDamage: preAttackDamage,
          ),
        ),
        logEntry: 'attack-roll:${player.id}:$targetInstanceId',
      ),
    );
  }
  return GameStepResult(
    state: _resolveAttackRoll(
      state,
      player.id,
      targetInstanceId,
      diceRoll,
      consumesAction: true,
      preAttackDamage: preAttackDamage,
    ),
  );
}

GameState _resolveAttackRoll(
  GameState state,
  PlayerId playerId,
  String targetInstanceId,
  List<int> dice, {
  required bool consumesAction,
  int preAttackDamage = 0,
}) {
  final player = _playerById(state, playerId)!;
  final monster = _monsterById(state, targetInstanceId)!;
  final hooks = _activeEffectHooks(state, player);
  final roll = const EffectEngine().resolveRoll(dice, hooks);
  final damage =
      preAttackDamage + (roll.hits - monster.defense).clamp(0, roll.hits);
  final defeated = monster.damage + damage >= monster.health;
  final collateral = defeated
      ? const EffectEngine()
            .resolveKill(
              killedEnemyId: monster.instanceId,
              sectorId: monster.coord.toString(),
              enemySectors: {
                for (final enemy in state.monsters)
                  enemy.instanceId: enemy.coord.toString(),
              },
              hooks: hooks,
            )
            .damageByEnemyId
      : const <String, int>{};
  final monsters = <MonsterInstance>[];
  final returnedMonsterCards = <CardId>[];
  if (defeated && monster.returnsToMonsterDeck) {
    returnedMonsterCards.add(monster.monsterId);
  }
  for (final current in state.monsters) {
    if (current.instanceId == monster.instanceId) continue;
    final totalDamage = current.damage + (collateral[current.instanceId] ?? 0);
    if (totalDamage < current.health) {
      monsters.add(_copyMonster(current, damage: totalDamage));
    } else if (current.returnsToMonsterDeck) {
      returnedMonsterCards.add(current.monsterId);
    }
  }
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final monsterDeck = decks['monsters'];
  if (monsterDeck != null && returnedMonsterCards.isNotEmpty) {
    decks['monsters'] = DeckState(
      drawPile: monsterDeck.drawPile,
      discardPile: [...monsterDeck.discardPile, ...returnedMonsterCards],
    );
  }
  var awardedPlayer = _copyPlayer(
    player,
    damage: player.damage + roll.ownerDamage,
  );
  var unclaimedLoot = const <CardId>[];
  if (defeated && monster.monsterId == RestlessMonster.restlessMonsterId) {
    final loot = _awardRestlessTrophies(awardedPlayer, monster, state);
    awardedPlayer = loot.player;
    unclaimedLoot = loot.unclaimed;
  }
  final resolved = resolveHeroDeaths(
    _copyState(
      state,
      actionsLeft: consumesAction ? state.actionsLeft - 1 : state.actionsLeft,
      players: _replacePlayer(
        state,
        player.id,
        (_) => awardedPlayer,
      ),
      monsters: [
        if (!defeated) _copyMonster(monster, damage: monster.damage + damage),
        ...monsters,
      ],
      decks: decks,
      logEntry: _attackLog(
        player,
        monster,
        damage,
        defeated,
        unclaimedLoot: unclaimedLoot,
      ),
    ),
  );
  var afterAttack = resolved;
  if (defeated && state.questDefinitions.isNotEmpty) {
    afterAttack = _applyFullQuestEvent(
      afterAttack,
      QuestMonsterKilled(monsterId: monster.monsterId),
      playerId: playerId,
    );
    afterAttack = _applyFullQuestEvent(
      afterAttack,
      const QuestCounterIncremented(metric: 'damage_tokens_collected'),
      playerId: playerId,
    );
  }
  return defeated
      ? _recordPersonalTaskKillProgress(state, afterAttack, playerId)
      : afterAttack;
}

({PlayerState player, List<CardId> unclaimed}) _awardRestlessTrophies(
  PlayerState player,
  MonsterInstance restless,
  GameState state,
) {
  var awarded = player;
  final unclaimed = <CardId>[];
  for (final cardId in restless.carriedGear) {
    try {
      awarded = InventoryRules.receive(awarded, cardId, state.cardDefinitions);
    } on BackpackCapacityExceeded {
      // Combat has already resolved.  A full backpack must not turn a valid
      // kill into an uncaught reducer exception or duplicate its effects.
      unclaimed.add(cardId);
    } on InventoryRuleViolation {
      // Corrupt/legacy content cannot be equipped as a reward.  Preserve a
      // deterministic completed combat and make the omission auditable.
      unclaimed.add(cardId);
    }
  }
  return (player: awarded, unclaimed: unclaimed);
}
