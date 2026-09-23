// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

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
