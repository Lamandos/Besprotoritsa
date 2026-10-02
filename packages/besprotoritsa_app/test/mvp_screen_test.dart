import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared journal does not reveal personal task cards', (
    tester,
  ) async {
    final initialState = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 31,
    );
    final privateTaskId =
        initialState.quests.personalTasksByPlayer.values.first.first;
    final privateTaskNameKey =
        initialState.taskDefinitions[privateTaskId]!['nameKey']! as String;
    final privateTaskName =
        initialState.contentTranslations[privateTaskNameKey]!;
    final queue = EventQueue(eventDuration: const Duration(seconds: 1));
    final container = ProviderContainer(
      overrides: [
        eventQueueProvider.overrideWithValue(queue),
        gameControllerProvider.overrideWith(
          () => GameController(initialState: initialState),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(queue.dispose);
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
    await tester.tap(
      find.byKey(const ValueKey<String>('wide-turn-log-button-bottom')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Текущая цель кампании'), findsOneWidget);
    expect(find.text('Пробуждение'), findsWidgets);
    expect(find.textContaining('0/1'), findsWidgets);
    expect(find.text(privateTaskName), findsNothing);
    await tester.tap(find.text('Личные задачи активного героя'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(privateTaskName), findsOneWidget);
  });

  testWidgets(
    'moving queues animation events and updates the hero position',
    (tester) async {
      final queue = EventQueue(eventDuration: const Duration(seconds: 1));
      final initialState = _stateWithoutMonsters();
      final container = ProviderContainer(
        overrides: [
          eventQueueProvider.overrideWithValue(queue),
          gameControllerProvider.overrideWith(
            () => GameController(initialState: initialState),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);

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

      expect(find.text('СЮЖЕТ'), findsOneWidget);
      expect(
        find.textContaining('Доберитесь до КАЮТ-КОМПАНИИ'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsOneWidget,
      );
      expect(queue.isPlaying, isFalse);
      expect(
        find.byKey(mvpMoveConfirmButtonKey),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('hero-ada-at-0-0')));
      await tester.tap(find.byKey(const ValueKey<String>('hex-0-1')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(mvpMoveConfirmButtonKey))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(mvpMoveConfirmButtonKey));
      await tester.pump();

      expect(queue.current, isNull);
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hex-0-1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('hex-0-1')));
      await tester.pump();
      await tester.tap(find.byKey(mvpMoveConfirmButtonKey));
      await tester.pump();

      expect(queue.current, isA<HexEntered>());
      expect(queue.pendingCount, 1);
      expect(
        find.byKey(const ValueKey<String>('animation-status')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('hero-ada-at-0-1')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    },
  );
}

GameState _stateWithoutMonsters() {
  final state = createMvpGameState();
  return GameState(
    seed: state.seed,
    difficulty: state.difficulty,
    round: state.round,
    phase: state.phase,
    activePlayerId: state.activePlayerId,
    actionsLeft: state.actionsLeft,
    board: state.board,
    players: state.players,
    monsters: const [],
    decks: state.decks,
    quests: state.quests,
    conditionCards: state.conditionCards,
    cardDefinitions: state.cardDefinitions,
    log: state.log,
  );
}
