// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

// Painter coordinate expressions intentionally repeat canvas/paint receivers.
// Keep geometric expressions readable even when they exceed 80 columns.
// ignore_for_file: cascade_invocations, lines_longer_than_80_chars

part of 'mvp_game_screen.dart';

class _StaticBoardLayer extends StatelessWidget {
  const _StaticBoardLayer({
    required this.board,
    required this.contentTranslations,
    required this.selectedDestination,
    required this.onSelectDestination,
  });

  final List<HexTile> board;
  final Map<String, String> contentTranslations;
  final HexCoord? selectedDestination;
  final ValueChanged<HexCoord>? onSelectDestination;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(painter: _BoardConnectorPainter(board)),
      for (final tile in board)
        _HexTileView(
          tile: tile,
          contentTranslations: contentTranslations,
          position: _layoutPosition(tile.coord, board),
          selected:
              selectedDestination?.q == tile.coord.q &&
              selectedDestination?.r == tile.coord.r,
          onTap: onSelectDestination == null
              ? null
              : () => onSelectDestination!(tile.coord),
        ),
    ],
  );
}

class _TokenLayer extends StatelessWidget {
  const _TokenLayer({
    required this.players,
    required this.monsters,
    required this.board,
    required this.selectedPlayerId,
    required this.activePlayerId,
    required this.onSelectPlayer,
  });

  final List<PlayerState> players;
  final List<MonsterInstance> monsters;
  final List<HexTile> board;
  final String? selectedPlayerId;
  final String? activePlayerId;
  final ValueChanged<String>? onSelectPlayer;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final (index, player) in players.indexed)
        _HeroToken(
          player: player,
          tokenIndex: index,
          position: _layoutPosition(player.coord, board),
          selected: player.id == selectedPlayerId,
          activeTurn: player.id == activePlayerId,
          onTap: onSelectPlayer == null
              ? null
              : () => onSelectPlayer!(player.id),
        ),
      for (final monster in monsters)
        _MonsterToken(
          monster: monster,
          position: _layoutPosition(monster.coord, board),
        ),
    ],
  );
}

class _HexTileView extends StatelessWidget {
  const _HexTileView({
    required this.tile,
    required this.contentTranslations,
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final HexTile tile;
  final Map<String, String> contentTranslations;
  final Offset position;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isKnown = tile.opened;
    final genericTitle = !isKnown
        ? 'НЕИЗВЕДАНО'
        : switch (tile.type) {
            HexTileType.start => 'АНАБИОЗ',
            HexTileType.corridor => 'КОРИДОР',
            HexTileType.compartment => 'КАЮТ-КОМПАНИЯ',
            HexTileType.airlock => 'ШЛЮЗ',
          };
    final locationId = tile.locationId;
    final title = !isKnown || locationId == null
        ? genericTitle
        : contentTranslations['content.location.$locationId'] ?? genericTitle;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Semantics(
        label: AppStrings.of(context).hexLabel(tile.coord.q, tile.coord.r),
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: ClipPath(
              clipper: const _HexClipper(),
              child: SizedBox(
                width: 224,
                height: 192,
                child: Stack(
                  key: ValueKey<String>('hex-${tile.coord.q}-${tile.coord.r}'),
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isKnown
                              ? const [Color(0xFF67503A), Color(0xFF33271F)]
                              : const [Color(0xFF39332A), Color(0xFF211D18)],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _RoomTilePainter(
                        type: tile.type,
                        revealed: isKnown,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDCC79D), Color(0xFFB99A6A)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF54402A),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 5),
                          ],
                        ),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF34271B),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .9,
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _HexRimPainter(
                        active: isKnown,
                        selected: selected,
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
  }
}

class _HeroToken extends StatelessWidget {
  const _HeroToken({
    required this.player,
    required this.tokenIndex,
    required this.position,
    required this.selected,
    required this.activeTurn,
    required this.onTap,
  });

