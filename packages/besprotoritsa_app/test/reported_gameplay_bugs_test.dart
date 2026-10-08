import 'dart:convert';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        await tester.tap(find.text('Оставить результат'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Результат события'), findsOneWidget);
        expect(
          find.textContaining(succeeded ? 'Успех' : 'Провал'),
          findsWidgets,
        );
        expect(
          find.textContaining(
            succeeded ? 'Вылечено урона: 3' : 'Следующий ход: −1 ОД',
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
    await tester.tap(find.text('Оставить результат'));
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
}

GameState _scenario([void Function(Map<String, dynamic>)? edit]) {
  final codec = GameStateJsonCodec();
  final source = createFullGameState(
    characterIds: const ['scientist', 'guard'],
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
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MvpGameScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

String _rosterText(WidgetTester tester) =>
    tester.widget<Text>(find.textContaining('СИЛ ').first).data!;
