// This part file retains original docs and readable canvas coordinate expressions.
// ignore_for_file: public_member_api_docs, cascade_invocations, lines_longer_than_80_chars

part of 'mvp_game_screen.dart';

class _HullEngravingPainter extends CustomPainter {
  const _HullEngravingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x12D8C39A)
      ..strokeWidth = 1;
    final rune = Paint()
      ..color = const Color(0x1CB8894D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (var i = 0; i < 12; i++) {
      final y = size.height * i / 12;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y + 16),
        line,
      );
    }
    for (final x in <double>[size.width * .018, size.width * .982]) {
      final center = Offset(x, size.height * .53);
      canvas.drawCircle(center, 24, rune);
      canvas.drawLine(center.translate(-16, 0), center.translate(16, 0), rune);
      canvas.drawLine(center.translate(0, -16), center.translate(0, 16), rune);
      canvas.drawLine(
        center.translate(-11, -11),
        center.translate(11, 11),
        rune,
      );
      canvas.drawLine(
        center.translate(-11, 11),
        center.translate(11, -11),
        rune,
      );
    }
    final rivet = Paint()
      ..color = const Color(0xFF8B6B45).withValues(alpha: .6);
    for (final x in <double>[10, size.width - 10]) {
      for (final y in <double>[10, size.height - 10]) {
        canvas.drawCircle(Offset(x, y), 2.3, rivet);
      }
    }
  }

  @override
  bool shouldRepaint(_HullEngravingPainter oldDelegate) => false;
}

class _ImmersiveGameHeader extends StatelessWidget {
  const _ImmersiveGameHeader({
    required this.state,
    required this.onSave,
  });

  final GameState state;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Container(
    height: 126,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.flare, size: 34, color: Color(0xFFD3AD75)),
        const SizedBox(width: 12),
        SizedBox(
          width: 230,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'БЕСПРОТОРИЦА',
                  style: TextStyle(
                    color: Color(0xFFF1E5CA),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.8,
                    fontFamily: 'serif',
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'КОРАБЛЬ ПОМНИТ. ЛЮДИ ПРОДОЛЖАЮТ.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFD8C39A).withValues(alpha: .78),
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ДАЛЬШЕ  •  ЕСТЬ  •  ЖИЗНЬ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFE8D8BA),
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ГЛАВА I  •  ПРОБУЖДЕНИЕ',
                style: TextStyle(
                  color: Color(0xFFD8C39A),
                  fontFamily: 'serif',
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        const _ShipPorthole(),
        const SizedBox(width: 12),
        if (onSave != null)
          IconButton(
            key: const ValueKey<String>('manual-save-button'),
            tooltip: 'Сохранить партию',
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
          ),
      ],
    ),
  );
}

class _ShipPorthole extends StatelessWidget {
  const _ShipPorthole();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 174,
    height: 84,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'СЕКТОР',
          style: TextStyle(
            color: Color(0xFFCDBA96),
            fontFamily: 'serif',
            fontSize: 10,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'ПЕРУН-7',
          style: TextStyle(
            color: Color(0xFFE6D6B8),
            fontFamily: 'serif',
            fontSize: 14,
            letterSpacing: 2.2,
          ),
        ),
        Container(
          width: 92,
          margin: const EdgeInsets.symmetric(vertical: 4),
          height: 1,
          color: const Color(0x998D704D),
        ),
        const Text(
          'ГОД 2147',
          style: TextStyle(
            color: Color(0xFFCDBA96),
            fontFamily: 'serif',
            fontSize: 9,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class _EventCardPanel extends StatelessWidget {
  const _EventCardPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final activeQuests = _activeQuests(state);
    final eventId = switch (state.pendingDecision) {
      AwaitingEventOption(:final eventId) => eventId,
      _ => null,
    };
    final cardTitle = eventId != null
        ? _eventCardTitle(eventId)
        : state.pendingDecision == null
        ? 'ОЖИДАНИЕ СОБЫТИЯ'
        : strings.decisionRequired.toUpperCase();
    final cardCopy = switch (eventId) {
      'cabin-noise' =>
        'Из кают-компании доносится глухой скрежет. В полумраке мелькает тень. Возможно, вас уже заметили.',
      null when state.pendingDecision != null => _decisionPrompt(
        state.pendingDecision!,
        strings,
      ),
      null => 'Новые сведения появятся, когда событие будет открыто.',
      _ => _decisionPrompt(state.pendingDecision!, strings),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD6BF95), Color(0xFFC6AA7D), Color(0xFFD9C398)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8B683B), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
      ),
      child: CustomPaint(
        painter: const _PaperStainPainter(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_stories, size: 17, color: Color(0xFF60472C)),
                  SizedBox(width: 7),
                  Text(
                    'СОБЫТИЕ',
                    style: TextStyle(
                      color: Color(0xFF493621),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 176,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF684A2E), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (eventId == 'cabin-noise')
                      Image.asset(
                        'assets/images/cabin_noise_scene.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: Color(0xFF30241B),
                              child: Icon(
                                Icons.bug_report,
                                size: 72,
                                color: Color(0xFFC75B32),
                              ),
                            ),
                      )
                    else
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF354049),
                              Color(0xFF171A1B),
                              Color(0xFF28231D),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_stories_outlined,
                            size: 58,
                            color: Color(0xFFB99A6A),
                          ),
                        ),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x33201811)],
                        ),
                      ),
                    ),
                    const CustomPaint(painter: _CardRunePainter()),
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(
                        Icons.flare,
                        size: 15,
                        color: Color(0xFFE3CC9F),
                      ),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(
                        Icons.flare,
                        size: 15,
                        color: Color(0xFFE3CC9F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF392819),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  cardCopy,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF493A2A),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF9B8057)),
              Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 17,
                    color: Color(0xFF694B2F),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      activeQuests.isEmpty
                          ? 'ЗАДАНИЕ НЕ ПОЛУЧЕНО'
                          : _questCardLabel(activeQuests.first),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF513B27),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _eventCardTitle(String eventId) => switch (eventId) {
  'cabin-noise' => 'ШУМ В КАЮТЕ',
  _ => 'СОБЫТИЕ В СЕКТОРЕ',
};

