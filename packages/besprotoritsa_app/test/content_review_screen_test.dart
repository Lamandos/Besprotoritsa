import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows content fields and records human review', (tester) async {
    final store = MemoryReviewStatusStore();
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ContentReviewScreen(statusStore: store),
      ),
    );
    await tester.pump();

    expect(find.text('Поля JSON'), findsOneWidget);
    expect(find.text('content.monster.volot.name'), findsOneWidget);
    expect(find.text('monster-standard'), findsOneWidget);
    expect(find.text('Пройдено · monster behavior registry'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('mark-human-reviewed')));
    await tester.pump();

    expect(find.text('Сверено человеком ✓'), findsOneWidget);
    expect(await store.reviewedIds(), contains('monster.volot'));
  });
}
