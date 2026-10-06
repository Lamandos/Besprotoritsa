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
    child: Column(
      children: [
        Expanded(
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
                          const BoxShadow(
                            color: Color(0x66D08A3D),
                            blurRadius: 12,
                          ),
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
                                    fullRuntimeCharacterName(
                                      player.characterId,
                                    ),
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
                                    'СИЛ ${player.stats.strength}  '
                                    'НАУ ${player.stats.science}  '
                                    'РЕМ ${player.stats.repair}  '
                                    'ВЫН ${player.stats.endurance}  '
                                    'ЛОВ ${player.stats.agility}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: _ChestAccessButton(state: state),
        ),
      ],
    ),
  );
}

class _ChestAccessButton extends ConsumerWidget {
  const _ChestAccessButton({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: double.infinity,
    height: 44,
    child: OutlinedButton.icon(
      key: const ValueKey<String>('shared-chest-button'),
      onPressed: () => _showChestTransferDialog(
        context,
        ref,
        ref.read(gameControllerProvider),
      ),
      icon: const Icon(Icons.inventory_2_outlined),
      label: Text('ОБЩИЙ СУНДУК · ${state.chestCards.length} КАРТ'),
    ),
  );
}

class _CompactChestButton extends ConsumerWidget {
  const _CompactChestButton({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey<String>('shared-chest-compact-button'),
    tooltip: 'Общий сундук · ${state.chestCards.length} карт',
    onPressed: () => _showChestTransferDialog(
      context,
      ref,
      ref.read(gameControllerProvider),
    ),
    icon: const Icon(Icons.inventory_2_outlined),
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
          GameCardSurface(
            material: GameCardMaterial.story,
            borderWidth: 1,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GameCardArtwork(
                cardId: currentGoal,
                kind: GameCardArtworkKind.quest,
                width: 38,
                height: 52,
              ),
              title: Text(
                _questCardLabel(state, currentGoal),
                style: const TextStyle(
                  color: Color(0xFF33271B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                _questCardDescription(state, currentGoal) ?? currentGoal,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF493A2A)),
              ),
              onTap: () => showGameCardScan(
                context,
                cardId: currentGoal,
                title: _questCardLabel(state, currentGoal),
                kind: GameCardArtworkKind.quest,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GameCardSurface(
                      material: GameCardMaterial.story,
                      borderWidth: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GameCardArtwork(
                          cardId: taskId,
                          kind: GameCardArtworkKind.task,
                          width: 38,
                          height: 52,
                        ),
                        trailing: Icon(
                          state.quests.statusOf(taskId) == QuestStatus.completed
                              ? Icons.check_circle_outline
                              : Icons.person_outline,
                          color: const Color(0xFF694B2F),
                        ),
                        title: Text(
                          _questCardLabel(state, taskId),
                          style: const TextStyle(
                            color: Color(0xFF33271B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: _questCardDescription(state, taskId) == null
                            ? null
                            : Text(
                                _questCardDescription(state, taskId)!,
                                style: const TextStyle(
                                  color: Color(0xFF493A2A),
                                ),
                              ),
                        onTap: () => showGameCardScan(
                          context,
                          cardId: taskId,
                          title: _questCardLabel(state, taskId),
                          kind: GameCardArtworkKind.task,
                        ),
                      ),
                    ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GameCardSurface(
                material: GameCardMaterial.story,
                borderWidth: 1,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: GameCardArtwork(
                    cardId: quest,
                    kind: GameCardArtworkKind.quest,
                    width: 38,
                    height: 52,
                  ),
                  title: Text(
                    _questCardLabel(state, quest),
                    style: const TextStyle(
                      color: Color(0xFF33271B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: _questProgressSummary(state, quest),
                  onTap: () => showGameCardScan(
                    context,
                    cardId: quest,
                    title: _questCardLabel(state, quest),
                    kind: GameCardArtworkKind.quest,
                  ),
                ),
              ),
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
  BuildContext context, {
  String? selectedPlayerId,
}) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _InventoryPanel(selectedPlayerId: selectedPlayerId),
    ),
  );
}

class _InventoryPanel extends ConsumerWidget {
  const _InventoryPanel({required this.selectedPlayerId});

  final String? selectedPlayerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final activePlayer = state.players
        .where((player) => player.id == state.activePlayerId)
        .firstOrNull;
    final selectedPlayer =
        state.players
            .where((player) => player.id == selectedPlayerId)
            .firstOrNull ??
        activePlayer ??
        state.players.firstOrNull;
    final isActivePlayer = selectedPlayer?.id == state.activePlayerId;
    return _GameBottomSheet(
      key: mvpInventorySheetKey,
      title: 'Инвентарь',
      icon: const Icon(Icons.backpack_outlined),
      child: selectedPlayer == null
          ? const Text('Нет выбранного персонажа.')
          : ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CharacterPortrait(
                        characterId: selectedPlayer.characterId,
                        size: const Size(64, 72),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullRuntimeCharacterName(
                                selectedPlayer.characterId,
                              ),
                              style: const TextStyle(
                                color: Color(0xFFFFF1D5),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Кредиты: ₡${selectedPlayer.credits}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isActivePlayer)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Действия доступны только для активного персонажа.',
                      style: TextStyle(color: Color(0xFFD3AD75)),
                    ),
                  ),
                const Divider(),
                const Text(
                  'ЭКИПИРОВАНО',
                  style: TextStyle(
                    color: Color(0xFFD3AD75),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                for (final (index, item)
                    in selectedPlayer.equipped.weapons.indexed)
                  _itemCardRow(
                    context: context,
                    title: _inventoryCardName(state, item),
                    cardId: item,
                    subtitle: 'Оружие ${index + 1}',
                    icon: Icons.shield_outlined,
                    actions: isActivePlayer
                        ? [
                            _InventoryAction(
                              'Снять',
                              UnequipCommand(
                                ItemSlot.weapon,
                                weaponSlot: index,
                              ),
                            ),
                            _InventoryAction(
                              'Сбросить',
                              DiscardCardCommand(item),
                            ),
                          ]
                        : const [],
                  ),
                if (selectedPlayer.equipped.armor case final item?)
                  _equippedInventoryRow(
                    context,
                    state,
                    isActivePlayer,
                    item,
                    'Броня',
                    ItemSlot.armor,
                  ),
                if (selectedPlayer.equipped.clothing case final item?)
                  _equippedInventoryRow(
                    context,
                    state,
                    isActivePlayer,
                    item,
                    'Одежда',
                    ItemSlot.clothing,
                  ),
                if (selectedPlayer.equipped.robot case final item?)
                  _equippedInventoryRow(
                    context,
                    state,
                    isActivePlayer,
                    item,
                    'Робот',
                    ItemSlot.robot,
                  ),
                for (final (index, item) in selectedPlayer.carriedMods.indexed)
                  _itemCardRow(
                    context: context,
                    title: _inventoryCardName(state, item),
                    cardId: item,
                    subtitle: 'Модификация ${index + 1}',
                    icon: Icons.memory_outlined,
                    actions: isActivePlayer
                        ? [
                            _InventoryAction(
                              'Вживить',
                              ImplantModificationCommand(item),
                            ),
                          ]
                        : const [],
                  ),
                for (final (index, item) in selectedPlayer.implanted.indexed)
                  _itemCardRow(
                    context: context,
                    title: _inventoryCardName(state, item),
                    cardId: item,
                    subtitle: 'Вживлённая модификация ${index + 1}',
                    icon: Icons.memory_outlined,
                  ),
                const SizedBox(height: 8),
                const Text(
                  'РЮКЗАК',
                  style: TextStyle(
                    color: Color(0xFFD3AD75),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                if (selectedPlayer.backpack.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Рюкзак пуст'),
                  )
                else
                  for (final item in selectedPlayer.backpack)
                    _itemCardRow(
                      context: context,
                      title: _inventoryCardName(state, item),
                      cardId: item,
                      icon: Icons.inventory_2_outlined,
                      actions: isActivePlayer
                          ? [
                              if (state
                                      .cardDefinitions[item]
                                      ?.slots
                                      .isNotEmpty ??
                                  false)
                                _InventoryAction(
                                  'Экипировать',
                                  EquipCommand(item),
                                ),
                              _InventoryAction(
                                'Сбросить',
                                DiscardCardCommand(item),
                              ),
                            ]
                          : const [],
                    ),
                const SizedBox(height: 8),
                const Text(
                  'ОБМЕН',
                  style: TextStyle(
                    color: Color(0xFFD3AD75),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                if (!isActivePlayer)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Обмен доступен только активному персонажу.'),
                  )
                else if (_colocatedPartners(state, selectedPlayer).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Рядом нет персонажей для обмена.'),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final partner in _colocatedPartners(
                        state,
                        selectedPlayer,
                      ))
                        InkWell(
                          key: ValueKey<String>(
                            'exchange-partner-${partner.id}',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showExchangeDialog(
                            context,
                            ref,
                            state,
                            selectedPlayer,
                            partner,
                          ),
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34291F),
                              border: Border.all(
                                color: const Color(0xFF8B6B45),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                CharacterPortrait(
                                  characterId: partner.characterId,
                                  size: const Size(56, 64),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fullRuntimeCharacterName(
                                    partner.characterId,
                                  ),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFF1D5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                for (final eventCard in selectedPlayer.retainedEventCards)
                  _itemCardRow(
                    context: context,
                    title: _inventoryCardName(state, eventCard),
                    cardId: eventCard,
                    icon: Icons.auto_stories_outlined,
                    material: GameCardMaterial.event,
                    artworkKind: GameCardArtworkKind.event,
                  ),
              ],
            ),
    );
  }
}

List<PlayerState> _colocatedPartners(GameState state, PlayerState player) => [
  for (final partner in state.players)
    if (partner.alive &&
        partner.id != player.id &&
        partner.coord == player.coord)
      partner,
];

class _TransferableCard {
  const _TransferableCard(this.cardId, this.location, [this.selection]);

  final String cardId;
  final String location;
  final InventoryCardSelection? selection;
}

List<_TransferableCard> _transferableInventoryCards(PlayerState player) => [
  for (final cardId in player.backpack)
    _TransferableCard(
      cardId,
      'Рюкзак',
      InventoryCardSelection(cardId: cardId, area: InventoryCardArea.backpack),
    ),
  for (final (index, cardId) in player.equipped.weapons.indexed)
    _TransferableCard(
      cardId,
      'Оружие ${index + 1}',
      InventoryCardSelection(cardId: cardId, area: InventoryCardArea.weapon),
    ),
  if (player.equipped.armor case final cardId?)
    _TransferableCard(
      cardId,
      'Броня',
      InventoryCardSelection(cardId: cardId, area: InventoryCardArea.armor),
    ),
  if (player.equipped.clothing case final cardId?)
    _TransferableCard(
      cardId,
      'Одежда',
      InventoryCardSelection(cardId: cardId, area: InventoryCardArea.clothing),
    ),
  if (player.equipped.robot case final cardId?)
    _TransferableCard(
      cardId,
      'Робот',
      InventoryCardSelection(cardId: cardId, area: InventoryCardArea.robot),
    ),
  for (final (index, cardId) in player.carriedMods.indexed)
    _TransferableCard(
      cardId,
      'Модификация ${index + 1}',
      InventoryCardSelection(
        cardId: cardId,
        area: InventoryCardArea.carriedMod,
      ),
    ),
];

Widget _transferableCardList(
  GameState state,
  List<_TransferableCard> cards,
  Set<int> selected,
  ValueChanged<int> onToggle,
) => ListView.builder(
  itemCount: cards.length,
  itemBuilder: (context, index) {
    final card = cards[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GameCardSurface(
        material: GameCardMaterial.item,
        overlayColor: const Color(0xB8201A14),
        child: CheckboxListTile(
          dense: true,
          value: selected.contains(index),
          onChanged: (_) => onToggle(index),
          secondary: GameCardArtwork(
            cardId: card.cardId,
            width: 36,
            height: 50,
          ),
          title: Text(
            _inventoryCardName(state, card.cardId),
            style: const TextStyle(
              color: Color(0xFFFFF1D5),
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            card.location,
            style: const TextStyle(color: Color(0xFFE3C99A)),
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: const Color(0xFFE5AC5F),
          checkColor: const Color(0xFF201711),
        ),
      ),
    );
  },
);

Widget _transferWindow({
  required GameState state,
  required PlayerState player,
  required List<_TransferableCard> cards,
  required Set<int> selected,
  required ValueChanged<int> onToggle,
  required TextEditingController creditsController,
  required ValueChanged<String> onCreditsChanged,
}) => Container(
  decoration: BoxDecoration(
    color: const Color(0xFF211A15),
    border: Border.all(color: const Color(0xFF8B6B45)),
    borderRadius: BorderRadius.circular(8),
  ),
  padding: const EdgeInsets.all(10),
  child: Column(
    children: [
      Row(
        children: [
          CharacterPortrait(
            characterId: player.characterId,
            size: const Size(54, 62),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fullRuntimeCharacterName(player.characterId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFF1D5),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: creditsController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.isEmpty) return newValue;
            final amount = int.tryParse(newValue.text);
            return amount != null && amount <= player.credits
                ? newValue
                : oldValue;
          }),
        ],
        onChanged: onCreditsChanged,
        decoration: InputDecoration(
          labelText: 'Кредиты (до ${player.credits} ₡)',
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF34291F),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: cards.isEmpty
            ? const Center(child: Text('Нет карт для передачи.'))
            : _transferableCardList(state, cards, selected, onToggle),
      ),
    ],
  ),
);

void _showExchangeDialog(
  BuildContext context,
  WidgetRef ref,
  GameState state,
  PlayerState activePlayer,
  PlayerState partner,
) {
  final activeCards = _transferableInventoryCards(activePlayer);
  final partnerCards = _transferableInventoryCards(partner);
  final fromSelected = <int>{};
  final toSelected = <int>{};
  final fromCredits = TextEditingController(text: '0');
  final toCredits = TextEditingController(text: '0');
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final wide = screen.width >= 820;
      return StatefulBuilder(
        builder: (context, setState) {
          final giveCredits = int.tryParse(fromCredits.text) ?? 0;
          final receiveCredits = int.tryParse(toCredits.text) ?? 0;
          final command = ExchangeCommand(
            partnerId: partner.id,
            giveCards: [
              for (final index in fromSelected) activeCards[index].selection!,
            ],
            receiveCards: [
              for (final index in toSelected) partnerCards[index].selection!,
            ],
            giveCredits: giveCredits,
            receiveCredits: receiveCredits,
          );
          final controller = ref.read(gameControllerProvider.notifier);
          final canExchange =
              !controller.validatesCommandsLocally ||
              validate(state, command) == null;
          final fromWindow = _transferWindow(
            state: state,
            player: activePlayer,
            cards: activeCards,
            selected: fromSelected,
            onToggle: (index) => setState(() {
              if (!fromSelected.add(index)) fromSelected.remove(index);
            }),
            creditsController: fromCredits,
            onCreditsChanged: (_) => setState(() {}),
          );
          final toWindow = _transferWindow(
            state: state,
            player: partner,
            cards: partnerCards,
            selected: toSelected,
            onToggle: (index) => setState(() {
              if (!toSelected.add(index)) toSelected.remove(index);
            }),
            creditsController: toCredits,
            onCreditsChanged: (_) => setState(() {}),
          );
          final confirm = Tooltip(
            message: canExchange
                ? 'Подтвердить обмен'
                : 'Выберите карты или кредиты для обмена',
            child: FilledButton.tonal(
              key: const ValueKey<String>('confirm-inventory-exchange'),
              onPressed: !canExchange
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _dispatchWithFeedback(context, ref, command);
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 64),
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.swap_horiz, size: 32),
            ),
          );
          return Dialog(
            child: SizedBox(
              width: (screen.width - 48).clamp(320, 1120).toDouble(),
              height: (screen.height * .86).clamp(420, 820).toDouble(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      'ОБМЕН · ВЫБЕРИТЕ КАРТЫ И КРЕДИТЫ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: fromWindow),
                                SizedBox(
                                  width: 82,
                                  child: Center(child: confirm),
                                ),
                                Expanded(child: toWindow),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: fromWindow),
                                SizedBox(
                                  height: 54,
                                  child: Center(child: confirm),
                                ),
                                Expanded(child: toWindow),
                              ],
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    fromCredits.dispose();
    toCredits.dispose();
  });
}

void _showChestTransferDialog(
  BuildContext context,
  WidgetRef ref,
  GameState state,
) {
  final activePlayer = state.players
      .where((player) => player.id == state.activePlayerId)
      .firstOrNull;
  final playerCards = activePlayer == null
      ? <_TransferableCard>[]
      : _transferableInventoryCards(activePlayer);
  final chestCards = [
    for (final cardId in state.chestCards)
      _TransferableCard(cardId, 'Общий сундук'),
  ];
  final playerSelected = <int>{};
  final chestSelected = <int>{};
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final wide = screen.width >= 820;
      return StatefulBuilder(
        builder: (context, setState) {
          final command = TransferChestCardsCommand(
            depositCards: [
              for (final index in playerSelected) playerCards[index].selection!,
            ],
            withdrawCardIds: [
              for (final index in chestSelected) chestCards[index].cardId,
            ],
          );
          final controller = ref.read(gameControllerProvider.notifier);
          final canTransfer =
              !controller.validatesCommandsLocally ||
              validate(state, command) == null;
          final playerWindow = _inventoryTransferWindow(
            state: state,
            title: activePlayer == null
                ? 'ИНВЕНТАРЬ НЕДОСТУПЕН'
                : 'ИНВЕНТАРЬ · '
                      '${fullRuntimeCharacterName(activePlayer.characterId)}',
            cards: playerCards,
            selected: playerSelected,
            onToggle: (index) => setState(() {
              if (!playerSelected.add(index)) playerSelected.remove(index);
            }),
          );
          final chestWindow = _inventoryTransferWindow(
            state: state,
            title: 'ОБЩИЙ СУНДУК · ${state.chestCards.length} КАРТ',
            cards: chestCards,
            selected: chestSelected,
            onToggle: (index) => setState(() {
              if (!chestSelected.add(index)) chestSelected.remove(index);
            }),
          );
          final confirm = FilledButton.tonalIcon(
            key: const ValueKey<String>('confirm-chest-transfer'),
            onPressed: !canTransfer
                ? null
                : () {
                    Navigator.of(dialogContext).pop();
                    _dispatchWithFeedback(context, ref, command);
                  },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Переложить'),
          );
          final canAccessForTransfer =
              activePlayer != null &&
              state.tileAt(activePlayer.coord)?.type == HexTileType.start &&
              state.actionsLeft > 0;
          return Dialog(
            child: SizedBox(
              width: (screen.width - 48).clamp(320, 1120).toDouble(),
              height: (screen.height * .86).clamp(420, 820).toDouble(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      'ОБЩИЙ СУНДУК',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canAccessForTransfer
                          ? 'Выберите карты для обмена с сундуком за 1 ОД.'
                          : 'Просмотр доступен всегда. Перенос возможен '
                                'у стартового отсека за 1 ОД.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: playerWindow),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(Icons.swap_horiz, size: 32),
                                ),
                                Expanded(child: chestWindow),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: playerWindow),
                                const SizedBox(
                                  height: 40,
                                  child: Icon(Icons.swap_vert, size: 28),
                                ),
                                Expanded(child: chestWindow),
                              ],
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Закрыть'),
                        ),
                        const SizedBox(width: 8),
                        confirm,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _inventoryTransferWindow({
  required GameState state,
  required String title,
  required List<_TransferableCard> cards,
  required Set<int> selected,
  required ValueChanged<int> onToggle,
}) => Container(
  decoration: BoxDecoration(
    color: const Color(0xFF211A15),
    border: Border.all(color: const Color(0xFF8B6B45)),
    borderRadius: BorderRadius.circular(8),
  ),
  padding: const EdgeInsets.all(8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFE7D5B5),
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: cards.isEmpty
            ? const Center(child: Text('Карты отсутствуют.'))
            : _transferableCardList(state, cards, selected, onToggle),
      ),
    ],
  ),
);

Widget _equippedInventoryRow(
  BuildContext context,
  GameState state,
  bool isActivePlayer,
  String item,
  String slot,
  ItemSlot itemSlot,
) => _itemCardRow(
  context: context,
  title: _inventoryCardName(state, item),
  cardId: item,
  subtitle: slot,
  icon: Icons.shield_outlined,
  actions: isActivePlayer
      ? [
          _InventoryAction('Снять', UnequipCommand(itemSlot)),
          _InventoryAction('Сбросить', DiscardCardCommand(item)),
        ]
      : const [],
);

class _InventoryAction {
  const _InventoryAction(this.label, this.command);

  final String label;
  final GameCommand command;
}

class _InventoryActionButton extends ConsumerWidget {
  const _InventoryActionButton({required this.action});

  final _InventoryAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final enabled = validate(state, action.command) == null;
    return FilledButton.tonalIcon(
      onPressed: !enabled
          ? null
          : () => _dispatchWithFeedback(context, ref, action.command),
      icon: const Icon(Icons.play_arrow, size: 16),
      label: Text(action.label),
    );
  }
}

Widget _itemCardRow({
  required BuildContext context,
  required String title,
  required String cardId,
  required IconData icon,
  String? subtitle,
  GameCardMaterial material = GameCardMaterial.item,
  GameCardArtworkKind? artworkKind,
  List<_InventoryAction> actions = const [],
}) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: GameCardSurface(
    material: material,
    borderColor: const Color(0xFF7F7769),
    borderWidth: 1,
    overlayColor: const Color(0xB8201A14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: gameCardArtworkAsset(cardId, kind: artworkKind) == null
                ? Icon(icon, color: const Color(0xFFEAD9B6), size: 30)
                : GameCardArtwork(
                    cardId: cardId,
                    kind: artworkKind,
                    width: 42,
                    height: 58,
                  ),
            title: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFF1D5),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFE3C99A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            onTap: () {
              final kind = artworkKind ?? gameCardArtworkKindForId(cardId);
              if (kind != null) {
                showGameCardScan(
                  context,
                  cardId: cardId,
                  title: title,
                  kind: kind,
                );
              }
            },
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final action in actions)
                    _InventoryActionButton(action: action),
                ],
              ),
            ),
        ],
      ),
    ),
  ),
);

String _inventoryCardName(GameState state, String cardId) =>
    state.contentTranslations['content.item.$cardId.name'] ??
    state.contentTranslations['content.special_item.$cardId.name'] ??
    state.contentTranslations['content.supply.$cardId.name'] ??
    cardId;
