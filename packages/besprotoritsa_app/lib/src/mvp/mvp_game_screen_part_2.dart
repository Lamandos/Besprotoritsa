// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

/// Three fixed regions give landscape displays an at-a-glance game overview.
class _WideGameLayout extends StatefulWidget {
  const _WideGameLayout({
    required this.state,
    required this.queue,
    required this.blocked,
    required this.onOpenLog,
    required this.onManualSaveRequested,
    required this.onExitRequested,
    required this.onScaleText,
    required this.textScale,
    super.key,
  });

  final GameState state;
  final EventQueue queue;
  final bool blocked;
  final VoidCallback onOpenLog;
  final VoidCallback? onManualSaveRequested;
  final Future<void> Function()? onExitRequested;
  final VoidCallback onScaleText;
  final double textScale;

  @override
  State<_WideGameLayout> createState() => _WideGameLayoutState();
}

class _WideGameLayoutState extends State<_WideGameLayout>
    with SingleTickerProviderStateMixin {
  String? _selectedPlayerId;
  HexCoord? _selectedDestination;
  late final AnimationController _ambienceController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _ambienceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WideGameLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.activePlayerId != widget.state.activePlayerId) {
      _selectedPlayerId = widget.state.activePlayerId;
      _selectedDestination = null;
    }
  }

  String _selectedPlayer(GameState state) {
    if (_selectedPlayerId != null &&
        state.players.any((player) => player.id == _selectedPlayerId)) {
      return _selectedPlayerId!;
    }
    return state.activePlayerId ?? state.players.first.id;
  }

  void _selectPlayer(String playerId) {
    setState(() {
      _selectedPlayerId = playerId;
      _selectedDestination = null;
    });
  }

  void _selectDestination(HexCoord destination) =>
      setState(() => _selectedDestination = destination);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final queue = widget.queue;
    final selectedPlayerId = _selectedPlayer(state);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 1664).clamp(
          0.1,
          constraints.maxHeight / 928,
        );
        return Center(
          child: SizedBox(
            width: 1664 * scale,
            height: 928 * scale,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: 1664,
                  height: 928,
                  child: AnimatedBuilder(
                    animation: _ambienceController,
                    builder: (context, foreground) => Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(
                            'assets/images/ship_bark_backdrop.png',
                          ),
                          fit: BoxFit.fill,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0x22101822), Color(0x22170805)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        const CustomPaint(painter: _HullEngravingPainter()),
                        CustomPaint(
                          painter: _ShipAmbientLightPainter(
                            progress: _ambienceController.value,
                          ),
                        ),
                        _SleepingCatBackdrop(
                          progress: _ambienceController.value,
                        ),
                        Positioned(
                          left: 356,
                          top: 146,
                          width: 816,
                          height: 564,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 1.25,
                                sigmaY: 1.25,
                              ),
                              child: const ColoredBox(
                                color: Color(0x09100D09),
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _TablePulseSpillPainter(
                              progress: _ambienceController.value,
                            ),
                          ),
                        ),
                        if (foreground != null) foreground,
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 126,
                          child: _ImmersiveGameHeader(
                            state: state,
                            onSave: widget.onManualSaveRequested,
                            onExit: widget.onExitRequested,
                            onScaleText: widget.onScaleText,
                            textScale: widget.textScale,
                          ),
                        ),
                        Positioned(
                          left: 18,
                          top: 142,
                          width: 340,
                          height: 514,
                          child: _HeroRosterPanel(
                            state: state,
                            selectedPlayerId: selectedPlayerId,
                            onSelected: _selectPlayer,
                          ),
                        ),
                        Positioned(
                          left: 356,
                          top: 146,
                          width: 816,
                          height: 564,
                          child: Column(
                            children: [
                              _GameStatus(state: state, queue: queue),
                              Expanded(
                                child: HexBoardWidget(
                                  state: state,
                                  selectedPlayerId: selectedPlayerId,
                                  selectedDestination: _selectedDestination,
                                  onSelectPlayer: _selectPlayer,
                                  onSelectDestination: _selectDestination,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 92,
                          top: 142,
                          width: 360,
                          height: 548,
                          child: _EventCardPanel(state: state),
                        ),
                        Positioned(
                          left: 230,
                          right: 95,
                          bottom: 40,
                          height: 146,
                          child: AbsorbPointer(
                            absorbing: widget.blocked,
                            child: _WideActionDock(
                              state: state,
                              onOpenLog: widget.onOpenLog,
                              selectedDestination: _selectedDestination,
                              selectedPlayerId: selectedPlayerId,
                              onClearDestination: () => setState(
                                () => _selectedDestination = null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Portrait screens reserve the board for play and reveal supporting content
/// in bottom sheets instead of squeezing it into permanent columns.
class _CompactGameLayout extends StatelessWidget {
  const _CompactGameLayout({
    required this.state,
    required this.queue,
    required this.blocked,
    required this.onOpenLog,
    super.key,
  });

  final GameState state;
  final EventQueue queue;
  final bool blocked;
  final VoidCallback onOpenLog;

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
          child: _MobileActionDock(state: state, onOpenLog: onOpenLog),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D241C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF765A3C)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.brightness_3_outlined,
            size: 17,
            color: Color(0xFFD3AD75),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${strings.roundStatus(state.round, state.actionsLeft)} · '
              '${switch (state.phase) {
                GamePhase.playersTurn => 'ХОД ЭКИПАЖА',
                GamePhase.monstersTurn => 'ХОД МОНСТРОВ',
                GamePhase.eventsPhase => 'ФАЗА СОБЫТИЙ',
              }}',
              maxLines: 2,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
          ),
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
  const HexBoardWidget({
    required this.state,
    this.selectedPlayerId,
    this.selectedDestination,
    this.onSelectPlayer,
    this.onSelectDestination,
    super.key,
  });

  /// State rendered by this board.
  final GameState state;
  final String? selectedPlayerId;
  final HexCoord? selectedDestination;
  final ValueChanged<String>? onSelectPlayer;
  final ValueChanged<HexCoord>? onSelectDestination;

  @override
  State<HexBoardWidget> createState() => _HexBoardWidgetState();
}

class _HexBoardWidgetState extends State<HexBoardWidget> {
  final TransformationController _transformationController =
      TransformationController();
  bool _didInitialFit = false;

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

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _handleKeyEvent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final boardSize = _boardCanvasSize(widget.state.board);
        if (!_didInitialFit && !viewport.isEmpty && !boardSize.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _didInitialFit) return;
            final fitScale = math
                .min(
                  (viewport.width - 24) / boardSize.width,
                  (viewport.height - 24) / boardSize.height,
                )
                .clamp(.12, 1.0);
            final dx = (viewport.width - boardSize.width * fitScale) / 2;
            final dy = (viewport.height - boardSize.height * fitScale) / 2;
            _transformationController.value = Matrix4.identity()
              ..translateByDouble(dx, dy, 0, 1)
              ..scaleByDouble(fitScale, fitScale, fitScale, 1);
            _didInitialFit = true;
          });
        }
        return InteractiveViewer(
          key: mvpBoardInteractiveViewerKey,
          transformationController: _transformationController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(160),
          minScale: 0.12,
          maxScale: 2.25,
          scaleFactor: 560,
          child: SizedBox(
            width: boardSize.width,
            height: boardSize.height,
            child: Stack(
              children: [
                RepaintBoundary(
                  key: mvpBoardStaticRepaintBoundaryKey,
                  child: _StaticBoardLayer(
                    board: widget.state.board,
                    contentTranslations: widget.state.contentTranslations,
                    selectedDestination: widget.selectedDestination,
                    onSelectDestination: widget.onSelectDestination,
                  ),
                ),
                RepaintBoundary(
                  key: mvpBoardTokensRepaintBoundaryKey,
                  child: _TokenLayer(
                    players: widget.state.players,
                    monsters: widget.state.monsters,
                    board: widget.state.board,
                    selectedPlayerId: widget.selectedPlayerId,
                    activePlayerId: widget.state.phase == GamePhase.playersTurn
                        ? widget.state.activePlayerId
                        : null,
                    onSelectPlayer: widget.onSelectPlayer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
