import 'dart:convert';

import 'package:besprotoritsa_data/src/game_storage.dart';
import 'package:besprotoritsa_data/src/save_json_models.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Converts every authoritative [GameState] field to and from save JSON.
class GameStateJsonCodec {
  /// Creates a codec that migrates documents before deserializing them.
  GameStateJsonCodec({SaveMigrator? migrator})
    : _migrator = migrator ?? SaveMigrator.standard();

  final SaveMigrator _migrator;

  /// Encodes [state] to a complete JSON document with `schema_version: 1`.
  String encode(GameState state) => jsonEncode(toJson(state));

  /// Decodes and migrates a JSON document into a complete [GameState].
  GameState decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Save document must be a JSON object.');
    }
    return fromJson(Map<String, Object?>.from(decoded));
  }

  /// Serializes [state] into JSON-compatible primitive values and collections.
  Map<String, Object?> toJson(GameState state) => {
    'schema_version': currentSaveSchemaVersion,
    'seed': state.seed,
    'round': state.round,
    'phase': state.phase.name,
    'active_player_id': state.activePlayerId,
    'actions_left': state.actionsLeft,
    'actions_taken_this_turn': state.actionsTakenThisTurn,
    'board': state.board.map(SaveJsonModels.tileToJson).toList(),
    'players': state.players.map(SaveJsonModels.playerToJson).toList(),
    'monsters': state.monsters.map(SaveJsonModels.monsterToJson).toList(),
    'boils': state.boils.map(SaveJsonModels.boilToJson).toList(),
    'condition_cards': {
      for (final entry in state.conditionCards.entries)
        entry.key: SaveJsonModels.conditionToJson(entry.value),
    },
    'pending_damage': state.pendingDamage
        .map(SaveJsonModels.incomingDamageToJson)
        .toList(),
    'decks': {
      for (final entry in state.decks.entries)
        entry.key: SaveJsonModels.deckToJson(entry.value),
    },
    'quests': SaveJsonModels.questsToJson(state.quests),
    'log': state.log,
    'game_events': state.gameEvents.map(SaveJsonModels.eventToJson).toList(),
    'is_complete': state.isComplete,
    'monster_turn_index': state.monsterTurnIndex,
    'monster_steps_remaining': state.monsterStepsRemaining,
    'event_turn_index': state.eventTurnIndex,
    'pending_decision': SaveJsonModels.decisionToJson(state.pendingDecision),
  };

  /// Migrates [document] to the current version and reconstructs its state.
  GameState fromJson(Map<String, Object?> document) {
    final json = _migrator.migrate(document);
    return GameState(
      schemaVersion: _int(json, 'schema_version'),
      seed: _int(json, 'seed'),
      round: _int(json, 'round'),
      phase: SaveJsonModels.gamePhaseFromJson(_string(json, 'phase')),
      activePlayerId: _nullableString(
        json['active_player_id'],
        'active_player_id',
      ),
      actionsLeft: _int(json, 'actions_left'),
      actionsTakenThisTurn: _intOrDefault(json, 'actions_taken_this_turn'),
      board: _objects(json, 'board').map(SaveJsonModels.tileFromJson),
      players: _objects(json, 'players').map(SaveJsonModels.playerFromJson),
      monsters: _objects(json, 'monsters').map(SaveJsonModels.monsterFromJson),
      boils: _objects(json, 'boils').map(SaveJsonModels.boilFromJson),
      conditionCards: _objectMap(json, 'condition_cards').map(
        (id, value) => MapEntry(id, SaveJsonModels.conditionFromJson(value)),
      ),
      pendingDamage: _objects(
        json,
        'pending_damage',
      ).map(SaveJsonModels.incomingDamageFromJson),
      decks: _objectMap(json, 'decks').map(
        (id, value) => MapEntry(id, SaveJsonModels.deckFromJson(value)),
      ),
      quests: SaveJsonModels.questsFromJson(_object(json, 'quests')),
      log: _strings(json, 'log'),
      gameEvents: _objects(
        json,
        'game_events',
      ).map(SaveJsonModels.eventFromJson),
      isComplete: _bool(json, 'is_complete'),
      monsterTurnIndex: _int(json, 'monster_turn_index'),
      monsterStepsRemaining: _int(json, 'monster_steps_remaining'),
      eventTurnIndex: _int(json, 'event_turn_index'),
      pendingDecision: SaveJsonModels.decisionFromJson(
        json['pending_decision'],
      ),
    );
  }
}

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return Map<String, Object?>.from(value);
}

Map<String, Map<String, Object?>> _objectMap(
  Map<String, Object?> json,
  String key,
) {
  final object = _object(json, key);
  return {
    for (final entry in object.entries)
      entry.key: _asObject(entry.value, '$key.${entry.key}'),
  };
}

Iterable<Map<String, Object?>> _objects(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<dynamic>) throw FormatException('$key must be an array.');
  return value.map((entry) => _asObject(entry, key));
}

List<String> _strings(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<dynamic> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  return List<String>.from(value);
}

Map<String, Object?> _asObject(Object? value, String key) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return Map<String, Object?>.from(value);
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int _intOrDefault(
  Map<String, Object?> json,
  String key, {
  int defaultValue = 0,
}) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

String? _nullableString(Object? value, String key) {
  if (value == null || value is String) return value as String?;
  throw FormatException('$key must be a string or null.');
}
