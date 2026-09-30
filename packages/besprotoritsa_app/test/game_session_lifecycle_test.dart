import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/menu/game_session_screen.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system Back saves before the active game route is disposed', (
    tester,
  ) async {
    final storage = InMemoryGameStorage();
    await _openGame(tester, storage);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('open-game')), findsOneWidget);
    expect((await storage.loadGame('autosave'))!.round, 1);
  });

  testWidgets('pause and resume retain the session and persist an autosave', (
    tester,
  ) async {
    final storage = InMemoryGameStorage();
    await _openGame(tester, storage);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect((await storage.loadGame('autosave'))!.round, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('manual-save-button')),
      findsOneWidget,
    );
  });

  testWidgets('isolated autosaves do not hide manual saves from normal slots', (
    tester,
  ) async {
    final storage = InMemoryGameStorage();
    final autosaveStorage = InMemoryGameStorage();
    await _openGame(tester, storage, autosaveStorage: autosaveStorage);

    expect(await storage.loadGame('autosave'), isNull);
    expect(await autosaveStorage.loadGame('autosave'), isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('manual-save-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(await storage.loadGame('slot-1'), isNotNull);
    expect(await autosaveStorage.loadGame('slot-1'), isNull);
  });
}

Future<void> _openGame(
  WidgetTester tester,
  GameStorage storage, {
  GameStorage? autosaveStorage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            key: const ValueKey<String>('open-game'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => GameSessionScreen(
                  initialState: createMvpGameState(),
                  storage: storage,
                  autosaveStorage: autosaveStorage,
                ),
              ),
            ),
            child: const Text('Open game'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey<String>('open-game')));
  await tester.pumpAndSettle();
}
