part of 'mvp_game_screen.dart';

/// Present completed transitions separately from the next pending choice.
class _GameFeedbackOverlay extends ConsumerStatefulWidget {
  const _GameFeedbackOverlay();

  @override
  ConsumerState<_GameFeedbackOverlay> createState() =>
      _GameFeedbackOverlayState();
}

class _GameFeedbackOverlayState extends ConsumerState<_GameFeedbackOverlay> {
  final List<_GameResult> _results = [];

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, (before, after) {
      if (before == null) return;
      final results = _transitionResults(before, after);
      if (results.isNotEmpty) setState(() => _results.addAll(results));
    });
    final queue = ref.read(eventQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        if (_results.isEmpty || queue.isPlaying) return const SizedBox.shrink();
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
                    onPressed: () => setState(() => _results.removeAt(0)),
                    child: const Text('Продолжить'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
  for (final line in lines) {
    final parts = line.split(':');
    if (parts.first == 'combat-roll' && parts.length == 6) {
      final attack = parts[1] == 'attack';
      final player = after.players
          .where((hero) => hero.id == parts[2])
          .firstOrNull;
      final damage = int.tryParse(parts[5]) ?? 0;
      results.add(
        _GameResult(
          attack ? 'Результат атаки' : 'Результат уклонения',
          [
            if (player != null) fullRuntimeCharacterName(player.characterId),
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
      final options = after.eventDefinitions[id]?['options'];
      final success = parts[3] == 'success';
      String? copy;
      if (index != null &&
          options is List &&
          index > 0 &&
          index <= options.length) {
        final option = options[index - 1];
        if (option is Map) {
          final key = option[success ? 'successKey' : 'failureKey'];
          if (key is String) copy = after.contentTranslations[key];
        }
      }
      final changes = _stateConsequences(before, after);
      final pending = before.pendingDecision;
      results.add(
        _GameResult(
          'Результат события',
          [
            _runtimeEventText(after, id, 'nameKey') ?? id,
            if (success) 'Успех' else 'Провал',
            if (pending is AwaitingRerollChoice)
              'Кубики: ${pending.dice.join(', ')}',
            if (copy != null) copy,
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
    if (player.monsterDefenseBonusRound != previous.monsterDefenseBonusRound &&
        player.monsterDefenseBonusRound == after.round) {
      changes.add('$name — Защита +1 до конца раунда.');
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
      if (previous == null) {
        changes.add('Появился монстр: $name');
      } else if (monster.damage > previous.damage) {
        changes.add(
          '$name — Нанесено урона: ${monster.damage - previous.damage}',
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
