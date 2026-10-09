import 'dart:convert';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/menu/character_portrait.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUG025 character portraits follow the printed character cards', () {
    expect(
      characterPortraitAssets['worker'],
      'assets/images/character-portraits/mechanic.png',
    );
    expect(
      characterPortraitAssets['mechanic'],
      'assets/images/character-portraits/worker.png',
    );
    expect(
      characterPortraitAssets['astronaut'],
      'assets/images/character-portraits/engineer.png',
    );
    expect(
      characterPortraitAssets['engineer'],
      'assets/images/character-portraits/astronaut.png',
    );
  });

  testWidgets('BUG026 tokens stay inside tiles and clear tile labels', (
    tester,
  ) async {
    final state = _scenarioWithCharacters(
      const ['scientist', 'guard', 'mechanic', 'worker'],
      (doc) {
        final startCoord = _player(doc)['coord']! as Map<String, dynamic>;
        for (final tile
            in (doc['board']! as List).cast<Map<String, dynamic>>()) {
          final coord = tile['coord']! as Map<String, dynamic>;
          if (coord['q'] == startCoord['q'] && coord['r'] == startCoord['r']) {
            tile['opened'] = true;
          }
        }
        for (final player
            in (doc['players']! as List).cast<Map<String, dynamic>>()) {
          player['coord'] = Map<String, dynamic>.of(startCoord);
        }
        doc['monsters'] = [
          _monsterJson(
            _monster(
              'token-layout-monster',
              HexCoord(startCoord['q']! as int, startCoord['r']! as int),
            ),
          ),
        ];
      },
    );
    await _mount(tester, state);
    final coord = state.players.first.coord;
    final tileFinder = find.byKey(
      ValueKey<String>('hex-${coord.q}-${coord.r}'),
    );
    final tile = tester.getRect(
      tileFinder,
    );
    final heroRects = [
      for (final player in state.players)
        tester.getRect(
          find.byKey(
            ValueKey<String>(
              'hero-${player.id}-at-${coord.q}-${coord.r}',
            ),
          ),
        ),
    ];
    final monster = tester.getRect(
      find.byTooltip('Карточка монстра: test-ghoul'),
    );
    final locationId = state.tileAt(coord)?.locationId;
    final title = locationId == null
        ? 'АНАБИОЗ'
        : state.contentTranslations['content.location.$locationId']!;
    final titleRect = tester.getRect(
      find.descendant(of: tileFinder, matching: find.text(title)),
    );
    for (final hero in heroRects) {
      expect(tile.contains(hero.topLeft), isTrue);
      expect(tile.contains(hero.bottomRight), isTrue);
      expect(hero.overlaps(titleRect), isFalse);
    }
    expect(tile.contains(monster.topLeft), isTrue);
    expect(tile.contains(monster.bottomRight), isTrue);
  });

  testWidgets('BUG027 confirms a discard pile destination before discarding', (
    tester,
  ) async {
    final state = _scenario((doc) {
      (_player(doc)['backpack']! as List).add('medic-bag');
    });
    final container = await _mount(
      tester,
      state,
      viewport: const Size(1280, 1600),
    );
    await tester.tap(find.byKey(mvpInventoryButtonKey));
    await tester.pump(const Duration(milliseconds: 400));
    final discardButton = find.ancestor(
      of: find.text('Сбросить').first,
      matching: find.byType(FilledButton),
    );
    tester.widget<FilledButton>(discardButton).onPressed!.call();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('колоду сброса'), findsOneWidget);
    expect(
      container.read(gameControllerProvider).players.first.backpack,
      contains('medic-bag'),
    );
  });

  testWidgets('BUG028 event choice shows its check and the hero skill pool', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['phase'] = 'eventsPhase';
      doc['pending_decision'] = {
        'type': 'event_option',
        'options': ['option-1'],
        'player_id': _player(doc)['id'],
        'event_id': 'rubble',
      };
    });
    await _mount(tester, state);
    expect(find.textContaining('Проверка силы'), findsOneWidget);
    expect(find.textContaining('Ваша сила — 2'), findsOneWidget);
  });

  testWidgets('BUG029 no-reroll check does not offer to keep a result', (
    tester,
  ) async {
    final container = await _mount(
      tester,
      _scenario(),
      dice: FixedDiceRoller([1, 1, 1, 1]),
    );
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(const SkillCheckCommand(StatType.science)),
      isTrue,
    );
    await tester.pump();
    expect(find.text('Оставить результат'), findsNothing);
    expect(find.text('Продолжить'), findsOneWidget);
  });

  testWidgets('BUG050 defibrillator lets the player select dice for a reroll', (
    tester,
  ) async {
    final state = _scenario((doc) {
      (_player(doc)['backpack']! as List).add('defibrillator');
    });
    final container = await _mount(
      tester,
      state,
      dice: FixedDiceRoller([6, 1, 1, 1, 2, 2, 2, 2]),
    );
    final controller = container.read(gameControllerProvider.notifier);
    expect(
      controller.dispatch(const SkillCheckCommand(StatType.science)),
      isTrue,
    );
    await tester.pump();
    final initial =
        container.read(gameControllerProvider).pendingDecision!
            as AwaitingRerollChoice;
    expect(initial.dice, hasLength(greaterThan(1)));
    expect(initial.rerollSources, contains('defibrillator'));

    await tester.tap(find.text('Выбрать кубики'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Выберите кубики для переброса'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reroll-die-0')));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('reroll-die-0')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('reroll-selected-dice')));
    await tester.pump(const Duration(milliseconds: 400));
    final rerolled =
        container.read(gameControllerProvider).pendingDecision!
            as AwaitingRerollChoice;
    expect(rerolled.dice, [2, 1, 1, 1]);
    expect(rerolled.availableRerolls, 0);
  });

  testWidgets('BUG030 round rollover is not reported as event consequences', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['phase'] = 'eventsPhase';
      doc['event_turn_index'] = 2;
      for (final player
          in (doc['players']! as List).cast<Map<String, dynamic>>()) {
        player['action_points'] = 0;
      }
      doc['pending_decision'] = {
        'type': 'event_option',
        'options': ['option-2'],
        'player_id': _player(doc)['id'],
        'event_id': 'cabin-noise',
      };
    });
    final container = await _mount(tester, state, dice: FixedDiceRoller([]));
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(
            const ResolvePendingDecisionCommand(EventOptionChoice('option-2')),
          ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Результат события'), findsOneWidget);
    expect(container.read(gameControllerProvider).round, 2);
    expect(find.textContaining('Следующий ход: +2 ОД'), findsNothing);
  });

  test('BUG031 ship-map text matches the printed source card', () {
    final translations = _scenario().contentTranslations;
    expect(
      translations['content.event.ship-map.description'],
      'Вы нашли карту корабля, которую никогда не видели до этого. '
      'На ней есть незнакомый вам проход.',
    );
    expect(
      translations['content.event.ship-map.option.o1.success'],
      'Вы рассматриваете карту и понимаете, что находитесь рядом с этим '
      'проходом. Свернув на него, вы натыкаетесь на дроида. '
      '«Привет, новый хозяин», - слышите вы. Возьмите робота из колоды '
      'предметов.',
    );
    expect(
      translations['content.event.ship-map.option.o1.failure'],
      'Вы быстро нашли этот проход, но долго не могли выбраться из него. '
      'В следующий ход вы выполняете на одно действие меньше.',
    );
    expect(
      translations['content.event.ship-map.option.o2.success'],
      'Понимая, что не очень сильны в картографии, вы мельком осматриваете '
      'карту и решаете оставить её там, где нашли. '
      'Откройте любой неизведанный фрагмент карты.',
    );
    expect(
      translations['content.event.ship-map.option.o2.failure'],
      translations['content.event.ship-map.option.o2.success'],
    );
  });

  testWidgets('BUG032 inventory exposes active card abilities', (tester) async {
    final state = _scenario((doc) {
      (_player(doc)['backpack']! as List).add('medic-bag');
      _player(doc)['damage'] = 1;
      _player(doc)['credits'] = 3;
    });
    final container = await _mount(
      tester,
      state,
      viewport: const Size(1280, 1600),
    );
    await tester.tap(find.byKey(mvpInventoryButtonKey));
    await tester.pump(const Duration(milliseconds: 400));
    final useButton = find.ancestor(
      of: find.text('Использовать'),
      matching: find.byType(FilledButton),
    );
    tester.widget<FilledButton>(useButton).onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('Саквояж фельдшера'), findsNWidgets(2));
    expect(find.textContaining('Лечение:'), findsOneWidget);
    await tester.tap(find.text('Лечить'));
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider).players.first.damage, 0);
    expect(container.read(gameControllerProvider).players.first.credits, 2);
    expect(container.read(gameControllerProvider).actionsLeft, 1);
  });

  testWidgets('BUG032 equipped R69-NIC3 can be activated from inventory', (
    tester,
  ) async {
    final state = _scenario((doc) {
      (_player(doc)['equipped']! as Map<String, dynamic>)['robot'] = 'r69-nic3';
    });
    final container = await _mount(
      tester,
      state,
      viewport: const Size(1280, 1600),
    );
    await tester.tap(find.byKey(mvpInventoryButtonKey));
    await tester.pump(const Duration(milliseconds: 400));

    final useButton = find.ancestor(
      of: find.text('Использовать'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(useButton).onPressed, isNotNull);
    tester.widget<FilledButton>(useButton).onPressed!.call();
    await tester.pumpAndSettle();

    final owner = container.read(gameControllerProvider).players.first;
    expect(owner.enemyFeaturesIgnoredThroughRound, 1);
    expect(owner.exhaustedRobots, contains('r69-nic3'));
  });

  testWidgets('BUG033 ship-map explains and enables fragment selection', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['phase'] = 'eventsPhase';
      final tiles = (doc['board']! as List).cast<Map<String, dynamic>>();
      final options = <String>[];
      for (final tile in tiles.where((tile) => tile['opened'] != true)) {
        final coord = tile['coord']! as Map<String, dynamic>;
        options.add('reveal:${coord['q']}:${coord['r']}');
      }
      doc['pending_decision'] = {
        'type': 'event_option',
        'options': options,
        'player_id': _player(doc)['id'],
        'event_id': 'ship-map',
      };
    });
    await _mount(tester, state);
    expect(
      find.textContaining('Выберите любой закрытый фрагмент'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('event-target-board-widget')),
      findsOneWidget,
    );
  });

  testWidgets(
    'BUG034 terminal offer shows full item and disables unaffordable buy',
    (
      tester,
    ) async {
      final state = _scenario((doc) {
        _player(doc)['credits'] = 3;
        doc['pending_decision'] = {
          'type': 'terminal_pick',
          'offered_cards': ['medkit'],
          'player_id': _player(doc)['id'],
          'deck_id': 'supplies',
        };
      });
      await _mount(tester, state);
      expect(find.textContaining('восполнить всё здоровье'), findsOneWidget);
      expect(find.text('Цена: ₡8'), findsOneWidget);
      final offer = find.byKey(const ValueKey<String>('terminal-offer-medkit'));
      expect(offer, findsOneWidget);
      final buy = find.descendant(
        of: offer,
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
    },
  );

  testWidgets('BUG016 roster follows equipment and removal', (tester) async {
    final state = _scenario();
    final container = await _mount(tester, state);
    expect(_rosterText(tester), contains('ЛОВ 3'));
    expect(_rosterText(tester), contains('ВЫН 2'));
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(
            const UnequipCommand(ItemSlot.clothing),
          ),
      isTrue,
    );
    await tester.pump();
    expect(_rosterText(tester), contains('ЛОВ 2'));
    expect(_rosterText(tester), contains('ВЫН 1'));
  });

  testWidgets('BUG016 roster follows conditions until healing', (tester) async {
    final state = _scenario((doc) {
      _player(doc)['conditions'] = ['fracture', 'fracture'];
    });
    final container = await _mount(tester, state);
    expect(_rosterText(tester), contains('ЛОВ 1'));
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(
            const HealCommand(1),
          ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(_rosterText(tester), contains('ЛОВ 3'));
  });

  testWidgets('BUG016 temporary effects stop at their recorded round', (
    tester,
  ) async {
    final state = _scenario((doc) {
      _player(doc)['monster_defense_bonus_round'] = 1;
      _player(doc)['monster_damage_immune_through_round'] = 1;
      (doc['decks']! as Map<String, dynamic>)['events'] = {
        'draw_pile': <String>[],
        'discard_pile': <String>[],
      };
    });
    final container = await _mount(tester, state);
    expect(_rosterText(tester), contains('ЗЩ 1'));
    expect(find.textContaining('Иммунитет к урону монстров'), findsOneWidget);
    final controller = container.read(gameControllerProvider.notifier);
    expect(controller.dispatch(const EndTurnCommand()), isTrue);
    expect(controller.dispatch(const EndTurnCommand()), isTrue);
    await tester.pump();
    expect(container.read(gameControllerProvider).round, 2);
    expect(_rosterText(tester), contains('ЗЩ 0'));
    expect(find.textContaining('Иммунитет к урону монстров'), findsNothing);
    expect(find.text('Защита +1 до конца раунда'), findsNothing);
  });

  testWidgets(
    'BUG017 movement label omits coordinates and moves selected hero',
    (
      tester,
    ) async {
      final state = _scenario((doc) {
        for (final tile
            in (doc['board']! as List).cast<Map<String, dynamic>>()) {
          tile['opened'] = true;
        }
      });
      final target = state.board.firstWhere(
        (tile) => validate(state, MoveCommand(tile.coord)) == null,
      );
      final container = await _mount(tester, state);
      await tester.tap(
        find.byKey(ValueKey('hex-${target.coord.q}-${target.coord.r}')),
      );
      await tester.pump();
      expect(find.text('ДВИЖЕНИЕ'), findsOneWidget);
      await tester.tap(find.text('ДВИЖЕНИЕ'));
      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(gameControllerProvider).players.first.coord,
        target.coord,
      );
    },
  );

  test('BUG018 spawning a monster does not replay distant attacks', () {
    final state = _scenario((doc) {
      _player(doc, 1)['coord'] = {'q': 2, 'r': 0};
    });
    final old = _monster('old', state.players.first.coord);
    final withOld = _scenario((doc) {
      _player(doc, 1)['coord'] = {'q': 2, 'r': 0};
      doc['monsters'] = [_monsterJson(old)];
    });
    final result = spawnMonster(
      withOld,
      _monster('new', state.players[1].coord),
    );
    expect(
      (result.pendingDecision! as AwaitingDodge).targetPlayerId,
      state.players[1].id,
    );
    expect(result.pendingDamage, isEmpty);
  });

  testWidgets('BUG018 dodge shows dice and damage then allows play', (
    tester,
  ) async {
    final state = spawnMonster(
      _scenario(),
      _monster('incoming', const HexCoord(0, 0)),
    );
    final container = await _mount(
      tester,
      state,
      dice: FixedDiceRoller([6, 1, 1, 6, 6, 6]),
    );
    await tester.tap(find.text('Уклониться'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Результат уклонения'), findsOneWidget);
    expect(find.textContaining('Кубики: 6, 1, 1'), findsOneWidget);
    expect(find.textContaining('Получено урона: 1'), findsOneWidget);
    await tester.tap(find.text('Продолжить'));
    await tester.pump();
    // A second co-located hero has a separate, finite decision.
    if (container.read(gameControllerProvider).pendingDecision
        is AwaitingDodge) {
      await tester.tap(find.text('Уклониться'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
    }
    expect(container.read(gameControllerProvider).pendingDecision, isNull);
    expect(find.text('Уклониться'), findsNothing);
  });

  testWidgets(
    'BUG019 campaign remains visible after events with selectable tabs',
    (
      tester,
    ) async {
      final state = _scenario((doc) {
        doc['round'] = 2;
        final quests = doc['quests']! as Map<String, dynamic>;
        quests['story_quest_ids'] = ['quest-01', 'quest-02'];
        quests['statuses'] = {'quest-01': 'active', 'quest-02': 'active'};
        _player(doc)['retained_event_cards'] = ['scientist-report'];
      });
      await _mount(tester, state);
      expect(find.text('ОЖИДАНИЕ СОБЫТИЯ'), findsNothing);
      expect(find.text('СЮЖЕТ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('active-quest-tab-quest-01')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('active-event-tab-scientist-report')),
      );
      await tester.pump();
      expect(find.text('СОБЫТИЕ'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('active-quest-tab-quest-02')));
      await tester.pump();
      expect(find.text('СЮЖЕТ'), findsOneWidget);
    },
  );

  testWidgets('BUG020 event description is readable without truncation', (
    tester,
  ) async {
    const description =
        'Длинное описание события. Строка условий. '
        'Первая подробность. Вторая подробность. Третья подробность. '
        'Четвёртая подробность. Пятая подробность. Шестая подробность. '
        'Седьмая подробность. Восьмая подробность. Последняя важная строка.';
    final state = _scenario((doc) {
      _player(doc)['retained_event_cards'] = ['scientist-report'];
      final translations = doc['content_translations']! as Map<String, dynamic>;
      translations['content.event.scientist-report.description'] = description;
    });
    await _mount(tester, state);
    await tester.tap(
      find.byKey(const ValueKey('active-event-tab-scientist-report')),
    );
    await tester.pump();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(description),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  for (final succeeded in [true, false]) {
    testWidgets(
      'BUG020 event outcome shows ${succeeded ? 'success' : 'failure'} '
      'and actual consequences',
      (
        tester,
      ) async {
        final state = _eventCheckState();
        final container = await _mount(
          tester,
          state,
          dice: FixedDiceRoller(List.filled(12, succeeded ? 6 : 1)),
        );
        final controller = container.read(gameControllerProvider.notifier);
        expect(
          controller.dispatch(
            const ResolvePendingDecisionCommand(
              EventOptionChoice('option-2'),
            ),
          ),
          isTrue,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Продолжить'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Результат события'), findsOneWidget);
        expect(
          find.textContaining(succeeded ? 'Успех' : 'Провал'),
          findsWidgets,
        );
        expect(
          find.textContaining(
            succeeded
                ? 'Восстановите 3 здоровья и в следующий ход выполните '
                      'на одно действие больше.'
                : 'В следующий ход выполните на одно действие меньше.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  test('BUG021 ordinary skill check has no unearned reroll', () {
    final state = _scenario();
    final result = step(
      state,
      const SkillCheckCommand(StatType.science),
      FixedDiceRoller([1, 1, 1, 1]),
    );
    expect(
      (result.state.pendingDecision! as AwaitingRerollChoice).availableRerolls,
      0,
    );
    final rejected = step(
      result.state,
      ResolvePendingDecisionCommand(RerollChoice()),
      FixedDiceRoller([6, 6, 6, 6]),
    );
    expect(rejected.isAccepted, isFalse);
  });

  test('BUG021 wrench reroll keeps its printed repair scope', () {
    final state = _scenario((doc) {
      (_player(doc)['equipped']! as Map<String, dynamic>)['weapon'] =
          'pipe-wrench';
    });
    for (final stat in [StatType.repair, StatType.science]) {
      final checked = step(
        state,
        SkillCheckCommand(stat),
        FixedDiceRoller(List.filled(20, 1)),
      );
      final pending = checked.state.pendingDecision! as AwaitingRerollChoice;
      expect(pending.availableRerolls, stat == StatType.repair ? 1 : 0);
      if (stat == StatType.repair) {
        final rerolled = step(
          checked.state,
          ResolvePendingDecisionCommand(RerollChoice()),
          FixedDiceRoller(List.filled(20, 6)),
        );
        expect(rerolled.isAccepted, isTrue);
        expect(
          (rerolled.state.pendingDecision! as AwaitingRerollChoice)
              .availableRerolls,
          0,
        );
        expect(
          step(
            rerolled.state,
            ResolvePendingDecisionCommand(RerollChoice()),
            FixedDiceRoller(List.filled(20, 6)),
          ).isAccepted,
          isFalse,
        );
      }
    }
  });

  test('BUG024 DRG rerolls strength only while equipped', () {
    final state = _scenario((doc) {
      (_player(doc)['equipped']! as Map<String, dynamic>)['robot'] = 'drg-4u';
    });
    expect(
      state.cardDefinitions['drg-4u']!.behaviorIds,
      contains('dice.reroll.all'),
    );
    for (final stat in StatType.values) {
      final checked = step(
        state,
        SkillCheckCommand(stat),
        FixedDiceRoller(List.filled(20, 1)),
      );
      expect(checked.isAccepted, isTrue);
      final pending = checked.state.pendingDecision! as AwaitingRerollChoice;
      expect(pending.availableRerolls, stat == StatType.strength ? 1 : 0);
      if (stat == StatType.strength) {
        expect(skillRerollSources(state, state.players.first, stat), [
          'drg-4u',
        ]);
        final rerolled = step(
          checked.state,
          ResolvePendingDecisionCommand(RerollChoice()),
          FixedDiceRoller(List.filled(20, 6)),
        );
        expect(rerolled.isAccepted, isTrue);
        final result = rerolled.state.pendingDecision! as AwaitingRerollChoice;
        expect(result.dice, List.filled(pending.dice.length, 6));
        expect(result.availableRerolls, 0);
        expect(
          step(
            rerolled.state,
            ResolvePendingDecisionCommand(RerollChoice()),
            FixedDiceRoller(List.filled(20, 6)),
          ).isAccepted,
          isFalse,
        );
      }
    }
    final unequipped = step(
      state,
      const UnequipCommand(ItemSlot.robot),
      FixedDiceRoller([]),
    );
    expect(unequipped.isAccepted, isTrue);
    expect(unequipped.state.players.first.backpack, contains('drg-4u'));
    final checked = step(
      unequipped.state,
      const SkillCheckCommand(StatType.strength),
      FixedDiceRoller(List.filled(20, 1)),
    );
    expect(checked.isAccepted, isTrue);
    expect(
      (checked.state.pendingDecision! as AwaitingRerollChoice).availableRerolls,
      0,
    );
  });

  testWidgets('BUG024 DRG source is shown for a strength reroll', (
    tester,
  ) async {
    final state = _scenario((doc) {
      (_player(doc)['equipped']! as Map<String, dynamic>)['robot'] = 'drg-4u';
    });
    final container = await _mount(
      tester,
      state,
      dice: FixedDiceRoller(List.filled(20, 1)),
    );
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(const SkillCheckCommand(StatType.strength)),
      isTrue,
    );
    await tester.pump();
    expect(find.text('Переброс даёт: DRG-4U'), findsOneWidget);
    expect(find.text('Перебросить'), findsOneWidget);
    await tester.tap(find.text('Перебросить'));
    await tester.pump();
    expect(find.text('Перебросить'), findsNothing);
    expect(find.textContaining('Переброс даёт:'), findsNothing);
  });

  testWidgets('BUG021 legal reroll explains its item source', (tester) async {
    final state = _scenario((doc) {
      (_player(doc)['equipped']! as Map<String, dynamic>)['weapon'] =
          'pipe-wrench';
    });
    final container = await _mount(
      tester,
      state,
      dice: FixedDiceRoller(List.filled(20, 1)),
    );
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(const SkillCheckCommand(StatType.repair)),
      isTrue,
    );
    await tester.pump();
    expect(find.textContaining('Переброс даёт:'), findsOneWidget);
    expect(find.text('Перебросить'), findsOneWidget);
  });

  test('BUG018 unrelated movement does not retrigger a stationary threat', () {
    final state = _scenario((doc) {
      for (final tile in (doc['board']! as List).cast<Map<String, dynamic>>()) {
        tile['opened'] = true;
      }
      doc['monsters'] = [
        _monsterJson(_monster('stationary', const HexCoord(0, 0))),
      ];
      // The second hero stays with the threat while the active hero leaves.
    });
    final target = state.board.firstWhere(
      (tile) => validate(state, MoveCommand(tile.coord)) == null,
    );
    final moved = step(state, MoveCommand(target.coord), FixedDiceRoller([]));
    expect(moved.isAccepted, isTrue);
    expect(moved.state.pendingDecision, isNull);
    expect(moved.state.pendingDamage, isEmpty);
  });

  testWidgets('BUG020 automatic outcome is visible without a roll', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['phase'] = 'eventsPhase';
      doc['event_turn_index'] = 2;
      doc['pending_decision'] = {
        'type': 'event_option',
        'options': ['option-2'],
        'player_id': _player(doc)['id'],
        'event_id': 'cabin-noise',
      };
    });
    final container = await _mount(tester, state, dice: FixedDiceRoller([]));
    expect(
      container
          .read(gameControllerProvider.notifier)
          .dispatch(
            const ResolvePendingDecisionCommand(EventOptionChoice('option-2')),
          ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Результат события'), findsOneWidget);
    expect(find.textContaining('Успех'), findsOneWidget);
    expect(find.textContaining('Кубики:'), findsNothing);
  });

  testWidgets('BUG020 successful event shows actually received loot', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['phase'] = 'eventsPhase';
      doc['event_turn_index'] = 2;
      doc['pending_decision'] = {
        'type': 'event_option',
        'options': ['option-1'],
        'player_id': _player(doc)['id'],
        'event_id': 'cabin-noise',
      };
    });
    final container = await _mount(
      tester,
      state,
      dice: FixedDiceRoller(List.filled(20, 6)),
    );
    final controller = container.read(gameControllerProvider.notifier);
    expect(
      controller.dispatch(
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      ),
      isTrue,
    );
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(gameControllerProvider).players.first.backpack,
      hasLength(1),
    );
    expect(find.textContaining('Получено:'), findsOneWidget);
  });

  testWidgets('BUG022 field action label fits completely', (tester) async {
    final state = _scenario();
    final target = state.board.firstWhere(
      (tile) =>
          tile.type == HexTileType.corridor &&
          validate(state, RevealTileCommand(tile.coord)) == null,
    );
    await _mount(tester, state);
    await tester.tap(
      find.byKey(ValueKey('hex-${target.coord.q}-${target.coord.r}')),
    );
    await tester.pump();
    final label = find.textContaining('ОТКРЫТЬ КОРИДОР');
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    await tester.tap(find.byKey(const ValueKey('text-scale-button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('text-scale-button')));
    await tester.pump();
    expect(
      tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('BUG023 Restless attack waits for animation then resolves', (
    tester,
  ) async {
    final state = _scenario((doc) {
      doc['monsters'] = [
        _monsterJson(
          _monster('restless-target', const HexCoord(0, 0), restless: true),
        ),
      ];
    });
    final queue = EventQueue(eventDuration: const Duration(seconds: 1));
    final container = await _mount(
      tester,
      state,
      queue: queue,
      dice: FixedDiceRoller([6, 6, 6, 6]),
      viewport: const Size(1211, 650),
    );
    queue.enqueue([const DamageDealt(playerId: 'player-1', amount: 1)]);
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            (widget.message?.startsWith('Карточка монстра:') ?? false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Сила боя:'), findsOneWidget);
    expect(find.textContaining('Здоровье:'), findsOneWidget);
    expect(find.textContaining('Защита:'), findsOneWidget);
    expect(find.textContaining('Атака:'), findsOneWidget);
    expect(find.textContaining('Движение:'), findsOneWidget);
    final queueWarning = find.text('Дождитесь завершения анимации.');
    expect(queueWarning, findsOneWidget);
    final cardViewport = tester.getRect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final warningBounds = tester.getRect(queueWarning);
    expect(
      cardViewport.contains(warningBounds.topLeft) &&
          cardViewport.contains(warningBounds.bottomRight),
      isTrue,
    );
    final attack = find.widgetWithText(TextButton, 'Атаковать');
    expect(tester.widget<TextButton>(attack).onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<TextButton>(attack).onPressed, isNotNull);
    await tester.tap(attack);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(gameControllerProvider).monsters, isEmpty);
    expect(container.read(gameControllerProvider).actionsLeft, 1);
    expect(find.text('Результат атаки'), findsOneWidget);
  });

  testWidgets('BUG035 monster stats fit in the card on a short screen', (
    tester,
  ) async {
    final state = _scenarioWithCharacters(
      const ['guard', 'worker', 'mechanic', 'scientist'],
      (doc) {
        doc['round'] = 4;
        doc['phase'] = 'playersTurn';
        doc['actions_left'] = 2;
        final start = _player(doc)['coord']! as Map<String, dynamic>;
        for (final player
            in (doc['players']! as List).cast<Map<String, dynamic>>()) {
          player['coord'] = Map<String, dynamic>.of(start);
        }
        doc['monsters'] = [
          _monsterJson(
            MonsterInstance(
              instanceId: 'plagued-target',
              monsterId: 'plagued',
              coord: HexCoord(start['q']! as int, start['r']! as int),
              damage: 0,
              health: 4,
              defense: 1,
              attack: 3,
              movement: 2,
            ),
          ),
        ];
      },
    );
    await _mount(tester, state, viewport: const Size(1211, 650));
    await tester.tap(find.byTooltip('Карточка монстра: Чумной'));
    await tester.pump(const Duration(milliseconds: 300));

    final scrollViewport = tester.getRect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    for (final label in const [
      'Здоровье: 4/4',
      'Защита: 1',
      'Атака: 3',
      'Движение: 2',
    ]) {
      final stat = find.text(label);
      expect(stat, findsOneWidget);
      final bounds = tester.getRect(stat);
      expect(
        scrollViewport.contains(bounds.topLeft) &&
            scrollViewport.contains(bounds.bottomRight),
        isTrue,
        reason: '$label должен быть виден без прокрутки карточки',
      );
    }
    final attack = find.widgetWithText(TextButton, 'Атаковать');
    expect(tester.widget<TextButton>(attack).onPressed, isNotNull);
  });

  testWidgets('BUG035 explains when hero and monster are in different cells', (
    tester,
  ) async {
    final state = _scenario((doc) {
      final start = _player(doc)['coord']! as Map<String, dynamic>;
      final otherTile = (doc['board']! as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((tile) {
            final coord = tile['coord']! as Map<String, dynamic>;
            return coord['q'] != start['q'] || coord['r'] != start['r'];
          });
      final coord = otherTile['coord']! as Map<String, dynamic>;
      doc['monsters'] = [
        _monsterJson(
          MonsterInstance(
            instanceId: 'plagued-target',
            monsterId: 'plagued',
            coord: HexCoord(coord['q']! as int, coord['r']! as int),
            damage: 0,
            health: 4,
            defense: 1,
            attack: 3,
            movement: 2,
          ),
        ),
      ];
    });
    await _mount(tester, state, viewport: const Size(1211, 650));
    await tester.tap(find.byTooltip('Карточка монстра: Чумной'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Атаковать'),
          )
          .onPressed,
      isNull,
    );
    final reason = find.text('Герой должен быть в одной клетке с монстром.');
    expect(reason, findsOneWidget);
    final scrollViewport = tester.getRect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    final reasonBounds = tester.getRect(reason);
    expect(
      scrollViewport.contains(reasonBounds.topLeft) &&
          scrollViewport.contains(reasonBounds.bottomRight),
      isTrue,
    );
  });
}

GameState _scenario([void Function(Map<String, dynamic>)? edit]) =>
    _scenarioWithCharacters(const ['scientist', 'guard'], edit);

GameState _scenarioWithCharacters(
  List<String> characterIds, [
  void Function(Map<String, dynamic>)? edit,
]) {
  final codec = GameStateJsonCodec();
  final source = createFullGameState(
    characterIds: characterIds,
    seed: 42,
  );
  final doc = jsonDecode(codec.encode(source)) as Map<String, dynamic>;
  edit?.call(doc);
  return codec.fromJson(doc);
}

Map<String, dynamic> _player(Map<String, dynamic> doc, [int index = 0]) =>
    (doc['players']! as List)[index] as Map<String, dynamic>;

MonsterInstance _monster(String id, HexCoord coord, {bool restless = false}) =>
    restless
    ? RestlessMonster(
        instanceId: id,
        coord: coord,
        attack: 2,
        defense: 0,
        carriedGear: const [],
      )
    : MonsterInstance(
        instanceId: id,
        monsterId: 'test-ghoul',
        coord: coord,
        damage: 0,
        health: 2,
        attack: 2,
      );

Map<String, Object?> _monsterJson(MonsterInstance monster) => {
  'instance_id': monster.instanceId,
  'monster_id': monster.monsterId,
  'coord': {'q': monster.coord.q, 'r': monster.coord.r},
  'damage': monster.damage,
  'health': monster.health,
  'defense': monster.defense,
  'attack': monster.attack,
  'movement': monster.movement,
  'carried_gear': monster.carriedGear,
};

GameState _eventCheckState() => _scenario((doc) {
  doc['phase'] = 'eventsPhase';
  doc['event_turn_index'] = 2;
  _player(doc)['damage'] = 4;
  doc['pending_decision'] = {
    'type': 'event_option',
    'options': ['option-2'],
    'player_id': _player(doc)['id'],
    'event_id': 'alcohol-crate',
  };
});

Future<ProviderContainer> _mount(
  WidgetTester tester,
  GameState state, {
  DiceRoller? dice,
  EventQueue? queue,
  Size viewport = const Size(1280, 800),
}) async {
  final events = queue ?? EventQueue(eventDuration: Duration.zero);
  final container = ProviderContainer(
    overrides: [
      eventQueueProvider.overrideWithValue(events),
      gameControllerProvider.overrideWith(
        () => GameController(initialState: state, dice: dice),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(events.dispose);
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: DefaultAssetBundle(
        bundle: _TransparentAssetBundle(),
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

String _rosterText(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining('СИЛ ').first).data!;

class _TransparentAssetBundle extends CachingAssetBundle {
  static final Uint8List _transparentPng = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5k8AAAAASUVORK5CYII=',
    ),
  );

  @override
  Future<ByteData> load(String key) async =>
      key.endsWith('.png') || key.endsWith('.webp')
      ? ByteData.sublistView(_transparentPng)
      : rootBundle.load(key);
}
