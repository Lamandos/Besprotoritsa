// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

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
