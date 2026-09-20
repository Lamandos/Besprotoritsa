import 'package:besprotoritsa_app/src/game/event_queue.dart';
import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Boundary around the static ship artwork and hex tiles.
const ValueKey<String> mvpBoardRepaintBoundaryKey = ValueKey<String>(
  'mvp-board-static-layer',
);

/// Alias retained for callers that describe the static boundary explicitly.
const ValueKey<String> mvpBoardStaticRepaintBoundaryKey =
    mvpBoardRepaintBoundaryKey;

/// Boundary around hero and monster tokens.
const mvpBoardTokensRepaintBoundaryKey = ValueKey<String>(
  'mvp-board-tokens-layer',
);

/// The pannable board viewport.
const mvpBoardInteractiveViewerKey = ValueKey<String>('mvp-board-viewport');

/// Compact portrait layout root.
const mvpCompactLayoutKey = ValueKey<String>('mvp-compact-layout');

/// Three-panel landscape layout root.
const mvpWideLayoutKey = ValueKey<String>('mvp-wide-layout');

/// Inventory sheet root.
const mvpInventorySheetKey = ValueKey<String>('mvp-inventory-sheet');

/// Quest journal sheet root.
const mvpJournalSheetKey = ValueKey<String>('mvp-journal-sheet');

/// Compact-layout inventory trigger.
const mvpInventoryButtonKey = ValueKey<String>('mvp-inventory-button');

/// Compact-layout quest journal trigger.
const mvpJournalButtonKey = ValueKey<String>('mvp-journal-button');

const _minimumTouchTarget = Size(48, 48);
const _wideLayoutMinimumWidth = 840.0;

/// The playable board, adaptive command palette, animation status, and log.
class MvpGameScreen extends ConsumerWidget {
  /// Creates the MVP game screen.
  const MvpGameScreen({this.onManualSaveRequested, super.key});

  /// Called with the current immutable snapshot when the player saves.
  final Future<void> Function(GameState state)? onManualSaveRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final outcome = _gameOutcome(state);
    if (outcome != null) {
      return _GameOutcomeScreen(outcome: outcome, state: state);
    }
    final queue = ref.read(eventQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) => _MvpGameLayout(
        state: state,
        queue: queue,
        onManualSaveRequested: onManualSaveRequested,
      ),
    );
  }
}

enum _GameOutcome { victory, defeat }

_GameOutcome? _gameOutcome(GameState state) {
  if (!state.isComplete) return null;
  return state.players.any((player) => player.alive)
      ? _GameOutcome.victory
      : _GameOutcome.defeat;
}

/// Final, non-interactive state of an expedition.
///
/// A completed rules snapshot is the source of truth: a surviving hero means
/// that the expedition won; no survivors means the reserve was exhausted.
class _GameOutcomeScreen extends StatelessWidget {
  const _GameOutcomeScreen({required this.outcome, required this.state});

