import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
