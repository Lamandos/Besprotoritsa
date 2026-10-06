// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

List<_NamedCommand> _availableCommands(GameState state, AppStrings strings) {
  final activePlayer = state.players
      .where((player) => player.id == state.activePlayerId)
      .firstOrNull;
  final candidates = <_NamedCommand>[
    for (final tile in state.board)
      if (tile.opened)
        _NamedCommand(
          strings.moveCommand(tile.coord.q, tile.coord.r),
          MoveCommand(tile.coord),
        )
      else
        _NamedCommand(
          'Открыть ${tile.type == HexTileType.corridor ? 'коридор' : 'отсек'} '
          '${tile.coord}',
          RevealTileCommand(tile.coord),
        ),
    for (final tile in state.board)
      if (tile.type == HexTileType.corridor)
        _NamedCommand(
          'Закрыть коридор ${tile.coord}',
          CloseCorridorCommand(tile.coord),
        ),
    for (final tile in state.board)
      if (tile.type == HexTileType.corridor && tile.isBlocked)
        _NamedCommand(
          'Открыть коридор ${tile.coord}',
          OpenCorridorCommand(tile.coord),
        ),
    for (final stat in _meaningfulSkillChecks(state, activePlayer))
      _NamedCommand('Проверка: ${_statLabel(stat)}', SkillCheckCommand(stat)),
    const _NamedCommand('Использовать терминал', UseTerminalCommand()),
    _NamedCommand(strings.next, const EndTurnCommand()),
  ];
  final validCandidates = [
    for (final candidate in candidates)
      if (validate(state, candidate.command) == null) candidate,
  ];
  final closableCorridors = validCandidates
      .where((candidate) => candidate.command is CloseCorridorCommand)
      .toList(growable: false);
  final openableCorridors = validCandidates
      .where((candidate) => candidate.command is OpenCorridorCommand)
      .toList(growable: false);
  final moves = validCandidates
      .where((candidate) => candidate.command is MoveCommand)
      .toList(growable: false);
  return [
    ...moves,
    if (closableCorridors.isNotEmpty)
      _NamedCommand(
        'Закрыть коридор',
        closableCorridors.first.command,
        alternatives: closableCorridors,
      ),
    if (openableCorridors.isNotEmpty)
      _NamedCommand(
        'Открыть коридор',
        openableCorridors.first.command,
        alternatives: openableCorridors,
      ),
    for (final candidate in validCandidates)
      if (candidate.command is! CloseCorridorCommand &&
          candidate.command is! MoveCommand &&
          candidate.command is! OpenCorridorCommand)
        candidate,
  ];
}

List<StatType> _meaningfulSkillChecks(
  GameState state,
  PlayerState? activePlayer,
) {
  if (activePlayer == null) return const [];
  final tile = state.tileAt(activePlayer.coord);
  final locationId = tile?.locationId;
  if (tile == null) return const [];

  final relevant = <StatType>{};
  for (final questId in state.quests.storyQuestIds) {
    if (state.quests.statusOf(questId) != QuestStatus.active) continue;
    final definition = state.questDefinitions[questId];
    final conditions = definition?['conditions'];
    if (conditions is! List) continue;
    for (final rawCondition in conditions) {
      if (rawCondition is! Map) continue;
      final condition = Map<String, Object?>.from(rawCondition);
      final conditionId = condition['id'];
      final progress = conditionId is String
          ? (state.quests.conditionProgress[questId]?[conditionId] ?? 0)
          : 0;
      final target = condition['targetValue'];
      if (progress >= (target is int ? target : 1)) continue;

      final type = condition['type'];
      if (type == 'skill_check' || type == 'skillCheck' || type == 'skill') {
        if (locationId == null || condition['locationId'] != locationId) {
          continue;
        }
        final skill = condition['skill'];
        if (skill is String) {
          for (final stat in StatType.values) {
            if (stat.name == skill) relevant.add(stat);
          }
        }
      } else if (type == 'counter' || type == 'count') {
        if (condition['metric'] == 'agility_check_in_ventilation' &&
            tile.ventColor != VentColor.none) {
          relevant.add(StatType.agility);
        }
      }
    }
  }

  // The legacy MVP quest stores condition names instead of structured
  // condition objects, so preserve its single supported science check.
  final mvpQuest = state.questDefinitions['chapter-1-awakening'];
  final mvpConditions = mvpQuest?['conditions'];
  final hasLegacyMvpScienceCheck =
      mvpQuest == null ||
      (mvpConditions is List && mvpConditions.contains('science-check'));
  if (locationId == 'crew-mess' &&
      state.quests.storyQuestIds.contains('chapter-1-awakening') &&
      state.quests.statusOf('chapter-1-awakening') == QuestStatus.active &&
      hasLegacyMvpScienceCheck) {
    relevant.add(StatType.science);
  }

  return [
    for (final stat in StatType.values)
      if (relevant.contains(stat)) stat,
  ];
}

