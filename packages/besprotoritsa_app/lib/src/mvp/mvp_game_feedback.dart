part of 'mvp_game_screen.dart';

final _gameFeedbackBlockingProvider =
    NotifierProvider<_GameFeedbackBlockingController, bool>(
      _GameFeedbackBlockingController.new,
    );

class _GameFeedbackBlockingController extends Notifier<bool> {
  @override
  bool build() => false;

  bool get blocked => state;

  set blocked(bool value) => state = value;
}

/// Present completed transitions separately from the next pending choice.
class _GameFeedbackOverlay extends ConsumerStatefulWidget {
  const _GameFeedbackOverlay();

  @override
  ConsumerState<_GameFeedbackOverlay> createState() =>
      _GameFeedbackOverlayState();
}

class _GameFeedbackOverlayState extends ConsumerState<_GameFeedbackOverlay> {
  final List<_GameResult> _results = [];
  final List<_EquipmentOffer> _equipmentOffers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(_gameFeedbackBlockingProvider.notifier).blocked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (before, after) {
      if (before == null) return;
      final results = _transitionResults(before, after);
      final offers = _newEquipmentOffers(before, after);
      if (results.isNotEmpty || offers.isNotEmpty) {
        setState(() {
          _results.addAll(results);
          _equipmentOffers.addAll(offers);
        });
      }
      _syncBlockingState(after);
    });
    final gameState = ref.watch(gameControllerProvider);
    final queue = ref.read(eventQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        if (queue.isPlaying) return const SizedBox.shrink();
        if (_results.isNotEmpty) {
          final result = _results.first;
          return Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: AlertDialog(
                  title: Text(result.title),
                  content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(child: Text(result.body)),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () {
                        setState(() => _results.removeAt(0));
                        _updateBlockingState();
                      },
                      child: const Text('Продолжить'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (_equipmentOffers.isEmpty || gameState.pendingDecision != null) {
          return const SizedBox.shrink();
        }
        return _equipmentOfferDialog(
          context,
          ref,
          _equipmentOffers.first,
          () {
            setState(() => _equipmentOffers.removeAt(0));
            _updateBlockingState();
          },
        );
      },
    );
  }

  void _syncBlockingState(GameState state) {
    ref.read(_gameFeedbackBlockingProvider.notifier).blocked =
        _results.isNotEmpty ||
        (_equipmentOffers.isNotEmpty && state.pendingDecision == null);
  }

  void _updateBlockingState() =>
      _syncBlockingState(ref.read(gameControllerProvider));
}

class _EquipmentOffer {
  const _EquipmentOffer({required this.playerId, required this.cardId});

  final String playerId;
  final String cardId;
}

List<_EquipmentOffer> _newEquipmentOffers(
  GameState before,
  GameState after,
) {
  final playerId = after.activePlayerId;
  if (playerId == null) return const [];
  final player = after.players
      .where((entry) => entry.id == playerId)
      .firstOrNull;
  if (player == null) return const [];
  final previous = before.players
      .where((entry) => entry.id == playerId)
      .firstOrNull;
  // A newly observed player can be part of the first authoritative snapshot
  // after connecting or recreating a multiplayer controller. Their existing
  // inventory establishes the baseline; it is not a newly received reward.
  if (previous == null) return const [];
  final beforeBackpack = _countCards(previous.backpack);
  final afterBackpack = _countCards(player.backpack);
  final beforeOwned = _countCards(_ownedCards(previous));
  final afterOwned = _countCards(_ownedCards(player));
  final offers = <_EquipmentOffer>[];
  for (final cardId in afterBackpack.keys) {
    final definition = after.cardDefinitions[cardId];
    if (definition == null ||
        !const {
          ItemType.weapon,
          ItemType.armor,
          ItemType.clothing,
          ItemType.robot,
        }.contains(definition.type)) {
      continue;
    }
    final newlyBackpacked =
        (afterBackpack[cardId] ?? 0) - (beforeBackpack[cardId] ?? 0);
    final newlyOwned = (afterOwned[cardId] ?? 0) - (beforeOwned[cardId] ?? 0);
    final receivedCount = math.min(newlyBackpacked, newlyOwned);
    for (var index = 0; index < receivedCount; index++) {
      offers.add(_EquipmentOffer(playerId: playerId, cardId: cardId));
    }
  }
  return offers;
}

