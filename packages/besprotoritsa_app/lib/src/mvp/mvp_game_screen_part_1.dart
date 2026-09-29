// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

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

/// Wide and compact movement confirmation trigger.
const mvpMoveConfirmButtonKey = ValueKey<String>('mvp-move-confirm-button');

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
    final screenSize = MediaQuery.sizeOf(context);
    final isWide =
        screenSize.width >= _wideLayoutMinimumWidth &&
        screenSize.width > screenSize.height;
    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
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
      endDrawer: Drawer(
        key: mvpJournalSheetKey,
        width: screenSize.width < 400 ? screenSize.width * .9 : 400,
        child: _JournalPanel(state: state, queue: queue),
      ),
      drawerScrimColor: Colors.black87,
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useWideLayout =
                  constraints.maxWidth >= _wideLayoutMinimumWidth &&
                  constraints.maxWidth > constraints.maxHeight;
              void openLog() => Scaffold.of(scaffoldContext).openEndDrawer();
              return Stack(
                children: [
                  if (useWideLayout)
                    _WideGameLayout(
                      key: mvpWideLayoutKey,
                      state: state,
                      queue: queue,
                      blocked: blocked,
                      onOpenLog: openLog,
                      onManualSaveRequested: onManualSaveRequested == null
                          ? null
                          : () => onManualSaveRequested!(state),
                    )
                  else
                    _CompactGameLayout(
                      key: mvpCompactLayoutKey,
                      state: state,
                      queue: queue,
                      blocked: blocked,
                      onOpenLog: openLog,
                    ),
                  if (state.pendingDecision != null && !queue.isPlaying)
                    _PendingDecisionModal(
                      decision: state.pendingDecision!,
                      state: state,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
