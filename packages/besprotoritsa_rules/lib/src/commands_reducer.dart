// Commands and their reducer are deliberately kept dependency-free so an
// identical transition can run on a client, server, or replay verifier.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/combat_models.dart';
import 'package:besprotoritsa_rules/src/dice_roller.dart';
import 'package:besprotoritsa_rules/src/game_state.dart';
import 'package:meta/meta.dart';

sealed class GameCommand {
  const GameCommand();
}

final class MoveCommand extends GameCommand {
  const MoveCommand(this.target);

  final HexCoord target;
}

final class AttackCommand extends GameCommand {
  const AttackCommand(this.targetInstanceId);

  final String targetInstanceId;
}

final class SkillCheckCommand extends GameCommand {
  const SkillCheckCommand(this.stat);

  final StatType stat;
}

final class ResolvePendingDecisionCommand extends GameCommand {
  const ResolvePendingDecisionCommand(this.choice);

  final DecisionChoice choice;
}

final class EndTurnCommand extends GameCommand {
  const EndTurnCommand();
}

/// Restores damage to the active hero and discards all of their conditions.
final class HealCommand extends GameCommand {
  const HealCommand(this.amount)
    : assert(amount > 0, 'amount must be positive');

  final int amount;
}

sealed class CommandRejection {
  const CommandRejection();
}

final class NotEnoughActions extends CommandRejection {
  const NotEnoughActions();
}

final class InvalidTargetCoord extends CommandRejection {
  const InvalidTargetCoord();
}

final class PortMismatch extends CommandRejection {
  const PortMismatch();
}

final class TargetOutOfRange extends CommandRejection {
  const TargetOutOfRange();
}

final class ActionBlockedByPendingDecision extends CommandRejection {
  const ActionBlockedByPendingDecision();
}

final class ActionUnavailableInPhase extends CommandRejection {
  const ActionUnavailableInPhase();
}

final class GameAlreadyCompleted extends CommandRejection {
  const GameAlreadyCompleted();
}

sealed class DecisionChoice {
  const DecisionChoice();
}

final class KeepRollChoice extends DecisionChoice {
  const KeepRollChoice();
}

/// Rerolls the specified dice. An empty [diceIndexes] means all dice.
final class RerollChoice extends DecisionChoice {
  RerollChoice({Iterable<int> diceIndexes = const []})
    : diceIndexes = List.unmodifiable(diceIndexes);

  final List<int> diceIndexes;
}

final class DodgeChoice extends DecisionChoice {
  const DodgeChoice();
}

final class EventOptionChoice extends DecisionChoice {
  const EventOptionChoice(this.option);

  final String option;
}

@immutable
final class GameStepResult {
  const GameStepResult({required this.state, this.rejection});

  final GameState state;
  final CommandRejection? rejection;

  GameState get nextState => state;
  bool get isAccepted => rejection == null;
}

/// Reports why [command] cannot be applied to [state], or null when it can.
CommandRejection? validate(GameState state, GameCommand command) {
  if (state.isComplete) {
    return const GameAlreadyCompleted();
  }
  if (state.pendingDecision != null &&
      command is! ResolvePendingDecisionCommand) {
    return const ActionBlockedByPendingDecision();
  }

  if (command is ResolvePendingDecisionCommand) {
    return state.pendingDecision == null
        ? const ActionBlockedByPendingDecision()
        : null;
  }

  if (state.phase != GamePhase.playersTurn) {
    return const ActionUnavailableInPhase();
  }

  if (command is EndTurnCommand) {
    return null;
  }

  if (state.actionsLeft == 0 || _activePlayer(state) == null) {
    return const NotEnoughActions();
  }

  if (command case MoveCommand(:final target)) {
    final player = _activePlayer(state)!;
    final source = state.tileAt(player.coord);
    final destination = state.tileAt(target);
    if (source == null || !source.opened || destination == null) {
      return const InvalidTargetCoord();
    }
    final edge = player.coord.edgeTowardOrNull(target);
    if (edge == null) {
      return const TargetOutOfRange();
    }
    if (!source.hasExit(edge) || !destination.hasExit(edge.opposite)) {
      return const PortMismatch();
    }
    if (state.actionsLeft < _movementCost(destination)) {
      return const NotEnoughActions();
    }
  }

  if (command case AttackCommand(:final targetInstanceId)) {
    final player = _activePlayer(state)!;
    final monster = _monsterById(state, targetInstanceId);
    if (monster == null || player.coord.distanceTo(monster.coord) != 0) {
      return const TargetOutOfRange();
    }
  }

  return null;
}

