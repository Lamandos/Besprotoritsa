import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGameAtSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MvpGameScreen())),
    );
  }

  testWidgets('phone portrait keeps the board compact with a floating dock', (
    tester,
  ) async {
    await pumpGameAtSize(tester, const Size(390, 844));

    expect(find.byKey(mvpCompactLayoutKey), findsOneWidget);
    expect(find.byKey(mvpWideLayoutKey), findsNothing);
    expect(find.byKey(mvpBoardInteractiveViewerKey), findsOneWidget);
    expect(find.byKey(mvpBoardStaticRepaintBoundaryKey), findsOneWidget);
    expect(find.byKey(mvpBoardTokensRepaintBoundaryKey), findsOneWidget);

    final inventoryButton = find.byKey(mvpInventoryButtonKey);
    expect(tester.getSize(inventoryButton), equals(const Size(48, 48)));
    expect(
      tester.getSize(find.byKey(mvpJournalButtonKey)),
      equals(const Size(48, 48)),
    );

    await tester.tap(inventoryButton);
    await tester.pumpAndSettle();
    expect(find.byKey(mvpInventorySheetKey), findsOneWidget);
    expect(find.text('Инвентарь'), findsOneWidget);

    Navigator.of(tester.element(find.byKey(mvpInventorySheetKey))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(mvpJournalButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(mvpJournalSheetKey), findsOneWidget);
    expect(find.text('Активные задания'), findsOneWidget);
  });

  testWidgets('tablet portrait also uses the compact game layout', (
    tester,
  ) async {
    await pumpGameAtSize(tester, const Size(800, 1280));

    expect(find.byKey(mvpCompactLayoutKey), findsOneWidget);
    expect(find.byKey(mvpWideLayoutKey), findsNothing);
  });

  testWidgets('desktop landscape exposes the three persistent game panels', (
    tester,
  ) async {
    await pumpGameAtSize(tester, const Size(1280, 800));

    expect(find.byKey(mvpWideLayoutKey), findsOneWidget);
    expect(find.byKey(mvpCompactLayoutKey), findsNothing);
    expect(find.text('Отряд героев'), findsOneWidget);
    expect(find.text('Журнал'), findsOneWidget);
    expect(find.text('Активные задания'), findsOneWidget);
    expect(find.byKey(mvpBoardInteractiveViewerKey), findsOneWidget);
  });
}