class _PaperStainPainter extends CustomPainter {
  const _PaperStainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stain = Paint()..color = const Color(0x14715332);
    final scratch = Paint()
      ..color = const Color(0x255D472D)
      ..strokeWidth = .7;
    for (var i = 0; i < 160; i++) {
      final x = (i * 73 % 997) / 997 * size.width;
      final y = (i * 137 % 991) / 991 * size.height;
      canvas.drawCircle(Offset(x, y), (i % 3 + 1).toDouble(), stain);
      if (i % 7 == 0) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 5 + i % 11, y + 1.5),
          scratch,
        );
      }
    }
    final corner = Paint()
      ..color = const Color(0x665F482D)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final point in <Offset>[
      const Offset(14, 14),
      Offset(size.width - 14, 14),
      Offset(14, size.height - 14),
      Offset(size.width - 14, size.height - 14),
    ]) {
      canvas.drawCircle(point, 5, corner);
      canvas.drawLine(point.translate(-8, 0), point.translate(8, 0), corner);
      canvas.drawLine(point.translate(0, -8), point.translate(0, 8), corner);
    }
  }

  @override
  bool shouldRepaint(_PaperStainPainter oldDelegate) => false;
}

class _CardRunePainter extends CustomPainter {
  const _CardRunePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x32D8C39A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width * .5, size.height * .5);
    canvas.drawCircle(center, 36, paint);
    canvas.drawLine(center.translate(-48, 0), center.translate(48, 0), paint);
    canvas.drawLine(center.translate(0, -48), center.translate(0, 48), paint);
    for (final offset in <Offset>[
      const Offset(18, 20),
      Offset(size.width - 18, 20),
      Offset(18, size.height - 20),
      Offset(size.width - 18, size.height - 20),
    ]) {
      canvas.drawLine(offset.translate(-5, 0), offset.translate(5, 0), paint);
      canvas.drawLine(offset.translate(0, -5), offset.translate(0, 5), paint);
      canvas.drawCircle(offset, 8, paint);
    }
  }

  @override
  bool shouldRepaint(_CardRunePainter oldDelegate) => false;
}

String _questCardLabel(String id) => switch (id) {
  'chapter-1-awakening' => 'ПРОБУЖДЕНИЕ',
  _ => id.replaceAll('-', ' ').toUpperCase(),
};

class _WideActionDock extends StatelessWidget {
  const _WideActionDock({
    required this.state,
    required this.onOpenLog,
    required this.selectedDestination,
    required this.selectedPlayerId,
    required this.onClearDestination,
  });

  final GameState state;
  final VoidCallback onOpenLog;
  final HexCoord? selectedDestination;
  final String selectedPlayerId;
  final VoidCallback onClearDestination;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final commands = _availableCommands(state, strings);
    final endTurn = commands.where(
      (command) => command.command is EndTurnCommand,
    );
    final endTurnCommand = endTurn.firstOrNull;
    final actions = commands.where(
      (command) =>
          command.command is! EndTurnCommand && command.command is! MoveCommand,
    );
    return Container(
      height: 146,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6382A20), Color(0xE01B1713)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF8E6B43), width: 1.4),
        ),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 14)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 78),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _MoveConfirmButton(
                    state: state,
                    selectedDestination: selectedDestination,
                    selectedPlayerId: selectedPlayerId,
                    onClearDestination: onClearDestination,
                  );
                }
                return _WideCommandButton(
                  command: actions.elementAt(index - 1),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _DockInventoryButton(
            state: state,
            selectedPlayerId: selectedPlayerId,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 338,
            height: 112,
            child: _WideCommandButton(
              command:
                  endTurnCommand ??
                  _NamedCommand(strings.next, const EndTurnCommand()),
              enabled: endTurnCommand != null,
            ),
          ),
          IconButton(
            key: const ValueKey<String>('wide-turn-log-button-bottom'),
            tooltip: 'Журнал ходов',
            onPressed: onOpenLog,
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
    );
  }
}

