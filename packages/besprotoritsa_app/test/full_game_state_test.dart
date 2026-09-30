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
    expect(
      state.reserveHeroes.map((hero) => hero.characterId),
      ['hauler', 'healer', 'engineer', 'astronaut'],
    );
    expect(state.cardDefinitions.keys, containsAll(['pistol', 'lucky-socks']));
    expect(state.cardDefinitions.keys, contains('nanobots'));
    expect(state.cardDefinitions.keys, contains('assault-rifle'));
    expect(state.conditionCards.keys, contains('malaise'));
    expect(state.board, hasLength(35));
    expect(state.board.where((tile) => tile.opened), hasLength(1));
    expect(state.decks['conditions']!.drawPile, hasLength(50));
    expect(state.decks['events']!.drawPile, hasLength(88));
    expect(state.eventDefinitions, hasLength(88));
    final cabinNoiseOptions =
        state.eventDefinitions['cabin-noise']!['options']! as List;
    expect(
      (cabinNoiseOptions.first as Map<String, Object?>)['behaviorId'],
      'event_cabin_noise',
    );
    expect(state.questDefinitions, hasLength(29));
    expect(state.taskDefinitions, hasLength(16));
    expect(state.monsterDefinitions, hasLength(16));
    expect(
      state.contentTranslations[state
              .eventDefinitions['cabin-noise']!['nameKey']!
          as String],
      'Шум в каюте',
    );
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
    expect(state.players[0].equipped.clothing, 'lucky-socks');
    expect(state.players[0].backpack, isEmpty);
    expect(state.players[2].equipped.armor, 'hard-hat');
    expect(state.players[2].backpack, isEmpty);
    expect(state.reserveHeroes.last.equipped.armor, 'spacesuit-mk2');
  });

  test('full runtime event definitions survive a save round trip', () {
    final state = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 21,
    );
    final codec = GameStateJsonCodec();
    final restored = codec.decode(codec.encode(state));

    expect(restored.eventDefinitions, hasLength(88));
    expect(restored.questDefinitions, hasLength(29));
    expect(restored.taskDefinitions, hasLength(16));
    expect(restored.monsterDefinitions, hasLength(16));
    expect(
      restored.eventDefinitions['vending-machine']!['options'],
      state.eventDefinitions['vending-machine']!['options'],
    );
    expect(
      restored.contentTranslations[restored
              .eventDefinitions['vending-machine']!['nameKey']!
          as String],
      'Торговый автомат',
    );
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