  final PlayerState player;
  final int tokenIndex;
  final Offset position;
  final bool selected;
  final bool activeTurn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx + 67 + (tokenIndex % 2) * 56,
      top: position.dy + 74 + (tokenIndex ~/ 2) * 42,
      child: Semantics(
        label: AppStrings.of(
          context,
        ).heroLabel(player.id, player.coord.q, player.coord.r),
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: AnimatedContainer(
              key: ValueKey<String>(
                'hero-${player.id}-at-${player.coord.q}-${player.coord.r}',
              ),
              duration: const Duration(milliseconds: 180),
              width: selected ? 50 : 42,
              height: selected ? 50 : 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeTurn
                    ? const Color(0xFF739B60)
                    : selected
                    ? const Color(0xFFD9A35D)
                    : const Color(0xFF745638),
                border: Border.all(
                  color: activeTurn
                      ? const Color(0xFFB5E28C)
                      : selected
                      ? const Color(0xFFFFD58E)
                      : const Color(0xFFC6A574),
                  width: activeTurn || selected ? 2 : 1,
                ),
                boxShadow: [
                  if (activeTurn)
                    const BoxShadow(
                      color: Color(0xAA72D45B),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  if (selected)
                    const BoxShadow(
                      color: Color(0x99E5A34C),
                      blurRadius: 14,
                    ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFB8894D),
                backgroundImage: AssetImage(
                  _heroPortraitPath(player.characterId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonsterToken extends StatelessWidget {
  const _MonsterToken({required this.monster, required this.position});

  final MonsterInstance monster;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx + 99,
      top: position.dy + 82,
      child: Semantics(
        label: AppStrings.of(
          context,
        ).monsterLabel(monster.monsterId, monster.coord.q, monster.coord.r),
        child: const Icon(Icons.bug_report, color: Color(0xFFC75B32), size: 28),
      ),
    );
  }
}

class _HexRimPainter extends CustomPainter {
  const _HexRimPainter({required this.active, required this.selected});

  final bool active;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .25, 2)
      ..lineTo(size.width * .75, 2)
      ..lineTo(size.width - 2, size.height * .5)
      ..lineTo(size.width * .75, size.height - 2)
      ..lineTo(size.width * .25, size.height - 2)
      ..lineTo(2, size.height * .5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected
            ? 4
            : active
            ? 2.2
            : 1.2
        ..color = selected
            ? const Color(0xFFFFCF76)
            : active
            ? const Color(0xFFD3AD75)
            : const Color(0xFF75634B),
    );
  }

  @override
  bool shouldRepaint(_HexRimPainter oldDelegate) =>
      active != oldDelegate.active || selected != oldDelegate.selected;
}

class _RoomTilePainter extends CustomPainter {
  const _RoomTilePainter({required this.type, required this.revealed});

  final HexTileType type;
  final bool revealed;

  @override
  void paint(Canvas canvas, Size size) {
    final metal = Paint()
      ..color = const Color(0xFFB8894D).withValues(alpha: .34);
    final seam = Paint()
      ..color = const Color(0xFF171513).withValues(alpha: .75)
      ..strokeWidth = 2;
    final light = Paint()
      ..color = const Color(0xFFFFC875).withValues(alpha: .88)
      ..strokeWidth = 2.4;
    final coolLight = Paint()
      ..color = const Color(0xFF8AC4CF).withValues(alpha: .82)
      ..strokeWidth = 3;

    for (var i = 0; i < 5; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 14), Offset(x, size.height * .74), seam);
      canvas.drawCircle(Offset(x + 8, 18), 2, metal);
    }
    canvas.drawLine(
      Offset(size.width * .1, size.height * .15),
      Offset(size.width * .9, size.height * .15),
      metal,
    );
    canvas.drawLine(
      Offset(size.width * .1, size.height * .73),
      Offset(size.width * .9, size.height * .73),
      seam,
    );

    switch (type) {
      case HexTileType.start:
        for (var i = 0; i < 3; i++) {
          final rect = Rect.fromLTWH(32 + i * 57, 42, 43, 87);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(20)),
            Paint()..color = const Color(0xFF101A1F),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(5), const Radius.circular(17)),
            Paint()
              ..color = const Color(0xFF6A9CA4).withValues(alpha: .52)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.drawLine(
            Offset(rect.left + 8, rect.top + 15),
            Offset(rect.right - 8, rect.top + 15),
            coolLight,
          );
        }
        canvas.drawLine(
          const Offset(28, 139),
          Offset(size.width - 28, 139),
          light,
        );
      case HexTileType.corridor:
        canvas.drawLine(
          const Offset(24, 46),
          Offset(size.width - 24, 46),
          light,
        );
        canvas.drawLine(
          const Offset(24, 57),
          Offset(size.width - 24, 57),
          metal,
        );
        for (var i = 0; i < 7; i++) {
          final y = 76 + i * 13.0;
          canvas.drawLine(Offset(50, y), Offset(size.width - 50, y), seam);
        }
        final rail = Paint()
          ..color = const Color(0xFFBA935B)
          ..strokeWidth = 3;
        canvas.drawLine(const Offset(38, 70), const Offset(38, 139), rail);
        canvas.drawLine(
          Offset(size.width - 38, 70),
          Offset(size.width - 38, 139),
          rail,
        );
      case HexTileType.compartment:
        final table = Rect.fromLTWH(size.width * .34, 69, 72, 38);
        canvas.drawRRect(
          RRect.fromRectAndRadius(table, const Radius.circular(5)),
          Paint()..color = const Color(0xFF805934),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(table.deflate(4), const Radius.circular(3)),
          Paint()
            ..color = const Color(0xFFD1AC6B).withValues(alpha: .8)
            ..style = PaintingStyle.stroke,
        );
        for (final chair in <Offset>[
          Offset(size.width * .27, 80),
          Offset(size.width * .68, 80),
          Offset(size.width * .4, 119),
          Offset(size.width * .6, 119),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: chair, width: 20, height: 14),
              const Radius.circular(3),
            ),
            Paint()..color = const Color(0xFF463226),
          );
        }
        canvas.drawCircle(Offset(size.width * .5, 52), 5, light);
      case HexTileType.airlock:
        final door = Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .48),
          width: 85,
          height: 100,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(door, const Radius.circular(40)),
          Paint()..color = const Color(0xFF161819),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(door.deflate(6), const Radius.circular(35)),
          Paint()
            ..color = const Color(0xFFD2AA6A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawLine(
          const Offset(34, 54),
          Offset(size.width - 34, 54),
          light,
        );
    }

    if (!revealed) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xC9151514),
      );
      final hatch = Paint()
        ..color = const Color(0x40C6A16D)
        ..strokeWidth = 1.2;
      for (var i = -4; i < 10; i++) {
        canvas.drawLine(
          Offset(i * 30, size.height * .28),
          Offset(i * 30 + 62, size.height * .58),
          hatch,
        );
      }
      if (type == HexTileType.compartment) {
        _paintCompartmentShadow(canvas, size);
      }
      canvas.drawCircle(
        Offset(size.width * .5, 56),
        3,
        Paint()..color = const Color(0xFF8C4B32),
      );
    }
  }

  void _paintCompartmentShadow(Canvas canvas, Size size) {
    final center = Offset(size.width * .53, size.height * .48);
    final halo = Paint()
      ..color = const Color(0x55B02E21)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center.translate(0, 44), 28, halo);
    final marker = Paint()
      ..color = const Color(0xCCB62E27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 47), width: 66, height: 21),
      marker,
    );
    final shadow = Paint()..color = const Color(0xFF100E0D);
    final silhouette = Path()
      ..moveTo(center.dx - 34, center.dy + 40)
      ..lineTo(center.dx - 20, center.dy + 7)
      ..lineTo(center.dx - 24, center.dy - 8)
      ..lineTo(center.dx - 13, center.dy - 28)
      ..lineTo(center.dx - 5, center.dy - 15)
      ..lineTo(center.dx + 2, center.dy - 37)
      ..lineTo(center.dx + 10, center.dy - 14)
      ..lineTo(center.dx + 24, center.dy - 26)
      ..lineTo(center.dx + 22, center.dy - 5)
      ..lineTo(center.dx + 35, center.dy + 26)
      ..lineTo(center.dx + 18, center.dy + 18)
      ..lineTo(center.dx + 19, center.dy + 42)
      ..close();
    canvas.drawPath(silhouette, shadow);
    canvas.drawCircle(
      center.translate(-5, -13),
      3,
      Paint()..color = const Color(0xFFE34D32),
    );
  }

  @override
  bool shouldRepaint(_RoomTilePainter oldDelegate) =>
      type != oldDelegate.type || revealed != oldDelegate.revealed;
}

