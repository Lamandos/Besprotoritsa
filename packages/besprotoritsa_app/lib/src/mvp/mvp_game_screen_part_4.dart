// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'mvp_game_screen.dart';

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
      onPressed: () => _dispatchNamedCommand(context, ref, command),
      child: Text(command.label),
    ),
  );
}

class _HeroRosterPanel extends StatelessWidget {
  const _HeroRosterPanel({
    required this.state,
    required this.selectedPlayerId,
    required this.onSelected,
  });

  final GameState state;
  final String selectedPlayerId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: 'Состав экипажа',
    icon: const Icon(Icons.groups_2_outlined),
    child: ListView.separated(
      itemCount: 4,
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index >= state.players.length) {
          return const _EmptyCrewSlot();
        }
        final player = state.players[index];
        final selected = player.id == selectedPlayerId;
        final activeTurn =
            state.phase == GamePhase.playersTurn &&
            player.id == state.activePlayerId;
        final currentHealth = (player.health - player.damage).clamp(
          0,
          player.health,
        );
        final healthRatio = player.health == 0
            ? 0.0
            : currentHealth / player.health;
        return GestureDetector(
          onTap: () => onSelected(player.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF433326), Color(0xFF2B211A)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: activeTurn
                      ? const Color(0xFF9BCB72)
                      : selected
                      ? const Color(0xFFE1AD65)
                      : const Color(0xFF80613F),
                  width: activeTurn || selected ? 2 : 1,
                ),
                boxShadow: [
                  const BoxShadow(color: Colors.black38, blurRadius: 5),
                  if (activeTurn)
                    const BoxShadow(
                      color: Color(0x8874CB55),
                      blurRadius: 14,
                    ),
                  if (selected)
                    const BoxShadow(color: Color(0x66D08A3D), blurRadius: 12),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CharacterPortrait(
                        characterId: player.characterId,
                        size: const Size(62, 64),
                        borderColor: activeTurn
                            ? const Color(0xFFB9E88A)
                            : const Color(0xFFD6B47E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullRuntimeCharacterName(player.characterId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF1E5CA),
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: healthRatio,
                                minHeight: 5,
                                backgroundColor: const Color(0xFF201915),
                                color: healthRatio <= .3
                                    ? const Color(0xFFC75B32)
                                    : const Color(0xFF899168),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'СИЛ ${player.stats.strength}   '
                              'БОЙ ${player.stats.combatStrength}   '
                              'НАУКА ${player.stats.science}   '
                              'РЕМ ${player.stats.repair}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                color: Color(0xFFCDBA96),
                                fontSize: 8,
                                letterSpacing: .2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 14,
                            color: Color(0xFFC76B52),
                          ),
                          Text(
                            '$currentHealth/${player.health}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: Color(0xFFD3AD75),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${player.credits} кр.',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ОД ${player.actionPoints}',
                        style: TextStyle(
                          color: activeTurn
                              ? const Color(0xFFB9E88A)
                              : const Color(0xFFD3AD75),
                          fontSize: 9,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        player.alive ? 'В СТРОЮ' : 'ПОТЕРЯН',
                        style: TextStyle(
                          color: player.alive
                              ? const Color(0xFFAEB58A)
                              : const Color(0xFFD36C4D),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _EmptyCrewSlot extends StatelessWidget {
  const _EmptyCrewSlot();

  @override
  Widget build(BuildContext context) => Container(
    height: 74,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0x55231D17),
      border: Border.all(color: const Color(0x665E4A35)),
      gradient: const LinearGradient(
        colors: [Color(0x331D1915), Color(0x552F251C)],
      ),
    ),
    child: const Row(
      children: [
        Icon(Icons.person_outline, color: Color(0xFF8F795A), size: 32),
        SizedBox(width: 12),
        Text(
          'СВОБОДНОЕ МЕСТО',
          style: TextStyle(
            color: Color(0xFF8F795A),
            fontFamily: 'serif',
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
      ],
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xE6211A15),
      border: Border.all(color: const Color(0xFF8C6943), width: 3),
      boxShadow: const [
        BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(2, 5)),
        BoxShadow(color: Color(0x5544A7C5), blurRadius: 10),
      ],
    ),
    child: Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF493728)),
        gradient: const LinearGradient(
          colors: [Color(0xC6423022), Color(0xD51B1713)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                IconTheme(
                  data: const IconThemeData(color: Color(0xFFD3AD75)),
                  child: icon,
                ),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE7D5B5),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
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
    final allEntries = <String>[
      ...state.log.map((entry) => _displayLogLine(state, entry)),
      ...queue.history.map((event) => _eventLabel(event, strings)),
    ];
    final entries = allEntries.length <= 20
        ? allEntries
        : allEntries.sublist(allEntries.length - 20);
    final activeQuests = _activeQuests(state);
    final currentGoal = activeQuests
        .where(
          (id) => (state.questDefinitions[id]?['chapter'] as int? ?? 0) > 0,
        )
        .firstOrNull;
    final activePlayerId = state.activePlayerId;
    final personalTasks = activePlayerId == null
        ? const <String>[]
        : state.quests.personalTasksByPlayer[activePlayerId] ??
              const <String>[];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(strings.eventLog),
        const SizedBox(height: 4),
        if (entries.isEmpty)
          const Text(
            'Событий пока нет.',
            style: TextStyle(color: Color(0xFFB6A68B)),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(entry, style: const TextStyle(height: 1.4)),
            ),
        const SizedBox(height: 16),
        const Text('Текущая цель кампании'),
        const SizedBox(height: 4),
        if (currentGoal == null)
          const Text('Нет активной сюжетной цели.')
        else
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag, color: Color(0xFFD3AD75)),
              title: Text(_questCardLabel(state, currentGoal)),
              subtitle: Text(
                _questCardDescription(state, currentGoal) ?? currentGoal,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(_questCardLabel(state, currentGoal)),
                  content: SingleChildScrollView(
                    child: Text(
                      _questCardDescription(state, currentGoal) ?? currentGoal,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Личные задачи активного героя'),
            subtitle: const Text('Скрыты от остальных игроков'),
            children: [
              if (personalTasks.isEmpty)
                const ListTile(title: Text('Личных задач нет.'))
              else
                for (final taskId in personalTasks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      state.quests.statusOf(taskId) == QuestStatus.completed
                          ? Icons.check_circle_outline
                          : Icons.person_outline,
                    ),
                    title: Text(_questCardLabel(state, taskId)),
                    subtitle: _questCardDescription(state, taskId) == null
                        ? null
                        : Text(_questCardDescription(state, taskId)!),
                  ),
            ],
          ),
        ),
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
              title: Text(_questCardLabel(state, quest)),
              subtitle: _questProgressSummary(state, quest),
            ),
      ],
    );
  }
}

