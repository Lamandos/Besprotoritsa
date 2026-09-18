import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the MVP start screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BesprotoritsaApp(),
      ),
    );

    expect(find.text('Беспроторица'), findsOneWidget);
    expect(find.text('0.1.0-dev'), findsOneWidget);
    expect(find.text('Одиночная игра / Локально'), findsOneWidget);
    expect(find.text('Запуск MVP (Демо)'), findsOneWidget);
  });
}