  final _GameOutcome outcome;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final victory = outcome == _GameOutcome.victory;
    return Scaffold(
      key: ValueKey<String>(
        victory ? 'victory-screen' : 'defeat-screen',
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  victory
                      ? Icons.emoji_events_outlined
                      : Icons.dangerous_outlined,
                  size: 64,
                  color: victory ? Colors.amber.shade700 : Colors.red.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  victory ? 'Победа выживших' : 'Поражение',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  victory
                      ? 'Сюжетная цепочка завершена. Экипаж покидает корабль.'
                      : 'Все герои пали, а резерв персонажей исчерпан.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('Раунд ${state.round}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MvpGameLayout extends ConsumerWidget {
  const _MvpGameLayout({
    required this.state,
    required this.queue,
    required this.onManualSaveRequested,
  });

  final GameState state;
  final EventQueue queue;
  final Future<void> Function(GameState state)? onManualSaveRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = queue.isPlaying || state.pendingDecision != null;
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.mvpTitle),
        actions: [
          if (onManualSaveRequested != null)
            IconButton(
              key: const ValueKey<String>('manual-save-button'),
              tooltip: 'Сохранить партию',
              constraints: const BoxConstraints.tightFor(
                width: 48,
                height: 48,
              ),
              onPressed: () => onManualSaveRequested!(state),
              icon: const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= _wideLayoutMinimumWidth &&
                constraints.maxWidth > constraints.maxHeight;
            return Stack(
              children: [
                if (isWide)
                  _WideGameLayout(
                    key: mvpWideLayoutKey,
                    state: state,
                    queue: queue,
                    blocked: blocked,
                  )
                else
                  _CompactGameLayout(
                    key: mvpCompactLayoutKey,
                    state: state,
                    queue: queue,
                    blocked: blocked,
                  ),
                if (state.pendingDecision != null && !queue.isPlaying)
                  _PendingDecisionModal(decision: state.pendingDecision!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Three fixed regions give landscape displays an at-a-glance game overview.
class _WideGameLayout extends StatelessWidget {
  const _WideGameLayout({
    required this.state,
    required this.queue,
    required this.blocked,
    super.key,
  });

  final GameState state;
  final EventQueue queue;
  final bool blocked;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 256, child: _HeroRosterPanel(state: state)),
      const VerticalDivider(width: 1),
      Expanded(
        child: Column(
          children: [
            _GameStatus(state: state, queue: queue),
            Expanded(child: HexBoardWidget(state: state)),
            AbsorbPointer(
              absorbing: blocked,
              child: _CommandPanel(state: state, compact: true),
            ),
          ],
        ),
      ),
      const VerticalDivider(width: 1),
      SizedBox(
        width: 304,
        child: _JournalPanel(state: state, queue: queue),
      ),
    ],
  );
}

/// Portrait screens reserve the board for play and reveal supporting content
/// in bottom sheets instead of squeezing it into permanent columns.
class _CompactGameLayout extends StatelessWidget {
  const _CompactGameLayout({
    required this.state,
    required this.queue,
    required this.blocked,
    super.key,
  });

  final GameState state;
  final EventQueue queue;
  final bool blocked;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        children: [
          _GameStatus(state: state, queue: queue),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: HexBoardWidget(state: state),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: AbsorbPointer(
          absorbing: blocked,
          child: _MobileActionDock(state: state, queue: queue),
        ),
      ),
    ],
  );
}

class _GameStatus extends StatelessWidget {
  const _GameStatus({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(strings.roundStatus(state.round, state.actionsLeft)),
          const Spacer(),
          if (queue.current != null)
            Chip(
              key: const ValueKey<String>('animation-status'),
              avatar: const Icon(Icons.animation),
              label: Text(
                strings.animationStatus(_eventLabel(queue.current!, strings)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A pannable and zoomable viewport for a board with isolated static artwork.
class HexBoardWidget extends StatefulWidget {
  /// Creates a board viewport from [state].
  const HexBoardWidget({required this.state, super.key});

  /// State rendered by this board.
  final GameState state;

  @override
  State<HexBoardWidget> createState() => _HexBoardWidgetState();
}

class _HexBoardWidgetState extends State<HexBoardWidget> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    var dx = 0.0;
    var dy = 0.0;
    if (key == LogicalKeyboardKey.arrowLeft) {
      dx = 32;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      dx = -32;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      dy = 32;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      dy = -32;
    } else {
      return KeyEventResult.ignored;
    }
    _transformationController.value = _transformationController.value.clone()
      ..translateByDouble(dx, dy, 0, 1);
    return KeyEventResult.handled;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    _transformationController.value = _transformationController.value.clone()
      ..translateByDouble(
        -event.scrollDelta.dx,
        -event.scrollDelta.dy,
        0,
        1,
      );
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _handleKeyEvent,
    child: Listener(
      onPointerSignal: _handlePointerSignal,
      child: InteractiveViewer(
        key: mvpBoardInteractiveViewerKey,
        transformationController: _transformationController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(160),
        minScale: 0.65,
        trackpadScrollCausesScale: true,
        child: SizedBox(
          width: 520,
          height: 420,
          child: Stack(
            children: [
              RepaintBoundary(
                key: mvpBoardStaticRepaintBoundaryKey,
                child: _StaticBoardLayer(board: widget.state.board),
              ),
              RepaintBoundary(
                key: mvpBoardTokensRepaintBoundaryKey,
                child: _TokenLayer(
                  players: widget.state.players,
                  monsters: widget.state.monsters,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StaticBoardLayer extends StatelessWidget {
  const _StaticBoardLayer({required this.board});

  final List<HexTile> board;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF27324A), Color(0xFF111622)],
          ),
        ),
      ),
      for (final tile in board) _HexTileView(tile: tile),
    ],
  );
}

class _TokenLayer extends StatelessWidget {
  const _TokenLayer({required this.players, required this.monsters});

  final List<PlayerState> players;
  final List<MonsterInstance> monsters;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final player in players) _HeroToken(player: player),
      for (final monster in monsters) _MonsterToken(monster: monster),
    ],
  );
}

class _HexTileView extends StatelessWidget {
  const _HexTileView({required this.tile});

  final HexTile tile;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(tile.coord);
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Semantics(
        label: AppStrings.of(context).hexLabel(tile.coord.q, tile.coord.r),
        child: ClipPath(
          clipper: const _HexClipper(),
          child: Container(
            key: ValueKey<String>('hex-${tile.coord.q}-${tile.coord.r}'),
            width: 82,
            height: 72,
            color: tile.opened
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text('(${tile.coord.q}, ${tile.coord.r})'),
          ),
        ),
      ),
    );
  }
}

class _HeroToken extends StatelessWidget {
  const _HeroToken({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(player.coord);
    return Positioned(
      left: position.dx + 23,
      top: position.dy + 18,
      child: Semantics(
        label: AppStrings.of(
          context,
        ).heroLabel(player.id, player.coord.q, player.coord.r),
        child: CircleAvatar(
          key: ValueKey<String>(
            'hero-${player.id}-at-${player.coord.q}-${player.coord.r}',
          ),
          radius: 17,
          backgroundColor: player.id == 'ada' ? Colors.indigo : Colors.teal,
          child: Text(player.id.substring(0, 1).toUpperCase()),
        ),
      ),
    );
  }
}

class _MonsterToken extends StatelessWidget {
  const _MonsterToken({required this.monster});

  final MonsterInstance monster;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(monster.coord);
    return Positioned(
      left: position.dx + 50,
      top: position.dy + 32,
      child: Semantics(
        label: AppStrings.of(
          context,
        ).monsterLabel(monster.monsterId, monster.coord.q, monster.coord.r),
        child: const Icon(Icons.bug_report, color: Colors.deepOrange, size: 28),
      ),
    );
  }
}

class _MobileActionDock extends StatelessWidget {
  const _MobileActionDock({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final commands = _availableCommands(state, strings);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _TouchIconButton(
                  buttonKey: mvpInventoryButtonKey,
                  tooltip: 'Инвентарь',
                  icon: const Icon(Icons.backpack_outlined),
                  onPressed: () => _showInventorySheet(context, state),
                ),
                const VerticalDivider(indent: 10, endIndent: 10),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: commands.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => _CommandButton(
                      command: commands[index],
                      compact: true,
                    ),
                  ),
                ),
                const VerticalDivider(indent: 10, endIndent: 10),
                _TouchIconButton(
                  buttonKey: mvpJournalButtonKey,
                  tooltip: 'Журнал заданий',
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => _showJournalSheet(context, state, queue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TouchIconButton extends StatelessWidget {
  const _TouchIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key buttonKey;
  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: buttonKey,
    tooltip: tooltip,
    constraints: const BoxConstraints.tightFor(
      width: 48,
      height: 48,
    ),
    onPressed: onPressed,
    icon: icon,
  );
}

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

List<String> _activeQuests(GameState state) => [
  for (final questId in state.quests.storyQuestIds)
    if (state.quests.statusOf(questId) == QuestStatus.active) questId,
  for (final entry in state.quests.personalTasksByPlayer.entries)
    for (final questId in entry.value)
      if (state.quests.statusOf(questId) == QuestStatus.active) questId,
];

class _PendingDecisionModal extends ConsumerWidget {
  const _PendingDecisionModal({required this.decision});

  final PendingDecision decision;

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
            actions: _decisionActions(ref, decision, strings),
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
) => switch (decision) {
  AwaitingRerollChoice(:final availableRerolls) => [
    if (availableRerolls > 0)
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
        child: Text(option),
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
    _NamedCommand(strings.next, const EndTurnCommand()),
  ];
  return [
    for (final candidate in candidates)
      if (validate(state, candidate.command) == null) candidate,
  ];
}

class _NamedCommand {
  const _NamedCommand(this.label, this.command);

  final String label;
  final GameCommand command;
}

Offset _positionFor(HexCoord coord) => Offset(
  108 + (coord.q + coord.r * .5) * 76,
  94 + coord.r * 64,
);

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
    ..moveTo(size.width * .25, 0)
    ..lineTo(size.width * .75, 0)
    ..lineTo(size.width, size.height * .5)
    ..lineTo(size.width * .75, size.height)
    ..lineTo(size.width * .25, size.height)
    ..lineTo(0, size.height * .5)
    ..close();

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}
