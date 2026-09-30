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
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: AlertDialog(
            title: Text(strings.decisionRequired),
            content: Text(_decisionPrompt(decision, strings)),
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