Iterable<String> _ownedCards(PlayerState? player) => player == null
    ? const []
    : [
        ...player.backpack,
        ...player.equipped.weapons,
        if (player.equipped.armor case final card?) card,
        if (player.equipped.clothing case final card?) card,
        if (player.equipped.robot case final card?) card,
        ...player.carriedMods,
        ...player.implanted,
      ];

Map<String, int> _countCards(Iterable<String> cards) {
  final counts = <String, int>{};
  for (final card in cards) {
    counts.update(card, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

Widget _equipmentOfferDialog(
  BuildContext context,
  WidgetRef ref,
  _EquipmentOffer offer,
  VoidCallback dismiss,
) {
  final state = ref.watch(gameControllerProvider);
  final player = state.players
      .where((entry) => entry.id == offer.playerId)
      .firstOrNull;
  final definition = state.cardDefinitions[offer.cardId];
  if (player == null || definition == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => dismiss());
    return const SizedBox.shrink();
  }
  final slotIndex =
      definition.type == ItemType.weapon &&
          player.equipped.weapons.length <
              InventoryRules.weaponCapacity(player, state.cardDefinitions)
      ? player.equipped.weapons.length
      : 0;
  final replacedCard = switch (definition.type) {
    ItemType.weapon =>
      player.equipped.weapons.length > slotIndex
          ? player.equipped.weapons[slotIndex]
          : null,
    ItemType.armor => player.equipped.armor,
    ItemType.clothing => player.equipped.clothing,
    ItemType.robot => player.equipped.robot,
    _ => null,
  };
  final cardName = _inventoryCardName(state, offer.cardId);
  final replacementName = replacedCard == null
      ? null
      : _inventoryCardName(state, replacedCard);
  return Positioned.fill(
    child: ColoredBox(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('Получена экипировка'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Карта «$cardName» уже добавлена в рюкзак.'),
                  if (replacementName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'При экипировке она заменит «$replacementName». '
                      'Старая карта переместится в рюкзак.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: dismiss,
              child: const Text('Оставить в рюкзаке'),
            ),
            FilledButton(
              onPressed: () {
                final accepted = ref
                    .read(gameControllerProvider.notifier)
                    .dispatch(
                      EquipCommand(offer.cardId, weaponSlot: slotIndex),
                    );
                if (accepted) dismiss();
              },
              child: const Text('Экипировать сейчас'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GameResult {
  const _GameResult(this.title, this.body);
  final String title;
  final String body;
}

List<_GameResult> _transitionResults(GameState before, GameState after) {
  if (after.log.length <= before.log.length) return const [];
  final results = <_GameResult>[];
  final lines = after.log.skip(before.log.length).toList();
  final teamResultLines = lines
      .where((line) => line.startsWith('event-team-result:'))
      .toList();
  if (teamResultLines.isNotEmpty) {
    final eventId = teamResultLines.first.split(':').elementAtOrNull(1);
    final details = <String>[];
    for (final line in teamResultLines) {
      final parts = line.split(':');
      if (parts.length != 5 || parts.first != 'event-team-result') continue;
      final id = parts[1];
      final playerId = parts[2];
      final option = parts[3];
      final outcome = parts[4];
      final player = after.players
          .where((hero) => hero.id == playerId)
          .firstOrNull;
      final displayOptionIndex = option.startsWith('horde|')
          ? 1
          : int.tryParse(option.replaceFirst('option-', ''));
      final optionHasCheck =
          displayOptionIndex != null &&
          _eventOptionSkillCheck(after, id, 'option-$displayOptionIndex') !=
              null;
      final outcomeText = switch (outcome) {
        'success' when optionHasCheck => 'Успех',
        'failure' when optionHasCheck => 'Провал',
        'success' || 'failure' => '',
        'skipped' => 'Не применено: герой выбыл до разрешения выбора.',
        _ => 'Исход варианта не определён.',
      };
      final playerName = player == null
          ? playerId
          : fullRuntimeCharacterName(player.characterId);
      details.add(
        [
          '$playerName: ${_eventOptionLabel(after, id, option)}',
          outcomeText,
          if (displayOptionIndex != null && outcome != 'skipped')
            _eventResultOutcomeText(
              _eventOptionText(
                    after,
                    id,
                    displayOptionIndex,
                    outcome == 'failure' ? 'failureKey' : 'successKey',
                  ) ??
                  '',
            ),
          for (final detail in _teamEventEffectDetails(
            lines,
            playerId,
            option,
          ))
            detail,
        ].where((line) => line.isNotEmpty).join('\n'),
      );
    }
    results.add(
      _GameResult(
        'Результат события',
        [
          if (eventId != null)
            _runtimeEventText(after, eventId, 'nameKey') ?? eventId,
          ...details,
        ].join('\n\n'),
      ),
    );
  }
  for (final line in lines) {
    final parts = line.split(':');
    if (parts.first == 'event-team-result') continue;
    if (parts.first == 'combat-roll' && parts.length == 6) {
      final attack = parts[1] == 'attack';
      final player = after.players
          .where((hero) => hero.id == parts[2])
          .firstOrNull;
      final damage = int.tryParse(parts[5]) ?? 0;
      final attackerName = player == null
          ? null
          : fullRuntimeCharacterName(player.characterId);
      results.add(
        _GameResult(
          attack
              ? 'Результат атаки: ${attackerName ?? 'персонажа'}'
              : 'Результат уклонения',
          [
            if (!attack && attackerName != null) attackerName,
            'Кубики: ${parts[3].split(',').join(', ')}',
            'Успехов: ${parts[4]}',
            if (attack)
              'Нанесено урона: $damage'
            else
              'Получено урона: $damage',
            if (attack &&
                lines.any(
                  (entry) =>
                      entry.startsWith('attack:${parts[2]}:') &&
                      entry.contains(':defeated'),
                ))
              'Монстр уничтожен.',
            ..._stateConsequences(
              before,
              after,
              includeDamage: false,
              includeMonsters: false,
            ),
          ].join('\n'),
        ),
      );
    }
    if (parts.first == 'event-result' && parts.length == 4) {
      final id = parts[1];
      final index = int.tryParse(parts[2]);
      final success = parts[3] == 'success';
      final changes = _stateConsequences(before, after);
      final pending = before.pendingDecision;
      final action = index == null
          ? null
          : _eventOptionText(after, id, index, 'actionKey');
      final outcome = index == null
          ? null
          : _eventOptionText(
              after,
              id,
              index,
              success ? 'successKey' : 'failureKey',
            );
      results.add(
        _GameResult(
          'Результат события',
          [
            _runtimeEventText(after, id, 'nameKey') ?? id,
            if (_eventOptionSkillCheck(after, id, 'option-$index') != null)
              if (success) 'Успех' else 'Провал',
            if (pending is AwaitingRerollChoice)
              'Кубики: ${pending.dice.join(', ')}',
            if (action != null) 'Вариант: $action',
            if (outcome != null) _eventResultOutcomeText(outcome),
            ...changes,
            if (changes.isEmpty) 'Изменений характеристик и инвентаря нет.',
          ].join('\n'),
        ),
      );
    }
  }
  final decision = before.pendingDecision;
  // Sector placement, trading and picking loot may finish on a later command
  // than the success/failure check. Report the changes made by that choice too.
  if (!lines.any((line) => line.startsWith('event-result:')) &&
      teamResultLines.isEmpty &&
      decision is AwaitingEventOption &&
      decision.eventId != null &&
      after.pendingDecision is! AwaitingRerollChoice) {
    final changes = _stateConsequences(before, after);
    if (changes.isNotEmpty || _pendingEventId(after) != decision.eventId) {
      results.add(
        _GameResult(
          'Результат события',
          [
            _runtimeEventText(after, decision.eventId!, 'nameKey') ??
                decision.eventId!,
            if (lines.any(
              (line) => line.startsWith('event-result-unresolved:'),
            ))
              'Исход этого варианта ещё не определён в данных карты.'
            else
              'Выбор выполнен.',
            ...changes,
            if (changes.isEmpty) 'Изменений характеристик и инвентаря нет.',
          ].join('\n'),
        ),
      );
    }
  }
  return results;
}

String _eventResultOutcomeText(String source) => source
    .replaceAll(', остальные замешайте.', '.')
    .replaceAll(', остальные замешайте', '')
    .replaceAll(
      'Возьмите робота из колоды предметов.',
      'Получите робота из колоды предметов.',
    );

List<String> _teamEventEffectDetails(
  List<String> lines,
  String playerId,
  String option,
) {
  final details = <String>[];
  for (final line in lines) {
    final parts = line.split(':');
    if (parts.first == 'event-damage-roll' &&
        parts.length == 3 &&
        parts[1] == playerId) {
      details.add('Получено ${parts[2]} урона.');
    } else if (parts.first == 'event-damage' &&
        parts.length == 3 &&
        parts[1] == playerId) {
      details.add('Получено ${parts[2]} урона.');
    } else if (parts.first == 'event-horde-damage' &&
        parts.length == 3 &&
        parts[1] == playerId) {
      details.add('Получено ${parts[2]} урона.');
    } else if (parts.first == 'event-horde-discard' &&
        parts.length == 3 &&
        parts[1] == playerId) {
      details.add('Сброшено карт: ${parts[2]}.');
    }
  }
  return details;
}

List<String> _stateConsequences(
  GameState before,
  GameState after, {
  bool includeDamage = true,
  bool includeMonsters = true,
}) {
  final changes = <String>[];
  for (final player in after.players) {
    final previous = before.players
        .where((hero) => hero.id == player.id)
        .firstOrNull;
    if (previous == null) continue;
    final name = fullRuntimeCharacterName(player.characterId);
    if (previous.alive && !player.alive) changes.add('$name — Герой погиб.');
    if (previous.characterId != player.characterId) {
      changes.add('На замену пришёл: $name');
    }
    for (final stat in StatType.values) {
      final delta =
          playerStatValue(after, player, stat) -
          playerStatValue(before, previous, stat);
      if (delta != 0) {
        changes.add(
          '$name — ${_statLabel(stat)}: '
          '${delta > 0 ? '+' : '−'}${delta.abs()}',
        );
      }
    }
    final damage = player.damage - previous.damage;
    if (includeDamage && damage != 0) {
      final change = damage > 0
          ? 'Получено урона: $damage'
          : 'Вылечено урона: ${-damage}';
      changes.add(
        '$name — $change',
      );
    }
    final credits = player.credits - previous.credits;
    if (credits != 0) {
      changes.add(
        '$name — Кредиты: ${credits > 0 ? '+' : '−'}${credits.abs()}',
      );
    }
    final actions = player.nextTurnActionDelta - previous.nextTurnActionDelta;
    if (actions != 0) {
      changes.add(
        '$name — Следующий ход: ${actions > 0 ? '+' : '−'}${actions.abs()} ОД',
      );
    }
    if (player.coord != previous.coord) {
      changes.add('$name — Перемещение в другой сектор.');
    }
    final oldCards = _feedbackCardCounts(previous);
    final newCards = _feedbackCardCounts(player);
    for (final id in {...oldCards.keys, ...newCards.keys}) {
      final count = (newCards[id] ?? 0) - (oldCards[id] ?? 0);
      if (count != 0) {
        final action = count > 0 ? 'Получено' : 'Потеряно';
        changes.add(
          '$name — $action: '
          '${_inventoryCardName(after, id)} ×${count.abs()}',
        );
      }
    }
    final oldConditions = <String, int>{};
    final newConditions = <String, int>{};
    for (final id in previous.conditions) {
      oldConditions.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final id in player.conditions) {
      newConditions.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final id in {...oldConditions.keys, ...newConditions.keys}) {
      final count = (newConditions[id] ?? 0) - (oldConditions[id] ?? 0);
      if (count != 0) {
        final action = count > 0 ? 'Получено состояние' : 'Снято состояние';
        final label =
            after.contentTranslations['content.condition.$id.name'] ?? id;
        changes.add(
          '$name — $action: $label ×${count.abs()}',
        );
      }
    }
    if (player.monsterDamageImmuneThroughRound !=
            previous.monsterDamageImmuneThroughRound &&
        player.monsterDamageImmuneThroughRound != null) {
      changes.add(
        '$name — Иммунитет к урону монстров до раунда '
        '${player.monsterDamageImmuneThroughRound}.',
      );
    }
    if (player.monsterDefenseBonusRound == after.round &&
        (player.monsterDefenseBonusRound != previous.monsterDefenseBonusRound ||
            player.monsterDefenseBonus != previous.monsterDefenseBonus)) {
      changes.add(
        '$name — Защита +${player.monsterDefenseBonus} до конца раунда.',
      );
    }
    if (player.damageImmuneThroughRound != previous.damageImmuneThroughRound &&
        player.damageImmuneThroughRound != null) {
      changes.add(
        '$name — Иммунитет ко всему урону до раунда '
        '${player.damageImmuneThroughRound}.',
      );
    }
    final newlyExhausted = player.exhaustedRobots
        .where((id) => !previous.exhaustedRobots.contains(id))
        .toList();
    final readied = previous.exhaustedRobots
        .where((id) => !player.exhaustedRobots.contains(id))
        .toList();
    if (newlyExhausted.isNotEmpty) {
      final labels = newlyExhausted
          .map((id) => _inventoryCardName(after, id))
          .join(', ');
      changes.add(
        '$name — Робот повёрнут: $labels',
      );
    }
    if (readied.isNotEmpty) {
      final labels = readied
          .map((id) => _inventoryCardName(after, id))
          .join(', ');
      changes.add('$name — Робот готов: $labels');
    }
  }
  if (includeMonsters) {
    for (final monster in after.monsters) {
      final previous = before.monsters
          .where((entry) => entry.instanceId == monster.instanceId)
          .firstOrNull;
      final key = after.monsterDefinitions[monster.monsterId]?['nameKey'];
      final name = key is String
          ? after.contentTranslations[key] ?? monster.monsterId
          : monster.monsterId;
      final isPublic = after.tileAt(monster.coord)?.opened ?? false;
      if (previous == null) {
        changes.add(
          isPublic
              ? 'Появился монстр: $name'
              : 'В закрытом секторе появилась неизвестная угроза.',
        );
      } else if (monster.damage > previous.damage) {
        changes.add(
          isPublic
              ? '$name — Нанесено урона: ${monster.damage - previous.damage}'
              : 'Неизвестная угроза получила урон: '
                    '${monster.damage - previous.damage}',
        );
      }
    }
    for (final monster in before.monsters) {
      if (!after.monsters.any(
        (entry) => entry.instanceId == monster.instanceId,
      )) {
        changes.add('Монстр уничтожен: ${monster.monsterId}');
      }
    }
  }
  var opened = 0;
  var closed = 0;
  var sealed = 0;
  for (final tile in after.board) {
    final previous = before.tileAt(tile.coord);
    if (previous == null) continue;
    if ((!previous.opened || previous.isBlocked) &&
        tile.opened &&
        !tile.isBlocked) {
      opened++;
    }
    if (!previous.isBlocked && tile.isBlocked) closed++;
    if (!previous.monsterAccessBlocked && tile.monsterAccessBlocked) sealed++;
  }
  if (opened > 0) changes.add('Открыто фрагментов поля: $opened');
  if (closed > 0) changes.add('Закрыто коридоров: $closed');
  if (sealed > 0) changes.add('Закрыт доступ монстрам в сектора: $sealed');
  return changes;
}

Map<String, int> _feedbackCardCounts(PlayerState player) {
  final counts = <String, int>{};
  for (final id in [
    ...player.backpack,
    ...InventoryRules.activeCardIds(player),
    ...player.carriedMods,
  ]) {
    counts.update(id, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
}