class _BoardConnectorPainter extends CustomPainter {
  const _BoardConnectorPainter(this.board);

  final List<HexTile> board;

  @override
  void paint(Canvas canvas, Size size) {
    if (board.length != 3 ||
        !board.any((tile) => tile.type == HexTileType.start)) {
      return;
    }
    final start = _layoutPosition(
      board.firstWhere((tile) => tile.type == HexTileType.start).coord,
      board,
    );
    final corridorTile = board
        .where((tile) => tile.type == HexTileType.corridor)
        .firstOrNull;
    final roomTile = board
        .where((tile) => tile.type == HexTileType.compartment)
        .firstOrNull;
    if (corridorTile == null || roomTile == null) return;
    final corridor = _layoutPosition(corridorTile.coord, board);
    final room = _layoutPosition(roomTile.coord, board);
    final points = <(Offset, Offset)>[
      (
        Offset(start.dx + 75, start.dy + 158),
        Offset(corridor.dx + 168, corridor.dy + 34),
      ),
      (
        Offset(corridor.dx + 165, corridor.dy + 96),
        Offset(room.dx + 58, room.dy + 96),
      ),
    ];
    for (final (from, to) in points) {
      _paintCorridor(from, to, canvas);
    }
  }

  void _paintCorridor(Offset from, Offset to, Canvas canvas) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    final normal = Offset(-delta.dy / length, delta.dx / length);
    Path corridorPath(double halfWidth) => Path()
      ..moveTo(from.dx + normal.dx * halfWidth, from.dy + normal.dy * halfWidth)
      ..lineTo(to.dx + normal.dx * halfWidth, to.dy + normal.dy * halfWidth)
      ..lineTo(to.dx - normal.dx * halfWidth, to.dy - normal.dy * halfWidth)
      ..lineTo(from.dx - normal.dx * halfWidth, from.dy - normal.dy * halfWidth)
      ..close();

