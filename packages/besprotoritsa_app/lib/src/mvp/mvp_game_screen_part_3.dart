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
    required this.selectableDestinations,
    required this.onSelectDestination,
  });

  final List<HexTile> board;
  final Map<String, String> contentTranslations;
  final HexCoord? selectedDestination;
  final Set<HexCoord> selectableDestinations;
  final ValueChanged<HexCoord>? onSelectDestination;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final tile in board.where(
        (tile) => tile.type == HexTileType.corridor,
      ))
        _tileView(tile),
      for (final tile in board.where(
        (tile) => tile.type != HexTileType.corridor,
      ))
        _tileView(tile),
    ],
  );

  Widget _tileView(HexTile tile) => _HexTileView(
    tile: tile,
    contentTranslations: contentTranslations,
    position: _layoutPosition(tile.coord, board),
    selected:
        (selectedDestination?.q == tile.coord.q &&
            selectedDestination?.r == tile.coord.r) ||
        selectableDestinations.contains(tile.coord),
    onTap: onSelectDestination == null
        ? null
        : () => onSelectDestination!(tile.coord),
  );
}

class _TokenLayer extends StatelessWidget {
  const _TokenLayer({
    required this.players,
    required this.monsters,
    required this.state,
    required this.board,
    required this.selectedPlayerId,
    required this.activePlayerId,
    required this.onSelectPlayer,
  });

  final List<PlayerState> players;
  final List<MonsterInstance> monsters;
  final GameState state;
  final List<HexTile> board;
  final String? selectedPlayerId;
  final String? activePlayerId;
  final ValueChanged<String>? onSelectPlayer;

  @override
  Widget build(BuildContext context) {
    final monstersByCoord = <String, List<MonsterInstance>>{};
    for (final monster in monsters) {
      monstersByCoord
          .putIfAbsent('${monster.coord.q},${monster.coord.r}', () => [])
          .add(monster);
    }
    return Stack(
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
        for (final group in monstersByCoord.values)
          for (final (index, monster) in group.indexed)
            _MonsterToken(
              monster: monster,
              state: state,
              position: _monsterTokenPosition(
                _layoutPosition(monster.coord, board),
                index: index,
                count: group.length,
              ),
            ),
      ],
    );
  }
}

