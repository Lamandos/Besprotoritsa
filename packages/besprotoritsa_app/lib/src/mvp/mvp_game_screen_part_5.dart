// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

class _GameBottomSheet extends StatelessWidget {
  const _GameBottomSheet({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .6,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [icon, const SizedBox(width: 8), Text(title)]),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

// This journal is shared at the table, so it only lists public story quests.
List<String> _activeQuests(GameState state) => [
  for (final questId in state.quests.storyQuestIds)
    if (state.quests.statusOf(questId) == QuestStatus.active) questId,
];

class _PendingDecisionModal extends ConsumerWidget {
  const _PendingDecisionModal({required this.decision, required this.state});

  final PendingDecision decision;
  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final eventId = switch (decision) {
      AwaitingEventOption(:final eventId) => eventId,
      AwaitingRerollChoice(context: SkillCheckContext(:final eventId)) =>
        eventId,
      _ => null,
    };
    final eventTitle = eventId == null
        ? null
        : _runtimeEventText(state, eventId, 'nameKey') ??
              _eventCardTitle(eventId);
    final eventDescription = eventId == null
        ? null
        : _runtimeEventText(state, eventId, 'descKey');
    final coordinateOptions = switch (decision) {
      AwaitingEventOption(:final options) => _eventCoordinateOptions(
        state,
        options,
      ),
      _ => const <HexCoord, String>{},
    };
    final eventTargetPlayerId = switch (decision) {
      AwaitingEventOption(:final playerId) => playerId,
      AwaitingDodge(:final targetPlayerId) => targetPlayerId,
      AwaitingRerollChoice(context: SkillCheckContext(:final playerId)) =>
        playerId,
      AwaitingRerollChoice(context: AttackRollContext(:final playerId)) =>
        playerId,
      _ => null,
    };
    final targetPlayerId = eventTargetPlayerId ?? state.activePlayerId;
    final targetPlayer = targetPlayerId == null
        ? null
        : state.players
              .where((player) => player.id == targetPlayerId)
              .firstOrNull;
    final targetPlayerName = targetPlayer == null
        ? null
        : fullRuntimeCharacterName(targetPlayer.characterId);
    final rerollSources = _decisionRerollSources(state, decision);
    final prompt = _decisionPrompt(decision, strings);
    final sourceNames = rerollSources
        .map((id) => _inventoryCardName(state, id))
        .join(', ');
    final sourceCopy = 'Переброс даёт: $sourceNames';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: AlertDialog(
            title: targetPlayer != null
                ? Row(
                    children: [
                      CharacterPortrait(
                        characterId: targetPlayer.characterId,
                        size: const Size(48, 56),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              eventTitle ??
                                  (decision is AwaitingDodge
                                      ? 'Уклонение'
                                      : strings.decisionRequired),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Для $targetPlayerName',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Text(
                    eventTitle ??
                        (decision is AwaitingDodge
                            ? 'Уклонение'
                            : strings.decisionRequired),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            content: eventId == null
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prompt),
                        if (rerollSources.isNotEmpty)
                          Text(
                            sourceCopy,
                          ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prompt),
                        if (rerollSources.isNotEmpty)
                          Text(
                            sourceCopy,
                          ),
                        if (coordinateOptions.isNotEmpty) ...[
                          const Text(
                            'Выберите подсвеченное поле на карте',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(
                            key: const ValueKey<String>(
                              'event-target-board-map',
                            ),
                            height: 200,
                            width: 500,
                            child: HexBoardWidget(
                              key: const ValueKey<String>(
                                'event-target-board-widget',
                              ),
                              state: state,
                              selectableDestinations: coordinateOptions.keys
                                  .toSet(),
                              onSelectDestination: (coord) {
                                final option = coordinateOptions[coord];
                                if (option == null) return;
                                ref
                                    .read(gameControllerProvider.notifier)
                                    .dispatch(
                                      ResolvePendingDecisionCommand(
                                        EventOptionChoice(option),
                                      ),
                                    );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        GameCardSurface(
                          material: GameCardMaterial.event,
                          overlayColor: const Color(0xD91B1510),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                eventDescription ??
                                    _decisionPrompt(decision, strings),
                                style: const TextStyle(
                                  color: Color(0xFFFFF0D1),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => showGameCardScan(
                                    context,
                                    cardId: eventId,
                                    title: eventTitle ?? eventId,
                                    kind: GameCardArtworkKind.event,
                                  ),
                                  icon: const Icon(
                                    Icons.open_in_full,
                                    size: 16,
                                  ),
                                  label: const Text('Вся карта'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            actions: _decisionActions(ref, decision, strings, state),
          ),
        ),
      ),
    );
  }
}

List<Widget> _decisionActions(
  WidgetRef ref,
  PendingDecision decision,
  AppStrings strings,
  GameState state,
) => switch (decision) {
  AwaitingRerollChoice(
    :final availableRerolls,
    :final maxDicePerReroll,
    :final dice,
  ) =>
    [
      if (availableRerolls > 0 && maxDicePerReroll == 1)
        for (final (index, die) in dice.indexed)
          TextButton(
            onPressed: () => ref
                .read(gameControllerProvider.notifier)
                .dispatch(
                  ResolvePendingDecisionCommand(
                    RerollChoice(diceIndexes: <int>[index]),
                  ),
                ),
            child: Text('${strings.reroll}: $die'),
          )
      else if (availableRerolls > 0)
        TextButton(
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(ResolvePendingDecisionCommand(RerollChoice())),
          child: Text(strings.reroll),
        ),
      FilledButton(
        onPressed: () => ref
            .read(gameControllerProvider.notifier)
            .dispatch(const ResolvePendingDecisionCommand(KeepRollChoice())),
        child: Text(strings.keepResult),
      ),
    ],
  AwaitingDodge() => [
    FilledButton(
      onPressed: () => ref
          .read(gameControllerProvider.notifier)
          .dispatch(const ResolvePendingDecisionCommand(DodgeChoice())),
      child: Text(strings.dodge),
    ),
  ],
  AwaitingEventOption(:final options) => [
    for (final option in options)
      if (!_eventCoordinateOptions(state, options).containsValue(option))
        FilledButton(
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(
                ResolvePendingDecisionCommand(EventOptionChoice(option)),
              ),
          child: Text(_eventOptionLabel(state, decision.eventId, option)),
        ),
  ],
  AwaitingTerminalPick(:final offeredCards) => [
    for (final cardId in offeredCards)
      FilledButton(
        onPressed: () => ref
            .read(gameControllerProvider.notifier)
            .dispatch(
              ResolvePendingDecisionCommand(TerminalPickChoice(cardId)),
            ),
        child: Text(strings.buyCommand(cardId)),
      ),
    TextButton(
      onPressed: () => ref
          .read(gameControllerProvider.notifier)
          .dispatch(
            const ResolvePendingDecisionCommand(DeclineTerminalPickChoice()),
          ),
      child: Text(strings.doNotBuy),
    ),
  ],
  AwaitingHeroReplacement(:final characterIds) => [
    for (final characterId in characterIds)
      FilledButton(
        onPressed: () => ref
            .read(gameControllerProvider.notifier)
            .dispatch(
              ResolvePendingDecisionCommand(
                SelectReplacementHeroChoice(characterId),
              ),
            ),
        child: Text(strings.chooseCommand(characterId)),
      ),
  ],
  AwaitingOtherPlayerDecision() => const [],
};

Map<HexCoord, String> _eventCoordinateOptions(
  GameState state,
  Iterable<String> options,
) => {
  for (final option in options)
    if (_eventOptionCoord(option) case final coord?
        when state.tileAt(coord) != null)
      coord: option,
};

HexCoord? _eventOptionCoord(String option) {
  final parts = option.split(':');
  final indexes = switch ((parts.first, parts.length)) {
    ('sector' || 'move' || 'reveal', 3) => (1, 2),
    ('place' || 'move_spawn', 4) => (2, 3),
    _ => null,
  };
  if (indexes == null) return null;
  final q = int.tryParse(parts[indexes.$1]);
  final r = int.tryParse(parts[indexes.$2]);
  return q == null || r == null ? null : HexCoord(q, r);
}

List<CardId> _decisionRerollSources(GameState state, PendingDecision decision) {
  if (decision is! AwaitingRerollChoice || decision.availableRerolls == 0) {
    return const [];
  }
  final context = decision.context;
  final playerId = switch (context) {
    SkillCheckContext(:final playerId) => playerId,
    AttackRollContext(:final playerId) => playerId,
    _ => state.activePlayerId,
  };
  final player = state.players.where((hero) => hero.id == playerId).firstOrNull;
  if (player == null) return const [];
  if (context is SkillCheckContext) {
    return skillRerollSources(state, player, context.stat);
  }
  if (context is! AttackRollContext) return const [];
  final registry = EffectRegistry.standard();
  return [
    for (final id in InventoryRules.activeCardIds(player))
      if (state.cardDefinitions[id]?.behaviorIds.any(
            (behavior) => switch (registry[behavior]) {
              ModifyRollHook(:final rerollsPerAttack) => rerollsPerAttack > 0,
              _ => false,
            },
          ) ??
          false)
        id,
  ];
}
