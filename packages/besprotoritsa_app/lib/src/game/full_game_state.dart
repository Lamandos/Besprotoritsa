import 'dart:convert';
import 'dart:math';

import 'package:besprotoritsa_app/src/game/full_runtime_content.g.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// The character records offered by the checked full runtime set.
List<Map<String, Object?>> get fullRuntimeCharacters =>
    _rows(_content['characters'], 'characters');

/// Returns the Russian name recorded for a full-set character.
String fullRuntimeCharacterName(String id) {
  final names = _object(_content['characterNames']);
  final character = names[id];
  if (character is Map<String, dynamic> && character['name'] is String) {
    return character['name'] as String;
  }
  return id;
}

/// Builds a deterministic new game using card and character facts from the
/// checked full runtime snapshot. The seed controls deck order and board.
GameState createFullGameState({
  required List<String> characterIds,
  int seed = 1,
}) {
  if (characterIds.length < 2 ||
      characterIds.length > 4 ||
      characterIds.toSet().length != characterIds.length) {
    throw ArgumentError.value(
      characterIds,
      'characterIds',
      'Expected 2..4 distinct characters.',
    );
  }
  final characters = {
    for (final row in fullRuntimeCharacters) _string(row, 'id'): row,
  };
  final definitions = _allCards();
  final playerStates = List<PlayerState>.generate(characterIds.length, (index) {
    final character = characters[characterIds[index]];
    if (character == null) {
      throw ArgumentError.value(
        characterIds[index],
        'characterIds',
        'Unknown full-set character.',
      );
    }
    final backpack = <String>[];
    String? weapon;
    String? robot;
    for (final id in _strings(character['startItems'])) {
      final definition = definitions[id];
      if (definition == null) {
        throw StateError('Missing starter card "$id" in full runtime set.');
      }
      if (definition.slots.contains(ItemSlot.weapon) && weapon == null) {
        weapon = id;
      } else if (definition.slots.contains(ItemSlot.robot) && robot == null) {
        robot = id;
      } else {
        backpack.add(id);
      }
    }
    return PlayerState(
      id: 'hero-${index + 1}',
      characterId: characterIds[index],
      coord: const HexCoord(0, 0),
      damage: 0,
      health: _int(character, 'health'),
      credits: _int(character, 'startCredits'),
      backpack: backpack,
      equipped: EquippedGear(weapon: weapon, robot: robot),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: true,
      stats: PlayerStats(
        strength: _int(character, 'strength'),
        combatStrength: _int(character, 'combatStrength'),
        science: _int(character, 'science'),
        repair: _int(character, 'repair'),
        endurance: _int(character, 'endurance'),
        agility: _int(character, 'agility'),
      ),
    );
  });
  final board = const ShipBoardGenerator().generate(seed).tiles;
  final monsterRows = _cards(_content['monsters']);
  final firstMonster = monsterRows.first;
  final conditionRows = _cards(_content['conditions']);
  final conditions = <String, ConditionCard>{
    for (final row in conditionRows)
      _string(row, 'id'): ConditionCard(
        id: _string(row, 'id'),
        statModifiers: {
          for (final entry in _object(row['statModifiers']).entries)
            StatType.values.byName(entry.key): entry.value! as int,
        },
      ),
  };
  final decks = _object(_content['decks']);
  final random = Random(seed);
  return GameState(
    seed: seed,
    round: 1,
    phase: GamePhase.playersTurn,
    activePlayerId: playerStates.first.id,
    actionsLeft: 2,
    board: board,
    players: playerStates,
    monsters: [
      MonsterInstance(
        instanceId: '${_string(firstMonster, 'id')}-1',
        monsterId: _string(firstMonster, 'id'),
        coord: const HexCoord(0, 1),
        damage: 0,
        health: _int(firstMonster, 'health'),
        attack: _int(firstMonster, 'attack'),
      ),
    ],
    decks: {
      'conditions': DeckState(drawPile: _shuffled(decks['conditions'], random)),
      'events': DeckState(drawPile: _shuffled(decks['events'], random)),
    },
    conditionCards: conditions,
    cardDefinitions: definitions,
    quests: QuestState(storyQuestIds: _strings(decks['storyQuests'])),
  );
}

final Map<String, Object?> _content = Map<String, Object?>.from(
  jsonDecode(fullRuntimeContentJson) as Map<String, dynamic>,
);

Map<String, CardDefinition> _allCards() {
  final cards = <String, CardDefinition>{};
  for (final catalogName in ['items', 'special_items']) {
    for (final row in _list(
      _object(_content[catalogName])['cards'],
    ).map(_object)) {
      final definition = CardDefinition.fromJson(row);
      cards[definition.id] = definition;
    }
  }
  for (final row in _list(
    _object(_content['supplies'])['cards'],
  ).map(_object)) {
    final supply = <String, Object?>{
      ...row,
      'category': 'supply',
      'slots': const <String>[],
      'stats': row['stats'] ?? const <String, int>{},
    };
    final definition = CardDefinition.fromJson(supply);
    cards[definition.id] = definition;
  }
  return cards;
}

List<Map<String, Object?>> _cards(Object? raw) =>
    _list(_object(raw)['cards']).map(_object).toList(growable: false);

List<String> _shuffled(Object? raw, Random random) {
  final cards = _strings(raw).toList()..shuffle(random);
  return cards;
}

List<Map<String, Object?>> _rows(Object? raw, String key) =>
    _list(_object(raw)[key]).map(_object).toList(growable: false);

Map<String, Object?> _object(Object? raw) {
  if (raw is Map<String, dynamic>) return Map<String, Object?>.from(raw);
  throw const FormatException('Expected content object.');
}

List<Object?> _list(Object? raw) {
  if (raw is List<Object?>) return raw;
  throw const FormatException('Expected content array.');
}

List<String> _strings(Object? raw) => _list(raw).cast<String>();

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}

int _int(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer.');
}
