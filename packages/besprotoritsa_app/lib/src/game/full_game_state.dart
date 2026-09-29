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
  final hexRows = _rows(_content['hexes'], 'hexes');
  final board = const ShipBoardGenerator()
      .generateFullSet(
        seed,
        compartmentIds: [
          for (final row in hexRows)
            if (row['type'] == 'compartment') _string(row, 'id'),
        ],
        airlockIds: [
          for (final row in hexRows)
            if (row['type'] == 'airlock') _string(row, 'id'),
        ],
        corridorVentColors: [
          for (final row in hexRows)
            if (row['type'] == 'corridor')
              for (var copy = 0; copy < _copies(row); copy++)
                VentColor.values.byName(_string(row, 'ventColor')),
        ],
      )
      .tiles
      .map(_concealNonStartTile)
      .toList(growable: false);
  final monsterRows = _cards(_content['monsters']);
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
  final random = Random(seed);
  final restless = monsterRows.singleWhere(
    (row) => row['id'] == 'restless',
  );
  final monsterDeck = _expandedIds(
    monsterRows.where((row) {
      final features = _list(row['features']).cast<String>();
      return row['id'] != 'boil' && !features.contains('boss');
    }),
    copyOverrides: {'restless': _copies(restless) - 7},
  )..shuffle(random);
  final taskIds = _expandedIds(_rows(_content['tasks'], 'tasks'))
    ..shuffle(random);
  var nextTask = 0;
  final personalTasks = <String, List<String>>{
    for (final player in playerStates)
      player.id: [
        taskIds[nextTask++],
        taskIds[nextTask++],
      ],
  };
  final conditionsDeck = _expandedIds(conditionRows)..shuffle(random);
  final eventRows = _cards(_content['events']);
  final eventsDeck = _expandedIds(eventRows)..shuffle(random);
  final itemRows = _cards(_content['items']);
  final supplyRows = [
    ..._cards(_content['supplies']),
    ...itemRows.where((row) => row['sourceDeck'] == 'supplies'),
  ];
  final itemsDeck = _expandedIds(
    itemRows.where((row) => row['sourceDeck'] == 'items'),
  )..shuffle(random);
  final suppliesDeck = _expandedIds(supplyRows)..shuffle(random);
  final specialItemsDeck = _expandedIds(_cards(_content['special_items']))
    ..shuffle(random);
  final restlessReserve = List<String>.filled(7, _string(restless, 'id'));
  final translations = _object(_content['contentTranslations']);
  return GameState(
    seed: seed,
    round: 1,
    phase: GamePhase.playersTurn,
    activePlayerId: playerStates.first.id,
    actionsLeft: 2,
    board: board,
    players: playerStates,
    monsters: const [],
    quests: QuestState(
      storyQuestIds: _strings(
        _object(_content['quests'])['initialQuestIds'],
      ),
      personalTasksByPlayer: personalTasks,
    ),
    decks: {
      'conditions': DeckState(drawPile: conditionsDeck),
      'events': DeckState(drawPile: eventsDeck),
      'items': DeckState(drawPile: itemsDeck),
      'supplies': DeckState(drawPile: suppliesDeck),
      'specialItems': DeckState(drawPile: specialItemsDeck),
      'monsters': DeckState(drawPile: monsterDeck),
      'tasks': DeckState(drawPile: taskIds.skip(nextTask)),
      'restlessReserve': DeckState(drawPile: restlessReserve),
    },
    conditionCards: conditions,
    cardDefinitions: definitions,
    eventDefinitions: {
      for (final row in eventRows)
        _string(row, 'id'): Map<String, Object?>.from(row),
    },
    questDefinitions: {
      for (final row in _rows(_content['quests'], 'quests'))
        _string(row, 'id'): Map<String, Object?>.from(row),
    },
    taskDefinitions: {
      for (final row in _rows(_content['tasks'], 'tasks'))
        _string(row, 'id'): Map<String, Object?>.from(row),
    },
    monsterDefinitions: {
      for (final row in monsterRows)
        _string(row, 'id'): Map<String, Object?>.from(row),
    },
    contentTranslations: {
      for (final entry in translations.entries)
        if (entry.value is String) entry.key: entry.value! as String,
    },
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

List<String> _expandedIds(
  Iterable<Map<String, Object?>> rows, {
  Map<String, int> copyOverrides = const {},
}) => [
  for (final row in rows)
    for (
      var copy = 0;
      copy < (copyOverrides[_string(row, 'id')] ?? _copies(row));
      copy++
    )
      _string(row, 'id'),
];

int _copies(Map<String, Object?> row) {
  final copies = row['copies'] ?? 1;
  if (copies is int && copies > 0) return copies;
  throw FormatException('Invalid copies on ${row['id']}.');
}

HexTile _concealNonStartTile(HexTile tile) => HexTile(
  id: tile.id,
  coord: tile.coord,
  type: tile.type,
  opened: tile.type == HexTileType.start,
  exits: tile.exits,
  locationId: tile.locationId,
  hasTerminal: tile.hasTerminal,
  ventColor: tile.ventColor,
  isBlocked: tile.isBlocked,
);

List<String> _strings(Object? raw) => _list(raw).cast<String>();

int _int(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer.');
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

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}
