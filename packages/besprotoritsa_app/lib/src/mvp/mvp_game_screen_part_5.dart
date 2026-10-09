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
    final eventOptions = switch (decision) {
      AwaitingEventOption(:final options) => options,
      _ => const <String>[],
    };
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
    final decisionPlayer = switch (decision) {
      AwaitingTerminalPick(:final playerId) =>
        state.players.where((player) => player.id == playerId).firstOrNull,
      _ => null,
    };
    final targetPlayerName = targetPlayer == null
        ? null
        : fullRuntimeCharacterName(targetPlayer.characterId);
    final rerollSources = _decisionRerollSources(state, decision);
    final prompt = _decisionPrompt(decision, strings);
    final terminalDecision = decision is AwaitingTerminalPick
        ? decision as AwaitingTerminalPick
        : null;
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
            content: terminalDecision != null
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(prompt),
                        if (decisionPlayer != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Ваши кредиты: ₡${decisionPlayer.credits}',
                            ),
                          ),
                        for (final cardId in terminalDecision.offeredCards)
                          _terminalOfferCard(
                            context,
                            ref,
                            state,
                            terminalDecision,
                            cardId,
                          ),
                      ],
                    ),
                  )
                : eventId == null
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
                          Text(
                            _coordinateOptionPrompt(coordinateOptions.values),
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
                        for (final option in eventOptions)
                          if (!coordinateOptions.containsValue(option))
                            _eventOptionControl(
                              context,
                              ref,
                              state,
                              eventId,
                              option,
                            ),
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
        child: Text(
          availableRerolls > 0 ? strings.keepResult : 'Продолжить',
        ),
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
  AwaitingEventOption() => const [],
  AwaitingTerminalPick() => [
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

Widget _terminalOfferCard(
  BuildContext context,
  WidgetRef ref,
  GameState state,
  AwaitingTerminalPick decision,
  String cardId,
) {
  final definition = state.cardDefinitions[cardId];
  final player = state.players
      .where((entry) => entry.id == decision.playerId)
      .firstOrNull;
  final cost = definition?.cost ?? 0;
  final affordable =
      definition != null && player != null && player.credits >= cost;
  final name = _inventoryCardName(state, cardId);
  final description =
      state.contentTranslations['content.supply.$cardId.description'];
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GameCardSurface(
      key: ValueKey<String>('terminal-offer-$cardId'),
      material: GameCardMaterial.item,
      overlayColor: const Color(0xD91B1510),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameCardArtwork(
            cardId: cardId,
            kind: GameCardArtworkKind.supply,
            width: 76,
            height: 104,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFFFF1D5),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(description ?? 'Описание карты недоступно.'),
                const SizedBox(height: 8),
                Text('Цена: ₡$cost'),
                if (player != null && !affordable)
                  Text('Не хватает: ₡${cost - player.credits}'),
                const SizedBox(height: 6),
                FilledButton(
                  key: ValueKey<String>('terminal-buy-$cardId'),
                  onPressed: !affordable
                      ? null
                      : () => ref
                            .read(gameControllerProvider.notifier)
                            .dispatch(
                              ResolvePendingDecisionCommand(
                                TerminalPickChoice(cardId),
                              ),
                            ),
                  child: Text('Купить · ₡$cost'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _eventOptionControl(
  BuildContext context,
  WidgetRef ref,
  GameState state,
  String eventId,
  String option,
) {
  final check = _eventOptionSkillCheck(state, eventId, option);
  final playerId = switch (state.pendingDecision) {
    AwaitingEventOption(:final playerId) => playerId,
    _ => null,
  };
  final player = playerId == null
      ? null
      : state.players.where((entry) => entry.id == playerId).firstOrNull;
  final pool = check == null || player == null
      ? null
      : playerStatValue(state, player, check.$1);
  final statName = check == null ? null : _eventStatName(check.$1);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: ValueKey<String>('event-option-$option'),
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(
                ResolvePendingDecisionCommand(EventOptionChoice(option)),
              ),
          child: Text(_eventOptionLabel(state, eventId, option)),
        ),
        if (check != null) ...[
          Text(
            'Проверка ${_eventStatGenitive(check.$1)} · сложность ${check.$2}',
          ),
          if (pool != null) Text('Ваша $statName — $pool'),
        ],
      ],
    ),
  );
}

(StatType, int)? _eventOptionSkillCheck(
  GameState state,
  String eventId,
  String option,
) {
  final index = int.tryParse(option.replaceFirst('option-', ''));
  final rawOptions = state.eventDefinitions[eventId]?['options'];
  if (index == null ||
      rawOptions is! List<Object?> ||
      index < 1 ||
      index > rawOptions.length) {
    return null;
  }
  final rawOption = rawOptions[index - 1];
  if (rawOption is! Map<String, Object?>) return null;
  final rawCheck = rawOption['skillCheck'];
  if (rawCheck is! Map<String, Object?>) return null;
  final skill = rawCheck['skill'];
  final difficulty = rawCheck['difficulty'];
  if (skill is! String || difficulty is! int) return null;
  final stat = StatType.values
      .where((value) => value.name == skill)
      .firstOrNull;
  return stat == null ? null : (stat, difficulty);
}

String _eventStatName(StatType stat) => switch (stat) {
  StatType.strength => 'сила',
  StatType.combatStrength => 'боевая сила',
  StatType.science => 'наука',
  StatType.repair => 'ремонт',
  StatType.endurance => 'выносливость',
  StatType.agility => 'ловкость',
};

String _eventStatGenitive(StatType stat) => switch (stat) {
  StatType.strength || StatType.combatStrength => 'силы',
  StatType.science => 'науки',
  StatType.repair => 'ремонта',
  StatType.endurance => 'выносливости',
  StatType.agility => 'ловкости',
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

String _coordinateOptionPrompt(Iterable<String> options) {
  final kinds = options.map((option) => option.split(':').first).toSet();
  if (kinds.length == 1 && kinds.single == 'reveal') {
    return 'Выберите любой закрытый фрагмент — он откроется после выбора.';
  }
  if (kinds.every((kind) => kind == 'sector' || kind == 'place')) {
    return 'Выберите подсвеченный сектор, в котором разместить монстра.';
  }
  if (kinds.every((kind) => kind == 'move' || kind == 'move_spawn')) {
    return 'Выберите подсвеченный сектор для перемещения.';
  }
  return 'Выберите один из подсвеченных секторов карты.';
}

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
  if (decision.rerollSources.isNotEmpty) return decision.rerollSources;
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
