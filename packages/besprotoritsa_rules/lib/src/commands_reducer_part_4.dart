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
  return GameStepResult(state: resolveColocation(moved));
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
        damage.add(
          IncomingDamage(
            targetPlayerId: player.id,
            amount: monster.attack,
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
      if (player.alive && player.coord == boil.coord) {
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

/// Moves a monster one board step and immediately resolves shared-cell attacks.
GameState moveMonsterOneStep(
  GameState state,
  String instanceId,
  HexCoord target,
) {
  final monster = _monsterById(state, instanceId);
  if (monster == null || monster.coord.distanceTo(target) != 1) {
    throw ArgumentError.value(target, 'target', 'Monster must move one step.');
  }
  final source = state.tileAt(monster.coord);
  final destination = state.tileAt(target);
  final edge = monster.coord.edgeToward(target);
  if (source == null ||
      destination == null ||
      source.isBlocked ||
      destination.isBlocked ||
      !source.hasExit(edge) ||
      !destination.hasExit(edge.opposite)) {
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

/// Places a Boil and immediately checks whether it detonates under a hero.
GameState spawnBoil(GameState state, BoilToken boil) => resolveColocation(
  _copyState(
    state,
    boils: [...state.boils, boil],
    logEntry: 'boil-spawn:${boil.instanceId}:${boil.coord}',
  ),
);

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
  for (final current in state.monsters) {
    if (current.instanceId == monster.instanceId) continue;
    final totalDamage = current.damage + (collateral[current.instanceId] ?? 0);
    if (totalDamage < current.health) {
      monsters.add(_copyMonster(current, damage: totalDamage));
    }
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
  return resolveHeroDeaths(
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
      logEntry: _attackLog(
        player,
        monster,
        damage,
        defeated,
        unclaimedLoot: unclaimedLoot,
      ),
    ),
  );
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