/// Applies one command without mutating [state]. Rejected commands return the
/// original state unchanged and describe their rejection in the result.
GameStepResult step(GameState state, GameCommand command, DiceRoller dice) {
  final rejection = validate(state, command);
  if (rejection != null) {
    return GameStepResult(state: state, rejection: rejection);
  }

  return switch (command) {
    MoveCommand(:final target) => _move(state, target),
    AttackCommand(:final targetInstanceId) => _attack(
      state,
      targetInstanceId,
      dice,
    ),
    SkillCheckCommand(:final stat) => _startPlayerSkillCheck(state, stat, dice),
    ResolvePendingDecisionCommand(:final choice) => _resolveDecision(
      state,
      choice,
      dice,
    ),
    EndTurnCommand() => GameStepResult(state: _endTurn(state)),
    HealCommand(:final amount) => GameStepResult(state: _heal(state, amount)),
  };
}

GameStepResult _move(GameState state, HexCoord target) {
  final destination = state.tileAt(target)!;
  final opensSector = !destination.opened;
  final moved = _copyState(
    state,
    actionsLeft: state.actionsLeft - _movementCost(destination),
    board: opensSector ? _openTile(state.board, destination) : null,
    players: _replaceActivePlayer(
      state,
      (player) => _copyPlayer(player, coord: target),
    ),
    logEntry: 'move:${state.activePlayerId}:$target',
  );
  return GameStepResult(state: resolveColocation(moved));
}

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
  final monster = _monsterById(state, targetInstanceId)!;
  final successes = countHits(dice.rollDice(_heroAttackDice(player, state)));
  final damage = (successes - monster.defense).clamp(0, successes);
  final monsterDamage = monster.damage + damage;
  final defeated = monsterDamage >= monster.health;
  return GameStepResult(
    state: _copyState(
      state,
      actionsLeft: state.actionsLeft - 1,
      monsters: [
        for (final current in state.monsters)
          if (current.instanceId != monster.instanceId)
            current
          else if (!defeated)
            _copyMonster(current, damage: monsterDamage),
      ],
      logEntry: _attackLog(player, monster, damage, defeated),
    ),
  );
}

GameStepResult _startPlayerSkillCheck(
  GameState state,
  StatType stat,
  DiceRoller dice,
) {
  final player = _activePlayer(state)!;
  final tile = state.tileAt(player.coord);
  final completesQuest =
      stat == StatType.science &&
      tile?.locationId == 'crew-mess' &&
      state.quests.storyQuestIds.contains('chapter-1-awakening') &&
      state.quests.statusOf('chapter-1-awakening') == QuestStatus.active;
  return _startRoll(
    state,
    dice,
    'skill-check:${player.id}:${stat.name}',
    diceCount: _statDice(player, state, stat),
    context: SkillCheckContext(
      playerId: player.id,
      stat: stat,
      questId: completesQuest ? 'chapter-1-awakening' : null,
    ),
  );
}

String _attackLog(
  PlayerState player,
  MonsterInstance monster,
  int damage,
  bool defeated,
) =>
    'attack:${player.id}:${monster.instanceId}:$damage'
    '${defeated ? ':defeated' : ''}';

int _heroAttackDice(PlayerState player, GameState state) =>
    _statDice(player, state, StatType.strength) + player.weaponModifier;

int _statDice(PlayerState player, GameState state, StatType stat) {
  final modifier = player.conditions.fold<int>(
    0,
    (total, conditionId) =>
        total + (state.conditionCards[conditionId]?.statModifiers[stat] ?? 0),
  );
  return (player.stats.valueFor(stat) + modifier).clamp(1, 999);
}

