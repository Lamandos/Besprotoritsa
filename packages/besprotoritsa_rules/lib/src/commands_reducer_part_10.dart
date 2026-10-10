// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

GameState _recordPersonalTaskProgress(
  GameState before,
  GameState after,
  GameCommand command,
) {
  if (after.quests.personalTasksByPlayer.isEmpty) return after;
  final catalog = PersonalTaskCatalog(
    tasks: after.taskDefinitions.values.map(PersonalTaskDefinition.fromJson),
  );
  var state = after;
  for (final entry in after.quests.personalTasksByPlayer.entries) {
    final taskIds = entry.value.where((id) => catalog[id] != null).toSet();
    final metrics = taskIds.map((id) => catalog.task(id).metric).toSet();
    for (final metric in metrics) {
      final observation = _personalTaskObservation(
        before,
        state,
        entry.key,
        metric,
        command,
      );
      if (observation == null) continue;
      state = _recordPersonalTaskEvent(state, catalog, observation);
    }
  }
  return state;
}

GameState _recordPersonalTaskKillProgress(
  GameState before,
  GameState after,
  PlayerId playerId,
) {
  final assigned = after.quests.personalTasksByPlayer[playerId];
  if (assigned == null || assigned.isEmpty) return after;
  final catalog = PersonalTaskCatalog(
    tasks: after.taskDefinitions.values.map(PersonalTaskDefinition.fromJson),
  );
  final metrics = assigned
      .where((id) => catalog[id] != null)
      .map((id) => catalog.task(id).metric)
      .toSet();
  if (metrics.isEmpty) return after;
  final remainingIds = after.monsters
      .map((monster) => monster.instanceId)
      .toSet();
  final defeated = before.monsters
      .where((monster) => !remainingIds.contains(monster.instanceId))
      .toList();
  if (defeated.isEmpty) return after;

  var state = after;
  if (metrics.contains('enemies_killed')) {
    state = _recordPersonalTaskEvent(
      state,
      catalog,
      PersonalTaskEvent(
        playerId: playerId,
        metric: 'enemies_killed',
        amount: defeated.length,
        turn: after.round,
      ),
    );
  }
  if (metrics.contains('strong_enemy_solo')) {
    final strongDefeated = defeated.where((monster) {
      final features =
          before.monsterDefinitions[monster.monsterId]?['features'];
      return features is List<Object?> &&
          features.contains('strong') &&
          before.players
                  .where((hero) => hero.alive && hero.coord == monster.coord)
                  .length ==
              1 &&
          before.players.any(
            (hero) => hero.id == playerId && hero.coord == monster.coord,
          );
    }).length;
    if (strongDefeated > 0) {
      state = _recordPersonalTaskEvent(
        state,
        catalog,
        PersonalTaskEvent(
          playerId: playerId,
          metric: 'strong_enemy_solo',
          amount: strongDefeated,
          turn: after.round,
        ),
      );
    }
  }
  return state;
}

