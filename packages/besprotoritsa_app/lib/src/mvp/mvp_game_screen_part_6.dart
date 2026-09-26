// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

List<_NamedCommand> _availableCommands(GameState state, AppStrings strings) {
  final candidates = <_NamedCommand>[
    for (final tile in state.board)
      _NamedCommand(
        strings.moveCommand(tile.coord.q, tile.coord.r),
        MoveCommand(tile.coord),
      ),
    for (final monster in state.monsters)
      _NamedCommand(
        strings.attackCommand(monster.monsterId),
        AttackCommand(monster.instanceId),
      ),
    for (final stat in StatType.values)
      _NamedCommand('Проверка: ${_statLabel(stat)}', SkillCheckCommand(stat)),
    const _NamedCommand('Использовать терминал', UseTerminalCommand()),
    _NamedCommand(strings.next, const EndTurnCommand()),
  ];
  return [
    for (final candidate in candidates)
      if (validate(state, candidate.command) == null) candidate,
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
  const _NamedCommand(this.label, this.command);

  final String label;
  final GameCommand command;
}

Offset _layoutPosition(HexCoord coord, List<HexTile> board) {
  final tile = board.where((candidate) => candidate.coord == coord).firstOrNull;
  if (board.length == 3 && tile != null) {
    final position = switch (tile.type) {
      HexTileType.start => const Offset(208, 0),
      HexTileType.corridor => const Offset(30, 220),
      HexTileType.compartment => const Offset(386, 220),
      HexTileType.airlock => null,
    };
    if (position != null) return position;
  }
  return Offset(
    24 + (coord.q + coord.r * .5) * 138,
    16 + coord.r * 118,
  );
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
    ..moveTo(size.width * .25, 2)
    ..lineTo(size.width * .75, 2)
    ..lineTo(size.width - 2, size.height * .5)
    ..lineTo(size.width * .75, size.height - 2)
    ..lineTo(size.width * .25, size.height - 2)
    ..lineTo(2, size.height * .5)
    ..close();

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}