GameState _heal(GameState state, int amount) {
  final player = _activePlayer(state)!;
  final conditionDeck = state.decks['conditions'];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  if (conditionDeck != null && player.conditions.isNotEmpty) {
    decks['conditions'] = DeckState(
      drawPile: conditionDeck.drawPile,
      discardPile: [...conditionDeck.discardPile, ...player.conditions],
    );
  }
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: _replaceActivePlayer(
      state,
      (current) => _copyPlayer(
        current,
        damage: (current.damage - amount).clamp(0, current.damage),
        conditions: const [],
      ),
    ),
    decks: decks,
    logEntry: 'heal:${player.id}:$amount',
  );
}

List<HexTile> _openTile(List<HexTile> board, HexTile destination) => [
  for (final tile in board)
    if (tile.coord == destination.coord)
      HexTile(
        id: tile.id,
        coord: tile.coord,
        type: tile.type,
        opened: true,
        exits: tile.exits,
        locationId: tile.locationId,
        hasTerminal: tile.hasTerminal,
        ventColor: tile.ventColor,
      )
    else
      tile,
];

GameStepResult _startRoll(
  GameState state,
  DiceRoller dice,
  String logEntry, {
  int diceCount = 1,
  SkillCheckContext? context,
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
  };
}

GameStepResult _resolveReroll(
  GameState state,
  AwaitingRerollChoice pending,
  DecisionChoice choice,
  DiceRoller dice,
) {
  if (choice is KeepRollChoice) {
    final resolved = _copyState(state, clearPendingDecision: true);
    return GameStepResult(state: _completeSkillCheck(resolved, pending));
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
  final withDamage = _copyState(
    state,
    players: _replacePlayer(
      state,
      targetId,
      (player) => _copyPlayer(player, damage: player.damage + remainingDamage),
    ),
    clearPendingDecision: true,
  );
  final withCondition = damaged && pending.source == DamageSource.monster
      ? _drawCondition(withDamage, targetId!)
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

GameState _drawCondition(GameState state, PlayerId targetId) {
  final deck = state.decks['conditions'];
  if (deck == null || deck.drawPile.isEmpty) {
    return state;
  }
  final condition = deck.drawPile.first;
  final decks = Map<DeckId, DeckState>.of(state.decks);
  decks['conditions'] = DeckState(
    drawPile: deck.drawPile.skip(1),
    discardPile: deck.discardPile,
  );
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

GameState _startNextIncomingDamage(GameState state) {
  if (state.pendingDecision != null || state.pendingDamage.isEmpty) {
    return state;
  }
  final next = state.pendingDamage.first;
  return _copyState(
    state,
    pendingDecision: AwaitingDodge(
      monsterDamage: next.amount,
      requiredAgilitySuccesses: next.agilityDice,
      targetPlayerId: next.targetPlayerId,
      source: next.source,
    ),
    pendingDamage: state.pendingDamage.skip(1),
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
  final selected = _copyState(
    state,
    clearPendingDecision: true,
    activePlayerId: playerId,
    logEntry: 'event-option:$playerId:${choice.option}',
  );
  if (pending.eventId == null) {
    return GameStepResult(state: _resumeAutomaticPhase(selected));
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
      eventId: pending.eventId,
    ),
    consumesAction: false,
  );
}

GameState _completeSkillCheck(
  GameState state,
  AwaitingRerollChoice pending,
) {
  final context = pending.context;
  if (context == null) return _resumeAutomaticPhase(state);
  final succeeded = countHits(pending.dice) >= context.difficulty;
  if (context.questId != null && succeeded) {
    return _completeMvpQuest(state, context);
  }
  if (context.eventId == 'cabin-noise') {
    return _resolveCabinNoise(state, context, succeeded);
  }
  return _resumeAutomaticPhase(state);
}

GameState _resolveCabinNoise(
  GameState state,
  SkillCheckContext context,
  bool succeeded,
) {
  if (succeeded) {
    final player = _playerById(state, context.playerId)!;
    final withSupply = player.backpack.length < 3
        ? _copyState(
            state,
            players: _replacePlayer(
              state,
              player.id,
              (current) => _copyPlayer(
                current,
                backpack: [...current.backpack, 'event-supply'],
              ),
            ),
            logEntry: 'event-success:cabin-noise:${player.id}:supply',
          )
        : _copyState(
            state,
            players: _replacePlayer(
              state,
              player.id,
              (current) => _copyPlayer(
                current,
                credits: current.credits + 1,
              ),
            ),
            logEntry: 'event-success:cabin-noise:${player.id}:credit',
          );
    return _resumeAutomaticPhase(withSupply);
  }
  final player = _playerById(state, context.playerId)!;
  return spawnMonster(
    _copyState(state, logEntry: 'event-failure:cabin-noise:${player.id}'),
    MonsterInstance(
      instanceId: 'ghoul-event-${state.round}-${player.id}',
      monsterId: 'ghoul',
      coord: player.coord,
      damage: 0,
      health: 2,
      defense: 0,
      attack: 2,
      movement: 1,
    ),
  );
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
  final activeIndex = state.players.indexWhere(
    (player) => player.id == state.activePlayerId,
  );
  final nextIndex = _nextLivingPlayerIndex(state.players, activeIndex);
  if (nextIndex == null) {
    return _copyState(state, actionsLeft: 0, clearActivePlayerId: true);
  }
  final lastPlayerOfRound = activeIndex >= 0 && nextIndex <= activeIndex;
  if (lastPlayerOfRound) {
    return _runMonstersTurn(
      _copyState(
        state,
        phase: GamePhase.monstersTurn,
        actionsLeft: 0,
        clearActivePlayerId: true,
        monsterTurnIndex: 0,
        monsterStepsRemaining: 0,
        logEntry: 'players-turn-complete:${state.round}',
      ),
    );
  }
  return _copyState(
    state,
    activePlayerId: state.players[nextIndex].id,
    actionsLeft: 2,
    logEntry: 'end-turn:${state.activePlayerId}',
  );
}

/// Returns living heroes sorted by a monster's deterministic target priority.
///
/// The path calculation traverses only opened tiles with mutually matching
/// exits.  Equal distances are then broken by current HP and saved player
/// order, which is the turn order of the round.
List<PlayerState> nearestTargets(GameState state, MonsterInstance monster) {
  final distances = _openPathDistances(state, monster.coord);
  final targets = state.players
      .where((player) => player.alive && distances.containsKey(player.coord))
      .toList();
  targets.sort((left, right) {
    final distanceOrder = distances[left.coord]!.compareTo(
      distances[right.coord]!,
    );
    if (distanceOrder != 0) return distanceOrder;
    final leftHp = _currentHp(left);
    final rightHp = _currentHp(right);
    final hpOrder = leftHp.compareTo(rightHp);
    if (hpOrder != 0) return hpOrder;
    return state.players.indexOf(left).compareTo(state.players.indexOf(right));
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
    if (eventDeck == null || eventDeck.drawPile.isEmpty) continue;
    final eventId = eventDeck.drawPile.first;
    final decks = Map<DeckId, DeckState>.of(current.decks);
    decks['events'] = DeckState(
      drawPile: eventDeck.drawPile.skip(1),
      discardPile: [...eventDeck.discardPile, eventId],
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
  PlayerState? first;
  for (final player in state.players) {
    if (player.alive) {
      first = player;
      break;
    }
  }
  if (first == null) {
    return _copyState(state, actionsLeft: 0, clearActivePlayerId: true);
  }
  return _copyState(
    state,
    round: state.round + 1,
    phase: GamePhase.playersTurn,
    activePlayerId: first.id,
    actionsLeft: 2,
    eventTurnIndex: 0,
    logEntry: 'round-start:${state.round + 1}',
  );
}

GameState _resumeAutomaticPhase(GameState state) {
  if (state.pendingDecision != null || state.isComplete) return state;
  return switch (state.phase) {
    GamePhase.monstersTurn => _runMonstersTurn(state),
    GamePhase.eventsPhase => _advanceEvents(state),
    GamePhase.playersTurn => state,
  };
}

int? _nextLivingPlayerIndex(List<PlayerState> players, int activeIndex) {
  if (players.isEmpty) {
    return null;
  }
  final start = activeIndex < 0 ? 0 : (activeIndex + 1) % players.length;
  for (var offset = 0; offset < players.length; offset++) {
    final index = (start + offset) % players.length;
    if (players[index].alive) {
      return index;
    }
  }
  return null;
}

PlayerState? _activePlayer(GameState state) {
  final id = state.activePlayerId;
  if (id == null) {
    return null;
  }
  for (final player in state.players) {
    if (player.id == id) {
      return player;
    }
  }
  return null;
}

PlayerState? _playerById(GameState state, PlayerId playerId) {
  for (final player in state.players) {
    if (player.id == playerId) return player;
  }
  return null;
}

MonsterInstance? _monsterById(GameState state, String instanceId) {
  for (final monster in state.monsters) {
    if (monster.instanceId == instanceId) {
      return monster;
    }
  }
  return null;
}

List<PlayerState> _replaceActivePlayer(
  GameState state,
  PlayerState Function(PlayerState player) replace,
) => [
  for (final player in state.players)
    if (player.id == state.activePlayerId) replace(player) else player,
];

List<PlayerState> _replacePlayer(
  GameState state,
  PlayerId? playerId,
  PlayerState Function(PlayerState player) replace,
) => [
  for (final player in state.players)
    if (player.id == playerId) replace(player) else player,
];

PlayerState _copyPlayer(
  PlayerState player, {
  HexCoord? coord,
  int? damage,
  int? credits,
  Iterable<CardId>? backpack,
  Iterable<CardId>? conditions,
}) => PlayerState(
  id: player.id,
  characterId: player.characterId,
  coord: coord ?? player.coord,
  damage: damage ?? player.damage,
  health: player.health,
  credits: credits ?? player.credits,
  backpack: backpack ?? player.backpack,
  equipped: player.equipped,
  carriedMods: player.carriedMods,
  implanted: player.implanted,
  conditions: conditions ?? player.conditions,
  alive: player.alive,
  stats: player.stats,
  weaponModifier: player.weaponModifier,
);

MonsterInstance _copyMonster(
  MonsterInstance monster, {
  HexCoord? coord,
  int? damage,
}) => MonsterInstance(
  instanceId: monster.instanceId,
  monsterId: monster.monsterId,
  coord: coord ?? monster.coord,
  damage: damage ?? monster.damage,
  health: monster.health,
  defense: monster.defense,
  attack: monster.attack,
  movement: monster.movement,
  carriedGear: monster.carriedGear,
);

GameState _copyState(
  GameState state, {
  int? round,
  GamePhase? phase,
  PlayerId? activePlayerId,
  bool clearActivePlayerId = false,
  int? actionsLeft,
  Iterable<HexTile>? board,
  Iterable<PlayerState>? players,
  Iterable<MonsterInstance>? monsters,
  Iterable<BoilToken>? boils,
  Map<DeckId, DeckState>? decks,
  QuestState? quests,
  Iterable<IncomingDamage>? pendingDamage,
  Iterable<GameEvent>? gameEvents,
  bool? isComplete,
  int? monsterTurnIndex,
  int? monsterStepsRemaining,
  int? eventTurnIndex,
  PendingDecision? pendingDecision,
  bool clearPendingDecision = false,
  String? logEntry,
}) => GameState(
  schemaVersion: state.schemaVersion,
  seed: state.seed,
  round: round ?? state.round,
  phase: phase ?? state.phase,
  activePlayerId: clearActivePlayerId
      ? null
      : activePlayerId ?? state.activePlayerId,
  actionsLeft: actionsLeft ?? state.actionsLeft,
  board: board ?? state.board,
  players: players ?? state.players,
  monsters: monsters ?? state.monsters,
  boils: boils ?? state.boils,
  conditionCards: state.conditionCards,
  pendingDamage: pendingDamage ?? state.pendingDamage,
  decks: decks ?? state.decks,
  quests: quests ?? state.quests,
  log: [...state.log, if (logEntry != null) logEntry],
  gameEvents: gameEvents ?? state.gameEvents,
  isComplete: isComplete ?? state.isComplete,
  monsterTurnIndex: monsterTurnIndex ?? state.monsterTurnIndex,
  monsterStepsRemaining: monsterStepsRemaining ?? state.monsterStepsRemaining,
  eventTurnIndex: eventTurnIndex ?? state.eventTurnIndex,
  pendingDecision: clearPendingDecision
      ? null
      : pendingDecision ?? state.pendingDecision,
);