class _DockInventoryButton extends StatelessWidget {
  const _DockInventoryButton({
    required this.state,
    required this.selectedPlayerId,
  });

  final GameState state;
  final String selectedPlayerId;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 108,
    height: 112,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      key: mvpInventoryButtonKey,
      onPressed: () => _showInventorySheet(
        context,
        state,
        selectedPlayerId: selectedPlayerId,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.backpack_outlined, size: 28),
          SizedBox(height: 8),
          Text('ИНВЕНТАРЬ', style: TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );
}

class _MoveConfirmButton extends ConsumerWidget {
  const _MoveConfirmButton({
    required this.state,
    required this.selectedDestination,
    required this.selectedPlayerId,
    required this.onClearDestination,
  });

  final GameState state;
  final HexCoord? selectedDestination;
  final String selectedPlayerId;
  final VoidCallback onClearDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = selectedDestination;
    final targetTile = target == null ? null : state.tileAt(target);
    final cost = targetTile?.opened ?? false ? 1 : 2;
    final selectedIsActive = selectedPlayerId == state.activePlayerId;
    final command = target == null ? null : MoveCommand(target);
    final canMove =
        command != null && selectedIsActive && validate(state, command) == null;
    final label = !selectedIsActive
        ? 'ЧУЖОЙ ХОД'
        : target == null
        ? 'ВЫБРАТЬ СЕКТОР'
        : 'ДВИЖЕНИЕ\n$cost ОД';
    return SizedBox(
      width: 98,
      height: 112,
      child: FilledButton(
        key: mvpMoveConfirmButtonKey,
        style: FilledButton.styleFrom(
          backgroundColor: canMove
              ? const Color(0xFF81582F)
              : const Color(0xFF30271E),
          foregroundColor: canMove
              ? const Color(0xFFFFE3AC)
              : const Color(0xFF9D8A6E),
          disabledBackgroundColor: const Color(0xFF28211A),
          disabledForegroundColor: const Color(0xFF88765E),
          side: BorderSide(
            color: canMove ? const Color(0xFFF1BB68) : const Color(0xFF725537),
            width: canMove ? 2 : 1,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        onPressed: canMove
            ? () {
                ref
                    .read(gameControllerProvider.notifier)
                    .dispatch(MoveCommand(target!));
                onClearDestination();
              }
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_walk, size: 27),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideCommandButton extends ConsumerWidget {
  const _WideCommandButton({required this.command, this.enabled = true});

  final _NamedCommand command;
  final bool enabled;

  bool get _isEndTurn => command.command is EndTurnCommand;
  bool get _isMove => command.command is MoveCommand;

  IconData get _icon {
    if (_isEndTurn) return Icons.hourglass_bottom;
    if (command.command is MoveCommand) return Icons.directions_walk;
    if (command.command is AttackCommand) return Icons.gavel_outlined;
    if (command.command is SkillCheckCommand) return Icons.visibility_outlined;
    return Icons.settings_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _isEndTurn
        ? 'ЗАВЕРШИТЬ ХОД'
        : _isMove
        ? 'ДВИЖЕНИЕ\n${command.label.toUpperCase()}'
        : command.label.toUpperCase();
    final child = _isEndTurn
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 19,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 27),
              const SizedBox(height: 8),
              SizedBox(
                width: 98,
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          );
    return SizedBox(
      width: _isEndTurn ? double.infinity : 98,
      height: _isEndTurn ? double.infinity : 112,
      child: _isEndTurn
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C3F28),
                foregroundColor: const Color(0xFFFFE8C2),
                side: const BorderSide(color: Color(0xFFE0A364), width: 1.4),
              ),
              onPressed: enabled
                  ? () => ref
                        .read(gameControllerProvider.notifier)
                        .dispatch(command.command)
                  : null,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _isMove
                    ? const Color(0xFF654628)
                    : const Color(0xAA211A15),
                foregroundColor: _isMove
                    ? const Color(0xFFFFE5B5)
                    : const Color(0xFFD8C39A),
                side: BorderSide(
                  color: _isMove
                      ? const Color(0xFFE2A85D)
                      : const Color(0xFF85623D),
                  width: _isMove ? 2 : 1,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
              onPressed: enabled
                  ? () => ref
                        .read(gameControllerProvider.notifier)
                        .dispatch(command.command)
                  : null,
              child: child,
            ),
    );
  }
}
