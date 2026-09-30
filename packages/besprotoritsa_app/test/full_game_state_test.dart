import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/menu/roster_selection_screen.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
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
    expect(
      state.board.singleWhere((tile) => tile.id == 'anabiosis').opened,
      isTrue,
    );
    expect(
      state.board.where((tile) => tile.type == HexTileType.corridor),
      hasLength(18),
    );
    expect(
      state.board.where((tile) => tile.type == HexTileType.compartment),
      hasLength(12),
    );
    expect(
      state.board.where((tile) => tile.type == HexTileType.airlock),
      hasLength(4),
    );
    expect(
      state.board
          .where((tile) => tile.hasTerminal)
          .map((tile) => tile.id)
          .toSet(),
      storyTerminalLocationIds,
    );
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
    expect(state.seed, 73);
    expect(state.leaderPlayerId, state.players.first.id);
    expect(state.turnOrder, state.players.map((player) => player.id));
    expect(state.players[0].equipped.clothing, 'lucky-socks');
    expect(state.players[0].backpack, isEmpty);
    expect(state.players[2].equipped.armor, 'hard-hat');
    expect(state.players[2].backpack, isEmpty);
    expect(state.reserveHeroes.last.equipped.armor, 'spacesuit-mk2');
  });

  test('full party setup is linked and reproducible across the full set', () {
    final first = createFullGameState(
      characterIds: const ['scientist', 'guard', 'mechanic', 'worker'],
      seed: 73,
    );
    final sameSeed = createFullGameState(
      characterIds: const ['scientist', 'guard', 'mechanic', 'worker'],
      seed: 73,
    );
    final otherSeed = createFullGameState(
      characterIds: const ['scientist', 'guard', 'mechanic', 'worker'],
      seed: 74,
    );

    expect(first.board.map(_tileSignature), sameSeed.board.map(_tileSignature));
    expect(first.decks.keys, sameSeed.decks.keys);
    for (final deckId in first.decks.keys) {
      expect(first.decks[deckId]!.drawPile, sameSeed.decks[deckId]!.drawPile);
      expect(first.decks[deckId]!.discardPile, isEmpty);
      expect(sameSeed.decks[deckId]!.discardPile, isEmpty);
    }
    expect(
      first.quests.personalTasksByPlayer,
      sameSeed.quests.personalTasksByPlayer,
    );
    expect(
      first.board.map(_tileSignature),
      isNot(otherSeed.board.map(_tileSignature)),
    );

    for (final state in [first, otherSeed]) {
      _expectFullBoard(state);
      expect(
        state.quests.personalTasksByPlayer.values,
        everyElement(hasLength(2)),
      );
      expect(
        state.quests.personalTasksByPlayer.values
            .expand((tasks) => tasks)
            .toSet(),
        hasLength(8),
      );
      expect(state.quests.storyQuestIds, ['quest-01']);
      expect(state.leaderPlayerId, state.turnOrder.first);
      expect(state.activePlayerId, state.leaderPlayerId);
      expect(state.decks['conditions']!.drawPile, hasLength(50));
      expect(state.decks['events']!.drawPile, hasLength(88));
      expect(state.decks['items']!.drawPile, hasLength(42));
      expect(state.decks['supplies']!.drawPile, hasLength(64));
      expect(state.decks['specialItems']!.drawPile, hasLength(7));
      expect(state.decks['monsters']!.drawPile, hasLength(41));
      expect(state.decks['restlessReserve']!.drawPile, hasLength(7));
      expect(state.decks['tasks']!.drawPile, hasLength(8));
      expect(state.reserveHeroes, hasLength(4));
      expect(state.players, hasLength(4));
      expect(
        state.players.map((player) => player.characterId).toSet()
          ..addAll(state.reserveHeroes.map((hero) => hero.characterId)),
        fullRuntimeCharacters.map((character) => character['id']).toSet(),
      );
      for (final hero in state.players) {
        _expectStartingCards(hero.characterId, hero.backpack, hero.equipped);
      }
      for (final hero in state.reserveHeroes) {
        _expectStartingCards(hero.characterId, hero.backpack, hero.equipped);
      }
    }
  });

  test('full runtime event definitions survive a save round trip', () {
    final state = createFullGameState(
      characterIds: const ['scientist', 'guard'],
      seed: 21,
    );
    final codec = GameStateJsonCodec();
    final restored = codec.decode(codec.encode(state));

    expect(restored.seed, state.seed);
    expect(restored.turnOrder, state.turnOrder);
    expect(restored.leaderPlayerId, state.leaderPlayerId);
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

String _tileSignature(HexTile tile) {
  final exits = tile.exits.map((edge) => edge.index).toList()..sort();
  return '${tile.id}:${tile.coord.q},${tile.coord.r}:${tile.type.name}:'
      '${tile.opened}:${exits.join(',')}:${tile.hasTerminal}:'
      '${tile.ventColor.name}';
}

List<String> _startingCards(List<String> backpack, EquippedGear equipped) => [
  ...backpack,
  ...equipped.weapons,
  if (equipped.armor != null) equipped.armor!,
  if (equipped.clothing != null) equipped.clothing!,
  if (equipped.robot != null) equipped.robot!,
];

void _expectStartingCards(
  String characterId,
  List<String> backpack,
  EquippedGear equipped,
) {
  final character = fullRuntimeCharacters.singleWhere(
    (row) => row['id'] == characterId,
  );
  expect(
    _startingCards(backpack, equipped),
    unorderedEquals((character['startItems']! as List).cast<String>()),
    reason: characterId,
  );
}

void _expectFullBoard(GameState state) {
  expect(state.board, hasLength(35));
  expect(state.board.where((tile) => tile.opened).map((tile) => tile.id), [
    'anabiosis',
  ]);
  expect(state.board.map((tile) => tile.coord).toSet(), hasLength(35));
  final visited = <HexCoord>{
    state.board.singleWhere((tile) => tile.id == 'anabiosis').coord,
  };
  final pending = <HexCoord>[...visited];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final edge in HexEdge.values) {
      final nextCoord = current.neighbor(edge);
      final next = state.tileAt(nextCoord);
      if (next == null) continue;
      final currentTile = state.tileAt(current)!;
      expect(currentTile.hasExit(edge), next.hasExit(edge.opposite));
      if (currentTile.hasExit(edge) && visited.add(nextCoord)) {
        pending.add(nextCoord);
      }
    }
  }
  expect(visited, hasLength(35));
  for (final corridor in state.board.where(
    (tile) => tile.type == HexTileType.corridor,
  )) {
    final roomNeighbors = HexEdge.values
        .map((edge) => state.tileAt(corridor.coord.neighbor(edge)))
        .whereType<HexTile>()
        .where((tile) => tile.type != HexTileType.corridor)
        .length;
    expect(roomNeighbors, 2, reason: corridor.id);
  }
  for (final room in state.board.where(
    (tile) => tile.type != HexTileType.corridor,
  )) {
    final corridorNeighbors = HexEdge.values
        .map((edge) => state.tileAt(room.coord.neighbor(edge)))
        .whereType<HexTile>()
        .where((tile) => tile.type == HexTileType.corridor)
        .length;
    expect(corridorNeighbors, inInclusiveRange(1, 6), reason: room.id);
  }
}
