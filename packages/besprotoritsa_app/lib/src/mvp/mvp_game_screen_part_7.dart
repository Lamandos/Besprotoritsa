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
    required this.onExit,
    required this.onScaleText,
    required this.textScale,
  });

  final GameState state;
  final VoidCallback? onSave;
  final Future<void> Function()? onExit;
  final VoidCallback onScaleText;
  final double textScale;

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
        if (onExit != null)
          IconButton(
            key: const ValueKey<String>('pause-menu-button'),
            tooltip: 'Пауза и меню',
            onPressed: onExit,
            icon: const Icon(Icons.pause_circle_outline),
          ),
        IconButton(
          key: const ValueKey<String>('rules-reference-button'),
          tooltip: 'Справочник правил',
          onPressed: () => _openRulesReference(context),
          icon: const Icon(Icons.rule_folder_outlined),
        ),
        IconButton(
          key: const ValueKey<String>('text-scale-button'),
          tooltip: 'Размер текста: ${textScale.toStringAsFixed(2)}×',
          onPressed: onScaleText,
          icon: const Icon(Icons.text_fields),
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

class _EventCardPanel extends StatefulWidget {
  const _EventCardPanel({required this.state});

  final GameState state;

  @override
  State<_EventCardPanel> createState() => _EventCardPanelState();
}

class _EventCardPanelState extends State<_EventCardPanel> {
  String? _selectedCard;

  @override
  void didUpdateWidget(covariant _EventCardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingEventId(widget.state);
    if (pending != null && pending != _pendingEventId(oldWidget.state)) {
      _selectedCard = 'event:$pending';
    } else if (oldWidget.state.phase == GamePhase.eventsPhase &&
        widget.state.phase == GamePhase.playersTurn) {
      _selectedCard = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final quests = _activeQuests(state);
    final events = _visibleActiveEventIds(state);
    final pending = _pendingEventId(state);
    final cards = [
      for (final id in quests) 'quest:$id',
      for (final id in events) 'event:$id',
    ];
    final selected = cards.contains(_selectedCard)
        ? _selectedCard
        : pending != null
        ? 'event:$pending'
        : cards.firstOrNull;
    final isQuest = selected?.startsWith('quest:') ?? false;
    final id = selected?.substring(selected.indexOf(':') + 1);
    String titleOf(String key) {
      final cardId = key.substring(key.indexOf(':') + 1);
      return key.startsWith('quest:')
          ? _questCardLabel(state, cardId)
          : _runtimeEventText(state, cardId, 'nameKey') ??
                _eventCardTitle(cardId);
    }

    final title = selected == null ? 'Нет активных карт' : titleOf(selected);
    final description = id == null
        ? 'Новые карты появятся по ходу партии.'
        : isQuest
        ? _questCardDescription(state, id)
        : _runtimeEventText(state, id, 'descKey');
    final card = GameCardSurface(
      material: isQuest ? GameCardMaterial.story : GameCardMaterial.event,
      overlayColor: const Color(0xB91B1510),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_stories,
                size: 17,
                color: Color(0xFFE9C78E),
              ),
              const SizedBox(width: 7),
              Text(
                isQuest ? 'СЮЖЕТ' : 'СОБЫТИЕ',
                style: const TextStyle(
                  color: Color(0xFFFFEBC7),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey<String>('tracked-card-$selected'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFFFEBC7),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (id == 'cabin-noise') ...[
                    Image.asset(
                      'assets/images/cabin_noise_scene.png',
                      height: 176,
                      fit: BoxFit.cover,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    description ?? title,
                    style: const TextStyle(
                      color: Color(0xFFFFF0D1),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  if (isQuest && id != null) ...[
                    const SizedBox(height: 12),
                    if (id == 'chapter-1-awakening')
                      const Text(
                        'ЧТО ДЕЛАТЬ ДАЛЬШЕ\n'
                        'Доберитесь до КАЮТ-КОМПАНИИ '
                        'и выполните проверку науки.',
                        style: TextStyle(color: Color(0xFFFFE8BC)),
                      )
                    else
                      for (final condition
                          in (state.questDefinitions[id]?['conditions']
                                  as List<Object?>? ??
                              const []))
                        if (condition is Map<String, Object?>)
                          Text(
                            '${_questConditionLabel(state, condition)} · '
                            '${state.quests.conditionProgress[id]?[condition['id']] ?? 0}/'
                            '${condition['targetValue'] ?? 1}',
                            style: const TextStyle(color: Color(0xFFFFE8BC)),
                          ),
                  ],
                ],
              ),
            ),
          ),
          if (id != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showGameCardScan(
                  context,
                  cardId: id,
                  title: title,
                  kind: isQuest
                      ? GameCardArtworkKind.quest
                      : GameCardArtworkKind.event,
                ),
                child: const Text('Вся карта'),
              ),
            ),
        ],
      ),
    );
    if (cards.length < 2) return card;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: card),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final key = cards[index];
              final quest = key.startsWith('quest:');
              final cardId = key.substring(key.indexOf(':') + 1);
              return Tooltip(
                message: titleOf(key),
                child: Material(
                  color: key == selected
                      ? const Color(0xFFB8874E)
                      : const Color(0xFF34291F),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(9),
                  ),
                  child: InkWell(
                    key: ValueKey<String>(
                      'active-${quest ? 'quest' : 'event'}-tab-$cardId',
                    ),
                    onTap: () => setState(() => _selectedCard = key),
                    child: SizedBox(
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            quest
                                ? Icons.flag_outlined
                                : Icons.auto_stories_outlined,
                            size: 18,
                          ),
                          Text('${index + 1}'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String? _pendingEventId(GameState state) => switch (state.pendingDecision) {
  AwaitingEventOption(:final eventId) => eventId,
  AwaitingRerollChoice(context: SkillCheckContext(:final eventId)) => eventId,
  _ => null,
};

List<String> _visibleActiveEventIds(GameState state) {
  final pendingEventId = _pendingEventId(state);
  final discardPile = state.decks['events']?.discardPile.toSet() ?? const {};
  return {
    if (pendingEventId != null) pendingEventId,
    for (final player in state.players)
      for (final eventId in player.retainedEventCards)
        if (!discardPile.contains(eventId)) eventId,
  }.toList();
}

String _eventCardTitle(String eventId) => switch (eventId) {
  'cabin-noise' => 'ШУМ В КАЮТЕ',
  _ => 'СОБЫТИЕ В СЕКТОРЕ',
};

String? _runtimeEventText(GameState state, String eventId, String field) {
  final event = state.eventDefinitions[eventId];
  final key = event?[field];
  return key is String ? state.contentTranslations[key] : null;
}

String _eventOptionLabel(GameState state, String? eventId, String option) {
  if (option == 'horde|discard') return 'Сбросить весь рюкзак';
  if (option == 'horde|keep') return 'Оставить карты и получить урон';
  if (option.startsWith('market|')) {
    final parts = option.split('|');
    if (parts.length == 9) {
      return switch (parts[7]) {
        'buy' => 'Купить: ${parts[8].split(':').last}',
        'sell' => 'Продать: ${parts[8]}',
        'done' => 'Закончить торговлю',
        _ => option,
      };
    }
  }
  final sector = option.split(':');
  if (sector.length == 3 && sector.first == 'sector') {
    return 'Сектор ${sector[1]}, ${sector[2]}';
  }
  if (sector.length == 3 && sector.first == 'move') {
    return 'Перейти в сектор ${sector[1]}, ${sector[2]}';
  }
  if (sector.length == 4 && sector.first == 'move_spawn') {
    return 'Перейти в сектор ${sector[2]}, ${sector[3]} и вступить в бой';
  }
  if (sector.length == 3 && sector.first == 'reveal') {
    return 'Открыть фрагмент ${sector[1]}, ${sector[2]}';
  }
  if (sector.length == 4 && sector.first == 'place') {
    final monster = state.monsters
        .where((entry) => entry.instanceId == sector[1])
        .firstOrNull;
    final nameKey = monster == null
        ? null
        : state.monsterDefinitions[monster.monsterId]?['nameKey'];
    final name = nameKey is String
        ? state.contentTranslations[nameKey] ?? monster?.monsterId
        : monster?.monsterId;
    return 'Разместить ${name ?? 'монстра'} в секторе ${sector[2]}, ${sector[3]}';
  }
  if (option.startsWith('kill:')) {
    final monster = state.monsters
        .where((entry) => entry.instanceId == option.substring(5))
        .firstOrNull;
    final definition = monster == null
        ? null
        : state.monsterDefinitions[monster.monsterId];
    final nameKey = definition?['nameKey'];
    final name = nameKey is String
        ? state.contentTranslations[nameKey] ?? monster?.monsterId
        : monster?.monsterId;
    return 'Убить монстра: ${name ?? option.substring(5)}';
  }
  if (option.startsWith('pick:')) {
    final parts = option.split(':');
    final cardId = parts.length == 3 ? parts[2] : option;
    final name =
        state.contentTranslations['content.item.$cardId.name'] ??
        state.contentTranslations['content.supply.$cardId.name'] ??
        state.contentTranslations['content.special_item.$cardId.name'] ??
        cardId;
    return 'Выбрать: $name';
  }
  if (eventId == null) return option;
  final index = int.tryParse(option.replaceFirst('option-', ''));
  if (index == null) return option;
  final rawOptions = state.eventDefinitions[eventId]?['options'];
  if (rawOptions is! List<Object?> || index < 1 || index > rawOptions.length) {
    return option;
  }
  final rawOption = rawOptions[index - 1];
  if (rawOption is! Map<String, Object?>) return option;
  final key = rawOption['actionKey'];
  if (key is! String) return option;
  return state.contentTranslations[key] ?? option;
}

String _questCardLabel(GameState state, String id) {
  final definition = state.questDefinitions[id] ?? state.taskDefinitions[id];
  final key = definition?['nameKey'];
  final localized = key is String ? state.contentTranslations[key] : null;
  return localized ??
      switch (id) {
        'chapter-1-awakening' => 'ПРОБУЖДЕНИЕ',
        _ => id.replaceAll('-', ' ').toUpperCase(),
      };
}

String? _questCardDescription(GameState state, String id) {
  final definition = state.questDefinitions[id] ?? state.taskDefinitions[id];
  final key = definition?['descKey'];
  return key is String ? state.contentTranslations[key] : null;
}

Widget _questProgressSummary(GameState state, String id) {
  final definition = state.questDefinitions[id];
  final conditions = definition?['conditions'];
  final description = _questCardDescription(state, id);
  if (conditions is! List<Object?> || conditions.isEmpty) {
    return Text(
      description ?? 'Цель завершена автоматически.',
      style: const TextStyle(color: Color(0xFF493A2A)),
    );
  }
  final progress = state.quests.conditionProgress[id] ?? const {};
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (description != null)
        Text(
          description,
          maxLines: 3,
          style: const TextStyle(color: Color(0xFF493A2A)),
        ),
      for (final rawCondition in conditions)
        if (rawCondition is Map<String, dynamic>)
          Builder(
            builder: (context) {
              final condition = Map<String, Object?>.from(rawCondition);
              final conditionId = condition['id'] as String? ?? '';
              final value = progress[conditionId] ?? 0;
              final target = condition['targetValue'] as int? ?? 1;
              final complete = value >= target;
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      complete
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: complete
                          ? const Color(0xFF51723A)
                          : const Color(0xFF694B2F),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_questConditionLabel(state, condition)} · $value/$target',
                        style: const TextStyle(
                          color: Color(0xFF493A2A),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    ],
  );
}

String _questConditionLabel(GameState state, Map<String, Object?> condition) {
  String translated(String key, String fallback) =>
      state.contentTranslations[key] ?? fallback;
  final locationId = condition['locationId'] as String?;
  final location = locationId == null
      ? null
      : translated('content.location.$locationId', locationId);
  return switch (condition['type']) {
    'arrive' => 'Достичь: $location',
    'skill_check' =>
      'Проверка «${_statLabel(StatType.values.byName(condition['skill']! as String))}»'
          '${location == null ? '' : ' в $location'}',
    'kill_monster' =>
      'Победить: ${translated('content.monster.${condition['monsterId']}.name', condition['monsterId']! as String)}',
    'collect_item' =>
      'Получить: ${translated('content.item.${condition['itemId']}.name', condition['itemId']! as String)}',
    'equipped_for_battle' => 'Экипировать оружие или броню для боя',
    'counter' => 'Выполнить: ${condition['metric']}',
    _ => 'Выполнить условие',
  };
}

class _WideActionDock extends StatelessWidget {
  const _WideActionDock({
    required this.state,
    required this.onOpenLog,
    required this.selectedDestination,
    required this.selectedPlayerId,
  });

  final GameState state;
  final VoidCallback onOpenLog;
  final HexCoord? selectedDestination;
  final String selectedPlayerId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final globalCommands = _availableCommands(state, strings);
    final tileCommands = selectedPlayerId == state.activePlayerId
        ? _availableTileCommands(state, strings, selectedDestination)
        : const <_NamedCommand>[];
    final endTurn = globalCommands.where(
      (command) => command.command is EndTurnCommand,
    );
    final endTurnCommand = endTurn.firstOrNull;
    final actions = globalCommands.where(
      (command) =>
          command.command is! EndTurnCommand &&
          command.command is! MoveCommand &&
          command.command is! RevealTileCommand &&
          command.command is! OpenCorridorCommand &&
          command.command is! CloseCorridorCommand,
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
              itemCount: tileCommands.length + actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index < tileCommands.length) {
                  return _WideCommandButton(command: tileCommands[index]);
                }
                return _WideCommandButton(
                  command: actions.elementAt(index - tileCommands.length),
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

class _WideCommandButton extends ConsumerWidget {
  const _WideCommandButton({required this.command, this.enabled = true});

  final _NamedCommand command;
  final bool enabled;

  bool get _isEndTurn => command.command is EndTurnCommand;
  bool get _isMove => command.command is MoveCommand;
  bool get _isOpen =>
      command.command is RevealTileCommand ||
      command.command is OpenCorridorCommand;
  bool get _isClose => command.command is CloseCorridorCommand;

  IconData get _icon {
    if (_isEndTurn) return Icons.hourglass_bottom;
    if (command.command is MoveCommand) return Icons.directions_walk;
    if (command.command is AttackCommand) return Icons.gavel_outlined;
    if (_isOpen) return Icons.visibility_outlined;
    if (_isClose) return Icons.lock_outline;
    if (command.command is SkillCheckCommand) return Icons.visibility_outlined;
    return Icons.settings_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _isEndTurn
        ? 'ЗАВЕРШИТЬ ХОД'
        : _isMove
        ? 'ДВИЖЕНИЕ'
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
                width: 112,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
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
      width: _isEndTurn ? double.infinity : 128,
      height: _isEndTurn ? double.infinity : 112,
      child: _isEndTurn
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C3F28),
                foregroundColor: const Color(0xFFFFE8C2),
                side: const BorderSide(color: Color(0xFFE0A364), width: 1.4),
              ),
              onPressed: () => enabled
                  ? _dispatchNamedCommand(context, ref, command)
                  : ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Завершить ход сейчас недоступно.'),
                      ),
                    ),
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              onPressed: () => enabled
                  ? _dispatchWithFeedback(context, ref, command.command)
                  : ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Это действие сейчас недоступно.'),
                      ),
                    ),
              child: child,
            ),
    );
  }
}
