import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the main menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BesprotoritsaApp(),
      ),
    );

    expect(find.text('БЕСПРОТОРИЦА'), findsOneWidget);
    expect(find.text('Новая полная партия'), findsOneWidget);
    expect(find.text('Короткая демонстрация'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Загрузить партию'), findsOneWidget);
    expect(find.text('Обучение'), findsOneWidget);
    expect(find.text('Справочник правил'), findsOneWidget);
  });
}
