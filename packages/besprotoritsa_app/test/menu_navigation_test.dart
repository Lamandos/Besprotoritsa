import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMenu(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameStorageProvider.overrideWithValue(InMemoryGameStorage()),
      ],
      child: const BesprotoritsaApp(),
    ),
  );

  testWidgets('new game opens a roster with two heroes selected', (
    tester,
  ) async {
    await pumpMenu(tester);

    await tester.tap(find.byKey(const ValueKey<String>('new-game-button')));
    await tester.pumpAndSettle();

    expect(find.text('Сформируйте отряд'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('roster-count')), findsOneWidget);
    expect(find.text('Героев: 2/4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('start-game-button')),
      findsOneWidget,
    );
  });

  testWidgets('menu opens the rulebook and interactive tutorial', (
    tester,
  ) async {
    await pumpMenu(tester);

    await tester.tap(find.byKey(const ValueKey<String>('rules-button')));
    await tester.pumpAndSettle();
    expect(find.text('Справочник правил'), findsOneWidget);
    expect(find.text('Движение'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('tutorial-button')));
    await tester.pumpAndSettle();
    expect(find.text('Раунд 1/3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('tutorial-action-0')));
    await tester.pump();
    expect(find.text('Осмотреть отсек'), findsNWidgets(2));
  });

  testWidgets('menu opens the list of save slots', (tester) async {
    await pumpMenu(tester);

    await tester.tap(find.byKey(const ValueKey<String>('load-game-button')));
    await tester.pumpAndSettle();

    expect(find.text('Последнее автосохранение'), findsOneWidget);
    expect(find.text('Слот 1'), findsOneWidget);
    expect(find.text('Пусто'), findsNWidgets(4));
  });
}
