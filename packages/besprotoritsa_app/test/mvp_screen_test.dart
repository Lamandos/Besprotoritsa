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
      final container = ProviderContainer(
        overrides: [eventQueueProvider.overrideWithValue(queue)],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);

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

      await tester.tap(find.text('Ход: 0, 1'));
      await tester.pump();

      expect(queue.current, isA<HexEntered>());
      expect(queue.pendingCount, 2);
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