String _displayLogLine(GameState state, String entry) {
  if (entry.startsWith('event-result-unresolved:')) {
    return 'Событие продолжено: эту ветвь нужно разрешить по правилам боя.';
  }
  final parts = entry.split(':');
  if (parts.length == 4 && parts.first == 'event-result') {
    final optionIndex = int.tryParse(parts[2]);
    final outcome = parts[3];
    final options = state.eventDefinitions[parts[1]]?['options'];
    if (optionIndex != null &&
        options is List<Object?> &&
        optionIndex >= 1 &&
        optionIndex <= options.length) {
      final option = options[optionIndex - 1];
      if (option is Map<String, Object?>) {
        final key = option['${outcome}Key'];
        if (key is String) return state.contentTranslations[key] ?? entry;
      }
    }
  }
  return entry;
}

void _showInventorySheet(
  BuildContext context,
  GameState state, {
  String? selectedPlayerId,
}) {
  final matchingPlayers = state.players
      .where(
        (player) => player.id == (selectedPlayerId ?? state.activePlayerId),
      )
      .toList();
  final selectedPlayer = matchingPlayers.isNotEmpty
      ? matchingPlayers.first
      : state.players.isNotEmpty
      ? state.players.first
      : null;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _GameBottomSheet(
      key: mvpInventorySheetKey,
      title: 'Инвентарь',
      icon: const Icon(Icons.backpack_outlined),
      child: selectedPlayer == null
          ? const Text('Нет выбранного персонажа.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    fullRuntimeCharacterName(selectedPlayer.characterId),
                  ),
                  subtitle: Text('₡${selectedPlayer.credits}'),
                ),
                const Divider(),
                for (final (slot, item) in <(String, String)>[
                  for (final (index, weapon)
                      in selectedPlayer.equipped.weapons.indexed)
                    ('Оружие ${index + 1}', weapon),
                  if (selectedPlayer.equipped.armor case final item?)
                    ('Броня', item),
                  if (selectedPlayer.equipped.clothing case final item?)
                    ('Одежда', item),
                  if (selectedPlayer.equipped.robot case final item?)
                    ('Робот', item),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(item),
                    subtitle: Text(slot),
                  ),
                if (selectedPlayer.backpack.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Рюкзак пуст'),
                  )
                else
                  for (final item in selectedPlayer.backpack)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item),
                    ),
              ],
            ),
    ),
  );
}
