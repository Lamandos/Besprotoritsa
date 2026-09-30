import 'dart:convert';

import 'package:besprotoritsa_app/src/game/mvp_runtime_content.g.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Creates the compact, deterministic scenario shown by the MVP game screen.
///
/// Runtime entities and card facts come from the checked JSON files under
/// `content/mvp`; only the fixed scenario arrangement is defined here.
GameState createMvpGameState({List<String>? characterIds}) {
  final content = _mvpContent;
  final roster = characterIds ?? const ['engineer', 'guard'];
  if (roster.length < 2 || roster.length > 4) {
    throw ArgumentError.value(
      characterIds,
      'characterIds',
      'Expected 2..4 heroes.',
    );
  }
  final characters = <String, Map<String, Object?>>{
    ..._byId(content['catalogCharacters']),
    ..._byId(content['characters']),
  };
  final items = _byId(content['items']);
  final players = List<PlayerState>.generate(roster.length, (index) {
    final isDefaultRoster =
        roster.length == 2 && roster[0] == 'engineer' && roster[1] == 'guard';
    final playerId = isDefaultRoster
        ? (index == 0 ? 'ada' : 'boris')
        : 'hero-${index + 1}';
    return _player(
      playerId,
      roster[index],
      characters,
      items,
      equipStartingItem: true,
    );
  });
  final hexes = _byId(content['hexes']);
  final layout = _map(content['layout']);
  final coordinates = _list(layout['coordinates']);
  final board = coordinates.map((raw) {
    final position = _map(raw);
    final id = _string(position, 'hexId');
    final definition = hexes[id];
    if (definition == null) throw StateError('Unknown runtime hex "$id".');
    return HexTile(
      id: id,
      coord: HexCoord(_int(position, 'q'), _int(position, 'r')),
      type: HexTileType.values.byName(_string(definition, 'type')),
      opened: id == 'anabiosis',
      exits: _list(
        definition['exits'],
      ).map((edge) => HexEdge.values[edge! as int]).toSet(),
      locationId: definition['type'] == 'compartment' ? id : null,
      hasTerminal: definition['hasTerminal'] == true,
      ventColor: VentColor.values.byName(_string(definition, 'ventColor')),
    );
  });
  final monsters = _byId(content['monsters']);
  final ghoul = monsters['ghoul'];
  if (ghoul == null) throw StateError('MVP content has no ghoul.');
  final conditionRows = _byId(content['conditions']);
  final conditionCards = <CardId, ConditionCard>{
    for (final entry in conditionRows.entries)
      entry.key: ConditionCard(
        id: entry.key,
        statModifiers: {
          for (final modifier in _map(entry.value['statModifiers']).entries)
            StatType.values.byName(modifier.key): modifier.value! as int,
        },
      ),
  };
  final deckOrder = _map(content['decks']);
  return GameState(
    seed: 17,
    round: 1,
    phase: GamePhase.playersTurn,
    activePlayerId: players.first.id,
    actionsLeft: 2,
    board: board,
    players: players,
    monsters: [
      MonsterInstance(
        instanceId: 'ghoul-1',
        monsterId: 'ghoul',
        coord: const HexCoord(0, 1),
        damage: 0,
        health: _int(ghoul, 'health'),
        attack: _int(ghoul, 'attack'),
      ),
    ],
    decks: {
      'conditions': DeckState(
        drawPile: _strings(deckOrder['conditions']),
      ),
      'events': DeckState(drawPile: _strings(deckOrder['events'])),
    },
    conditionCards: conditionCards,
    cardDefinitions: {
      for (final entry in items.entries)
        entry.key: CardDefinition.fromJson(entry.value),
    },
    eventDefinitions: _byId(content['events']),
    quests: QuestState(
      storyQuestIds: _strings(deckOrder['storyQuests']),
    ),
  );
}

PlayerState _player(
  String id,
  String characterId,
  Map<String, Map<String, Object?>> characters,
  Map<String, Map<String, Object?>> items, {
  required bool equipStartingItem,
}) {
  final character = characters[characterId];
  if (character == null) {
    throw ArgumentError.value(characterId, 'characterId', 'Unknown MVP hero.');
  }
  final startItems = _strings(character['startItems']);
  String? weapon;
  String? robot;
  final backpack = <CardId>[];
  for (final itemId in startItems) {
    final item = items[itemId];
    if (item == null) {
      backpack.add(itemId);
      continue;
    }
    final slots = _strings(item['slots']);
    if (equipStartingItem && slots.contains('weapon')) {
      weapon = itemId;
    } else if (equipStartingItem && slots.contains('robot')) {
      robot = itemId;
    } else {
      backpack.add(itemId);
    }
  }
  return PlayerState(
    id: id,
    characterId: characterId,
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
}

final Map<String, Object?> _mvpContent = Map<String, Object?>.from(
  jsonDecode(mvpRuntimeContentJson) as Map<String, dynamic>,
);

Map<String, Map<String, Object?>> _byId(Object? raw) => {
  for (final row in _list(raw).map(_map)) _string(row, 'id'): row,
};

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, dynamic>) return Map<String, Object?>.from(value);
  throw const FormatException('Expected content object.');
}

List<Object?> _list(Object? value) {
  if (value is List<Object?>) return value;
  throw const FormatException('Expected content array.');
}

List<String> _strings(Object? value) => _list(value).cast<String>();

String _string(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is String) return result;
  throw FormatException('$key must be a string.');
}

int _int(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is int) return result;
  throw FormatException('$key must be an integer.');
}