    canvas.drawPath(
      corridorPath(23),
      Paint()..color = const Color(0xFF161614),
    );
    canvas.drawPath(
      corridorPath(19),
      Paint()..color = const Color(0xFF917044),
    );
    canvas.drawPath(
      corridorPath(15),
      Paint()..color = const Color(0xFF263036),
    );
    for (final side in <double>[-9, 9]) {
      canvas.drawLine(
        from.translate(normal.dx * side, normal.dy * side),
        to.translate(normal.dx * side, normal.dy * side),
        Paint()
          ..color = const Color(0xFFD1A565)
          ..strokeWidth = 1.4,
      );
    }
    for (final ratio in <double>[.3, .7]) {
      final center = from + delta * ratio;
      canvas.drawLine(
        center.translate(normal.dx * -14, normal.dy * -14),
        center.translate(normal.dx * 14, normal.dy * 14),
        Paint()
          ..color = const Color(0xFF0F1517)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        center.translate(normal.dx * -12, normal.dy * -12),
        2,
        Paint()..color = const Color(0xFFE5A85C),
      );
      canvas.drawCircle(
        center.translate(normal.dx * 12, normal.dy * 12),
        2,
        Paint()..color = const Color(0xFFE5A85C),
      );
    }
  }

  @override
  bool shouldRepaint(_BoardConnectorPainter oldDelegate) =>
      !identical(board, oldDelegate.board);
}

class _MobileActionDock extends StatelessWidget {
  const _MobileActionDock({required this.state, required this.onOpenLog});

  final GameState state;
  final VoidCallback onOpenLog;

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
          color: const Color(0xFF30251D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF8B6B45)),
          ),
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
                  onPressed: onOpenLog,
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