Offset _monsterTokenPosition(
  Offset position, {
  required int index,
  required int count,
}) {
  const tokenWidth = 108.0;
  const tokenHeight = 82.0;
  const spacing = 4.0;
  final columns = math.sqrt(count).ceil();
  final rows = (count / columns).ceil();
  final column = index % columns;
  final row = index ~/ columns;
  final width = columns * (tokenWidth + spacing) - spacing;
  final height = rows * (tokenHeight + spacing) - spacing;
  return Offset(
    position.dx +
        99 +
        column * (tokenWidth + spacing) -
        width / 2 +
        tokenWidth / 2,
    position.dy +
        82 +
        row * (tokenHeight + spacing) -
        height / 2 +
        tokenHeight / 2,
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
    final isCorridor = tile.type == HexTileType.corridor;
    const tileWidth = 168.0;
    const tileHeight = 194.0;
    final isKnown = tile.opened && !tile.isBlocked;
    final genericTitle = switch (tile.type) {
      HexTileType.start => 'АНАБИОЗ',
      HexTileType.corridor => 'КОРИДОР',
      HexTileType.compartment => 'КАЮТ-КОМПАНИЯ',
      HexTileType.airlock => 'ШЛЮЗ',
    };
    final locationId = tile.locationId;
    final title = locationId == null
        ? genericTitle
        : contentTranslations['content.location.$locationId'] ?? genericTitle;
    final tileFace = SizedBox(
      width: tileWidth,
      height: isCorridor ? tileWidth * .58 : tileHeight,
      child: Stack(
        key: ValueKey<String>('hex-${tile.coord.q}-${tile.coord.r}'),
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scaleX: isCorridor ? 1.2 : 1,
            alignment: Alignment.centerRight,
            child: Image.asset(
              isKnown
                  ? _fieldTileArt(tile)
                  : isCorridor
                  ? 'assets/images/field-tiles/corridor-back.webp'
                  : 'assets/images/field-tiles/tile-back.webp',
              fit: isCorridor ? BoxFit.fill : BoxFit.cover,
            ),
          ),
          if (isKnown) ...[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x18000000),
                    Color(0x00000000),
                    Color(0xA6000000),
                  ],
                  stops: [0, .42, 1],
                ),
              ),
            ),
            if (tile.ventColor != VentColor.none)
              Positioned(
                top: isCorridor ? 0 : 42,
                right: isCorridor ? 4 : 20,
                bottom: isCorridor ? 0 : null,
                child: Center(child: _VentMarker(color: tile.ventColor)),
              ),
            if (!isCorridor)
              Positioned(
                left: 18,
                right: 18,
                bottom: 40,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 124),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFDCC79D),
                            Color(0xFFB99A6A),
                          ],
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF34271B),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          CustomPaint(
            painter: _HexRimPainter(
              active: isKnown,
              selected: selected,
              rectangular: isCorridor,
            ),
          ),
        ],
      ),
    );
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
            child: SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: isCorridor
                  ? Center(
                      child: Transform.rotate(
                        angle: _corridorAngle(tile),
                        child: tileFace,
                      ),
                    )
                  : ClipPath(
                      clipper: const _HexClipper(),
                      child: tileFace,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _fieldTileArt(HexTile tile) {
  final assetName = switch (tile.type) {
    HexTileType.start => 'anabiosis',
    HexTileType.airlock => 'airlock',
    HexTileType.corridor => switch (tile.ventColor) {
      VentColor.green => 'corridor-green',
      VentColor.red => 'corridor-red',
      VentColor.none => 'corridor',
    },
    HexTileType.compartment => switch (tile.locationId) {
      'anabiosis' => 'anabiosis',
      'crew-quarters' => 'crew-quarters',
      'engineering-control-post' => 'engineering-control-post',
      'reactor' => 'reactor',
      'medical-bay' => 'medical-bay',
      'laboratory' => 'laboratory',
      'main-computer' => 'main-computer',
      'escape-pods' => 'escape-pods',
      'storage' => 'storage',
      'flight-control' => 'flight-control',
      'armory' => 'armory',
      'dining-hall' => 'dining-hall',
      'morgue' => 'morgue',
      _ => 'crew-quarters',
    },
  };
  return 'assets/images/field-tiles/$assetName.webp';
}

class _VentMarker extends StatelessWidget {
  const _VentMarker({required this.color});

  final VentColor color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: color == VentColor.green
          ? 'Зелёная вентиляция'
          : 'Красная вентиляция',
      child: Image.asset(
        'assets/images/field-tiles/vent-${color.name}.webp',
        width: 40,
        height: 40,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

double _corridorAngle(HexTile tile) {
  final edges = tile.exits.toList()
    ..sort((left, right) => left.index - right.index);
  if (edges.isEmpty) return 0;
  var direction = Offset.zero;
  for (final edge in edges) {
    direction += _corridorVector(edge);
  }
  if (direction.distance < .001) direction = _corridorVector(edges.first);
  var angle = math.atan2(direction.dy, direction.dx);
  if (angle > math.pi / 2) angle -= math.pi;
  if (angle < -math.pi / 2) angle += math.pi;
  return angle;
}

Offset _corridorVector(HexEdge edge) => switch (edge) {
  HexEdge.north => const Offset(-84, -145),
  HexEdge.northEast => const Offset(84, -145),
  HexEdge.southEast => const Offset(168, 0),
  HexEdge.south => const Offset(84, 145),
  HexEdge.southWest => const Offset(-84, 145),
  HexEdge.northWest => const Offset(-168, 0),
};

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
              child: CharacterPortrait(
                characterId: player.characterId,
                size: Size(selected ? 44 : 36, selected ? 44 : 36),
                circle: true,
                borderColor: activeTurn
                    ? const Color(0xFFB5E28C)
                    : selected
                    ? const Color(0xFFFFD58E)
                    : const Color(0xFFC6A574),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonsterToken extends StatelessWidget {
  const _MonsterToken({
    required this.monster,
    required this.state,
    required this.position,
  });

  final MonsterInstance monster;
  final GameState state;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    final definition = state.monsterDefinitions[monster.monsterId];
    final nameKey = definition?['nameKey'];
    final monsterName = nameKey is String
        ? state.contentTranslations[nameKey] ?? monster.monsterId
        : monster.monsterId;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Semantics(
        button: true,
        label: AppStrings.of(
          context,
        ).monsterLabel(monster.monsterId, monster.coord.q, monster.coord.r),
        child: Tooltip(
          message: 'Карточка монстра: $monsterName',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showMonsterCard(context, state, monster, monsterName),
            child: SizedBox(
              width: 108,
              height: 82,
              child: GameCardArtwork(
                cardId: monster.monsterId,
                assetPath:
                    gameMonsterTokenArtworkAsset(monster.monsterId) ??
                    gameCardArtworkAsset(monster.monsterId),
                width: 108,
                height: 82,
                borderRadius: BorderRadius.zero,
                fit: BoxFit.contain,
                fallbackIcon: Icons.bug_report,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showMonsterCard(
  BuildContext context,
  GameState state,
  MonsterInstance monster,
  String monsterName,
) {
  final definition = state.monsterDefinitions[monster.monsterId];
  final descriptionKey = definition?['descKey'];
  final description = descriptionKey is String
      ? state.contentTranslations[descriptionKey]
      : null;
  final currentHealth = (monster.health - monster.damage).clamp(
    0,
    monster.health,
  );
  final activePlayer = state.players
      .where((player) => player.id == state.activePlayerId)
      .firstOrNull;
  final mayAttack =
      activePlayer?.coord == monster.coord &&
      validate(state, AttackCommand(monster.instanceId)) == null;
  final combatDice = activePlayer == null
      ? 0
      : _heroCombatDiceCount(state, activePlayer);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(monsterName),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: GameCardSurface(
            material: GameCardMaterial.monster,
            borderColor: const Color(0xFF8D6D46),
            overlayColor: const Color(0x990C0B0A),
            padding: const EdgeInsets.all(16),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Color(0xFFF1E5CA), height: 1.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (gameMonsterTokenArtworkAsset(monster.monsterId)
                      case final art?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: Image.asset(
                          art,
                          width: 320,
                          height: 210,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  const Text(
                    'МОНСТР',
                    style: TextStyle(
                      color: Color(0xFFD0A66D),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(description ?? 'Идентификатор: ${monster.monsterId}'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (activePlayer != null)
                        _monsterStat('Сила боя', '$combatDice'),
                      _monsterStat(
                        'Здоровье',
                        '$currentHealth/${monster.health}',
                      ),
                      _monsterStat('Защита', '${monster.defense}'),
                      _monsterStat('Атака', '${monster.attack}'),
                      _monsterStat('Движение', '${monster.movement}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (activePlayer != null)
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: mayAttack
                  ? () {
                      final beforeMonster = ref
                          .read(gameControllerProvider)
                          .monsters
                          .where(
                            (entry) => entry.instanceId == monster.instanceId,
                          )
                          .firstOrNull;
                      if (beforeMonster == null ||
                          !ref
                              .read(gameControllerProvider.notifier)
                              .dispatch(AttackCommand(monster.instanceId))) {
                        return;
                      }
                      final afterState = ref.read(gameControllerProvider);
                      final afterMonster = afterState.monsters
                          .where(
                            (entry) => entry.instanceId == monster.instanceId,
                          )
                          .firstOrNull;
                      final damage = afterMonster == null
                          ? beforeMonster.health - beforeMonster.damage
                          : afterMonster.damage - beforeMonster.damage;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              afterMonster == null
                                  ? 'Монстр уничтожен.'
                                  : afterState.pendingDecision != null
                                  ? 'Выберите результат переброса.'
                                  : damage > 0
                                  ? 'Атака нанесла $damage урона.'
                                  : 'Атака не нанесла урона.',
                            ),
                          ),
                        );
                    }
                  : null,
              child: const Text('Атаковать'),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

int _heroCombatDiceCount(GameState state, PlayerState player) {
  final strengthModifier = player.conditions.fold<int>(
    0,
    (total, conditionId) =>
        total +
        (state.conditionCards[conditionId]?.statModifiers[StatType.strength] ??
            0),
  );
  return math.max(
    1,
    player.stats.combatStrength + strengthModifier + player.weaponModifier,
  );
}

Widget _monsterStat(String label, String value) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
  decoration: BoxDecoration(
    color: const Color(0xAA28221D),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: const Color(0xFF8D6D46)),
  ),
  child: Text('$label: $value'),
);

class _HexRimPainter extends CustomPainter {
  const _HexRimPainter({
    required this.active,
    required this.selected,
    this.rectangular = false,
  });

  final bool active;
  final bool selected;
  final bool rectangular;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (rectangular) {
      path.addRect(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2));
    } else if (size.width > size.height) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(8),
        ),
      );
    } else {
      path
        ..moveTo(size.width * .5, 2)
        ..lineTo(size.width - 2, size.height * .25)
        ..lineTo(size.width - 2, size.height * .75)
        ..lineTo(size.width * .5, size.height - 2)
        ..lineTo(2, size.height * .75)
        ..lineTo(2, size.height * .25)
        ..close();
    }
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
      active != oldDelegate.active ||
      selected != oldDelegate.selected ||
      rectangular != oldDelegate.rectangular;
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
                  onPressed: () => _showInventorySheet(context),
                ),
                _CompactChestButton(state: state),
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
