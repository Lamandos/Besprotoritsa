import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/menu/roster_selection_screen.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full runtime state loads the full character and card catalog', () {
    final state = createFullGameState(
      characterIds: const ['scientist', 'guard', 'mechanic', 'worker'],
      seed: 73,
    );

    expect(fullRuntimeCharacters, hasLength(8));
    expect(state.players.map((player) => player.characterId), [
      'scientist',
      'guard',
      'mechanic',
      'worker',
    ]);
    expect(state.cardDefinitions.keys, containsAll(['pistol', 'lucky-socks']));
    expect(state.cardDefinitions.keys, contains('nanobots'));
    expect(state.cardDefinitions.keys, contains('assault-rifle'));
    expect(state.conditionCards.keys, contains('malaise'));
    expect(state.board, hasLength(35));
    expect(state.board.where((tile) => tile.opened), hasLength(1));
    expect(state.decks['conditions']!.drawPile, hasLength(50));
    expect(state.decks['events']!.drawPile, hasLength(88));
    expect(state.decks['items']!.drawPile, hasLength(42));
    expect(state.decks['supplies']!.drawPile, hasLength(64));
    expect(state.decks['specialItems']!.drawPile, hasLength(7));
    expect(state.decks['monsters']!.drawPile, hasLength(41));
    expect(state.decks['restlessReserve']!.drawPile, hasLength(7));
    expect(state.decks['tasks']!.drawPile, hasLength(8));
    expect(
      state.quests.personalTasksByPlayer.values,
      everyElement(hasLength(2)),
    );
    expect(state.quests.storyQuestIds, ['quest-01']);
  });

  test('full runtime deck order is reproducible for the same seed', () {
    final first = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 21,
    );
    final second = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 21,
    );
    expect(
      first.decks['conditions']!.drawPile,
      equals(second.decks['conditions']!.drawPile),
    );
    expect(
      first.decks['events']!.drawPile,
      equals(second.decks['events']!.drawPile),
    );
  });

  testWidgets('roster screen exposes characters from the selected full set', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RosterSelectionScreen(storage: InMemoryGameStorage()),
      ),
    );
    await tester.tap(find.text('Полный набор'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('content-set-selector')),
      findsOneWidget,
    );
    expect(find.text('Рабочий'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Таскала'), 300);
    expect(find.text('Таскала'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Астронавт'), 300);
    expect(find.text('Астронавт'), findsOneWidget);
  });
}