String _statLabel(StatType stat) => switch (stat) {
  StatType.strength => 'сила',
  StatType.combatStrength => 'боевая сила',
  StatType.science => 'наука',
  StatType.repair => 'ремонт',
  StatType.endurance => 'выносливость',
  StatType.agility => 'ловкость',
};

class _NamedCommand {
  const _NamedCommand(
    this.label,
    this.command, {
    this.alternatives,
  });

  final String label;
  final GameCommand command;
  final List<_NamedCommand>? alternatives;
}

void _dispatchNamedCommand(
  BuildContext context,
  WidgetRef ref,
  _NamedCommand namedCommand,
) {
  final alternatives = namedCommand.alternatives;
  if (alternatives == null) {
    _dispatchWithFeedback(context, ref, namedCommand.command);
    return;
  }
  showDialog<_NamedCommand>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(
        namedCommand.command is OpenCorridorCommand
            ? 'Выберите коридор для открытия'
            : 'Выберите коридор для закрытия',
      ),
      children: [
        for (final option in alternatives)
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(option),
            child: Text(option.label),
          ),
      ],
    ),
  ).then((selected) {
    if (selected != null && context.mounted) {
      _dispatchWithFeedback(context, ref, selected.command);
    }
  });
}

Offset _layoutPosition(HexCoord coord, List<HexTile> board) {
  final coordinates = board.map((tile) => tile.coord).toList();
  final minX = coordinates
      .map((point) => point.q * 168 + point.r * 84)
      .reduce((left, right) => left < right ? left : right);
  final minY = coordinates
      .map((point) => point.r * 145)
      .reduce((left, right) => left < right ? left : right);
  return Offset(
    16.0 + coord.q * 168 + coord.r * 84 - minX,
    16.0 + coord.r * 145 - minY,
  );
}

Size _boardCanvasSize(List<HexTile> board) {
  final positions = board.map((tile) {
    final coord = tile.coord;
    return Offset(coord.q * 168 + coord.r * 84, coord.r * 145);
  }).toList();
  final minX = positions.map((point) => point.dx).reduce(math.min);
  final maxX = positions.map((point) => point.dx).reduce(math.max);
  final minY = positions.map((point) => point.dy).reduce(math.min);
  final maxY = positions.map((point) => point.dy).reduce(math.max);
  return Size(maxX - minX + 256, maxY - minY + 224);
}

String _eventLabel(GameEvent event, AppStrings strings) => switch (event) {
  HexEntered(:final playerId, :final to) => strings.enteredEvent(
    playerId,
    to.q,
    to.r,
  ),
  ColocationTriggered(:final playerId) => strings.colocationEvent(playerId),
  DamageDealt(:final playerId, :final amount) => strings.damageEvent(
    playerId,
    amount,
  ),
  HeroDied(:final playerId, :final restlessInstanceId) => strings.diedEvent(
    playerId,
    restlessInstanceId,
  ),
  ConditionDrawn(:final conditionId) => strings.conditionEvent(conditionId),
  MvpDemonstrationCompleted(:final questId) => strings.questEvent(questId),
};

String _decisionPrompt(PendingDecision decision, AppStrings strings) =>
    switch (decision) {
      AwaitingRerollChoice(:final dice) => strings.dicePrompt(dice.join(', ')),
      AwaitingDodge(:final requiredSuccesses) => strings.dodgePrompt(
        requiredSuccesses,
      ),
      AwaitingEventOption() => strings.eventOptionPrompt,
      AwaitingTerminalPick() => strings.terminalPickPrompt,
      AwaitingHeroReplacement() => strings.replacementHeroPrompt,
      AwaitingOtherPlayerDecision() => strings.waitingForOtherPlayer,
    };

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .5, 0)
    ..lineTo(size.width, size.height * .25)
    ..lineTo(size.width, size.height * .75)
    ..lineTo(size.width * .5, size.height)
    ..lineTo(0, size.height * .75)
    ..lineTo(0, size.height * .25)
    ..close();

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}
