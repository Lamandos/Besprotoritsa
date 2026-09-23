// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

class _CommandPanel extends StatelessWidget {
  const _CommandPanel({required this.state, required this.compact});

  final GameState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final commands = _availableCommands(state, strings);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.availableCommands),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final command in commands)
                _CommandButton(command: command, compact: compact),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends ConsumerWidget {
  const _CommandButton({required this.command, required this.compact});

  final _NamedCommand command;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: _minimumTouchTarget.height,
    child: FilledButton(
      style: compact
          ? FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            )
          : null,
      onPressed: () =>
          ref.read(gameControllerProvider.notifier).dispatch(command.command),
      child: Text(command.label),
    ),
  );
}

class _HeroRosterPanel extends StatelessWidget {
  const _HeroRosterPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: 'Отряд героев',
    icon: const Icon(Icons.groups_outlined),
    child: ListView.separated(
      itemCount: state.players.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final player = state.players[index];
        return ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(child: Text(player.id.substring(0, 1))),
          title: Text(player.characterId),
          subtitle: Text(
            'Здоровье: ${player.health - player.damage}/${player.health}',
          ),
          trailing: Text('₡${player.credits}'),
        );
      },
    ),
  );
}

class _JournalPanel extends StatelessWidget {
  const _JournalPanel({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: 'Журнал',
    icon: const Icon(Icons.menu_book_outlined),
    child: _JournalContents(state: state, queue: queue),
  );
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [icon, const SizedBox(width: 8), Text(title)]),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    ),
  );
}

class _JournalContents extends StatelessWidget {
  const _JournalContents({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final entries = <String>[
      ...state.log,
      ...queue.history.map((event) => _eventLabel(event, strings)),
    ];
    final activeQuests = _activeQuests(state);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(strings.eventLog),
        const SizedBox(height: 4),
        if (entries.isEmpty)
          const Text('Событий пока нет.')
        else
          for (final entry in entries) Text(entry),
        const SizedBox(height: 20),
        const Text('Активные задания'),
        const SizedBox(height: 4),
        if (activeQuests.isEmpty)
          const Text('Нет активных заданий.')
        else
          for (final quest in activeQuests)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(quest),
            ),
      ],
    );
  }
}

void _showInventorySheet(BuildContext context, GameState state) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _GameBottomSheet(
      key: mvpInventorySheetKey,
      title: 'Инвентарь',
      icon: const Icon(Icons.backpack_outlined),
      child: ListView.separated(
        itemCount: state.players.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final player = state.players[index];
          final inventory = player.backpack.isEmpty
              ? 'Рюкзак пуст'
              : player.backpack.join(', ');
          return ListTile(
            title: Text(player.characterId),
            subtitle: Text(inventory),
            trailing: Text('₡${player.credits}'),
          );
        },
      ),
    ),
  );
}

void _showJournalSheet(
  BuildContext context,
  GameState state,
  EventQueue queue,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _GameBottomSheet(
      key: mvpJournalSheetKey,
      title: 'Журнал заданий',
      icon: const Icon(Icons.menu_book_outlined),
      child: _JournalContents(state: state, queue: queue),
    ),
  );
}
