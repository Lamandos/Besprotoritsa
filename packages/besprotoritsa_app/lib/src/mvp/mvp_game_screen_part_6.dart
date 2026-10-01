// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

List<_NamedCommand> _availableCommands(GameState state, AppStrings strings) {
  final activePlayer = state.players
      .where((player) => player.id == state.activePlayerId)
      .firstOrNull;
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
    for (final stat in StatType.values)
      _NamedCommand('Проверка: ${_statLabel(stat)}', SkillCheckCommand(stat)),
    const _NamedCommand('Использовать терминал', UseTerminalCommand()),
    if (activePlayer != null) ...[
      for (final cardId in activePlayer.backpack)
        if (state.cardDefinitions[cardId]?.slots.isNotEmpty ?? false)
          _NamedCommand('Экипировать: $cardId', EquipCommand(cardId)),
      for (final cardId in activePlayer.carriedMods)
        _NamedCommand('Вживить: $cardId', ImplantModificationCommand(cardId)),
      for (final (index, cardId) in activePlayer.equipped.weapons.indexed)
        _NamedCommand(
          'Снять оружие: $cardId',
          UnequipCommand(ItemSlot.weapon, weaponSlot: index),
        ),
      if (activePlayer.equipped.armor != null)
        const _NamedCommand('Снять броню', UnequipCommand(ItemSlot.armor)),
      if (activePlayer.equipped.clothing != null)
        const _NamedCommand('Снять одежду', UnequipCommand(ItemSlot.clothing)),
      if (activePlayer.equipped.robot != null)
        const _NamedCommand('Снять робота', UnequipCommand(ItemSlot.robot)),
      if (activePlayer.coord == const HexCoord(0, 0)) ...[
        for (final cardId in activePlayer.backpack)
          _NamedCommand(
            'Положить в сундук: $cardId',
            DepositIntoChestCommand(cardId),
          ),
        for (final cardId in state.chestCards)
          _NamedCommand(
            'Взять из сундука: $cardId',
            WithdrawFromChestCommand(cardId),
          ),
      ],
      for (final partner in state.players)
        if (partner.alive &&
            partner.id != activePlayer.id &&
            partner.coord == activePlayer.coord) ...[
          for (final cardId in activePlayer.backpack)
            _NamedCommand(
              'Обмен с ${partner.characterId}: отдать $cardId',
              ExchangeCommand(partnerId: partner.id, giveCardId: cardId),
            ),
          for (final cardId in partner.backpack)
            _NamedCommand(
              'Обмен с ${partner.characterId}: взять $cardId',
              ExchangeCommand(partnerId: partner.id, receiveCardId: cardId),
            ),
          if (activePlayer.credits > 0)
            _NamedCommand(
              'Передать кредиты ${partner.characterId}',
              ExchangeCommand(
                partnerId: partner.id,
                giveCredits: activePlayer.credits,
              ),
            ),
          if (partner.credits > 0)
            _NamedCommand(
              'Взять кредиты у ${partner.characterId}',
              ExchangeCommand(
                partnerId: partner.id,
                receiveCredits: partner.credits,
              ),
            ),
        ],
    ],
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