PersonalTaskEvent? _personalTaskObservation(
  GameState before,
  GameState after,
  PlayerId playerId,
  String metric,
  GameCommand command,
) {
  final player = _playerById(after, playerId);
  final previous = _playerById(before, playerId);
  if (player == null || previous == null) return null;
  int? value;
  var amount = 1;
  switch (metric) {
    case 'map_fragments_open':
      value = after.board.every((tile) => tile.opened) ? 1 : 0;
    case 'implants':
      value = player.implanted.length;
    case 'chest_cards':
      value = after.chestCards.length;
    case 'credits':
      value = player.credits;
    case 'combat_strength':
      value = _heroAttackDice(player, after);
    case 'conditions':
      value = player.conditions.length;
    case 'clothing_and_armor':
      value = player.equipped.clothing != null && player.equipped.armor != null
          ? 1
          : 0;
    case 'health_at_most':
      value = player.health - player.damage <= 1 ? 1 : 0;
    case 'dodges_without_damage':
      amount = after.log
          .skip(before.log.length)
          .where((line) => line == 'dodge:$playerId:0')
          .length;
      if (amount == 0) return null;
    case 'enemies_killed':
      return null;
    case 'strong_enemy_solo':
      return null;
    case 'special_items_received':
      final beforeCards = _ownedCardCounts(previous);
      final afterCards = _ownedCardCounts(player);
      amount = afterCards.entries.fold<int>(0, (sum, entry) {
        final definition = after.cardDefinitions[entry.key];
        if (definition?.type != ItemType.specialItem) return sum;
        return sum + (entry.value - (beforeCards[entry.key] ?? 0)).clamp(0, 99);
      });
      if (amount == 0) return null;
    case 'boils_popped':
      final remaining = after.boils.map((boil) => boil.instanceId).toSet();
      final coord = previous.coord;
      amount = before.boils
          .where(
            (boil) =>
                boil.coord == coord && !remaining.contains(boil.instanceId),
          )
          .length;
      if (amount == 0) return null;
      value = amount;
    case 'supply_purchase_cost':
      amount = 0;
      for (final line in after.log.skip(before.log.length)) {
        final prefix = 'terminal-pick:$playerId:';
        if (!line.startsWith(prefix)) continue;
        final cardId = line.substring(prefix.length);
        if (cardId == 'decline') continue;
        final definition = after.cardDefinitions[cardId];
        if (definition?.type == ItemType.supply) amount += definition!.cost;
      }
      if (amount == 0) return null;
    case 'roll_successes':
      if (command case ResolvePendingDecisionCommand(
        choice: KeepRollChoice(),
      )) {
        final pending = before.pendingDecision;
        if (pending is AwaitingRerollChoice &&
            switch (pending.context) {
              SkillCheckContext(playerId: final contextPlayerId) =>
                contextPlayerId == playerId,
              AttackRollContext(playerId: final contextPlayerId) =>
                contextPlayerId == playerId,
              _ => false,
            }) {
          value = countHits(pending.dice);
        }
      }
      if (value == null) return null;
    case 'robot_reloaded':
      final ownedRobotIds = _ownedCardCounts(player).keys
          .where(
            (cardId) => after.cardDefinitions[cardId]?.type == ItemType.robot,
          )
          .toSet();
      amount = previous.exhaustedRobots
          .where(
            (robotId) =>
                !player.exhaustedRobots.contains(robotId) &&
                ownedRobotIds.contains(robotId),
          )
          .length;
      if (amount == 0) return null;
    default:
      return null;
  }
  return PersonalTaskEvent(
    playerId: playerId,
    metric: metric,
    amount: amount > 0 ? amount : 1,
    value: value,
    simultaneousValue: value,
    turn: after.round,
  );
}

GameState _recordPersonalTaskEvent(
  GameState state,
  PersonalTaskCatalog catalog,
  PersonalTaskEvent event,
) {
  final quests = state.quests;
  final assigned = quests.personalTasksByPlayer;
  final taskIds = assigned[event.playerId] ?? const <String>[];
  final countersByPlayer = <String, Map<String, int>>{};
  final completedByPlayer = <String, Set<String>>{};
  final lastTurns = <String, int>{};
  for (final entry in assigned.entries) {
    final counters = <String, int>{};
    for (final taskId in entry.value) {
      final saved = quests.conditionProgress[taskId] ?? const {};
      final value = saved['personal-task-value'];
      if (value != null) counters[taskId] = value;
      final turn = saved['personal-task-turn'];
      if (turn != null &&
          (lastTurns[entry.key] == null || turn > lastTurns[entry.key]!)) {
        lastTurns[entry.key] = turn;
      }
      if (quests.statusOf(taskId) == QuestStatus.completed) {
        completedByPlayer.putIfAbsent(entry.key, () => {}).add(taskId);
      }
    }
    countersByPlayer[entry.key] = counters;
  }
  final progress = PersonalTaskProgress(
    assignedTasksByPlayer: assigned,
    completedTasksByPlayer: completedByPlayer,
    countersByPlayer: countersByPlayer,
    lastTurnByPlayer: lastTurns,
  );
  final transition = PersonalTaskEngine(catalog).record(progress, event);
  final statuses = Map<String, QuestStatus>.of(quests.statuses);
  final conditionProgress = <String, Map<String, int>>{
    for (final entry in quests.conditionProgress.entries)
      entry.key: Map<String, int>.of(entry.value),
  };
  for (final taskId in taskIds) {
    if (catalog[taskId] == null) continue;
    final saved = conditionProgress.putIfAbsent(taskId, () => {});
    final value = transition.progress.valueOf(event.playerId, taskId);
    saved['personal-task-value'] = value;
    final turn = transition.progress.lastTurnByPlayer[event.playerId];
    if (turn != null) saved['personal-task-turn'] = turn;
  }
  for (final completion in transition.completed) {
    statuses[completion.taskId] = QuestStatus.completed;
  }
  var players = state.players;
  final rewardCredits = transition.completed.fold<int>(
    0,
    (sum, completion) => sum + completion.rewardCredits,
  );
  if (rewardCredits > 0) {
    players = [
      for (final player in state.players)
        if (player.id == event.playerId)
          _copyPlayer(player, credits: player.credits + rewardCredits)
        else
          player,
    ];
  }
  return _copyState(
    state,
    players: players,
    quests: QuestState(
      storyQuestIds: quests.storyQuestIds,
      personalTasksByPlayer: quests.personalTasksByPlayer,
      statuses: statuses,
      conditionProgress: conditionProgress,
    ),
  );
}
