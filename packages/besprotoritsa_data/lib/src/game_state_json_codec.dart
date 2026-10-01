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

  /// Encodes [state] to a complete release-2 JSON document.
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
    'prng_state': state.prngState ?? (state.seed & 0xFFFFFFFF),
    'content_set_id': state.contentSetId,
    'content_set_version': state.contentSetVersion,
    'difficulty': state.difficulty,
    'round': state.round,
    'phase': state.phase.name,
    'active_player_id': state.activePlayerId,
    'actions_left': state.actionsLeft,
    'actions_taken_this_turn': state.actionsTakenThisTurn,
    'board': state.board.map(SaveJsonModels.tileToJson).toList(),
    'players': state.players.map(SaveJsonModels.playerToJson).toList(),
    'monsters': state.monsters.map(SaveJsonModels.monsterToJson).toList(),
    'boils': state.boils.map(SaveJsonModels.boilToJson).toList(),
    'reserve_heroes': state.reserveHeroes
        .map(SaveJsonModels.reserveHeroToJson)
        .toList(),
    'queued_replacements': {
      for (final entry in state.queuedReplacements.entries)
        entry.key: SaveJsonModels.reserveHeroToJson(entry.value),
    },
    'condition_cards': {
      for (final entry in state.conditionCards.entries)
        entry.key: SaveJsonModels.conditionToJson(entry.value),
    },
    'card_definitions': {
      for (final entry in state.cardDefinitions.entries)
        entry.key: SaveJsonModels.cardDefinitionToJson(entry.value),
    },
    'event_definitions': state.eventDefinitions,
    'quest_definitions': state.questDefinitions,
    'task_definitions': state.taskDefinitions,
    'monster_definitions': state.monsterDefinitions,
    'content_translations': state.contentTranslations,
    'pending_damage': state.pendingDamage
        .map(SaveJsonModels.incomingDamageToJson)
        .toList(),
    'chest_cards': state.chestCards,
    'decks': {
      for (final entry in state.decks.entries)
        entry.key: SaveJsonModels.deckToJson(entry.value),
    },
    'quests': SaveJsonModels.questsToJson(state.quests),
    'log': state.log,
    'game_events': state.gameEvents.map(SaveJsonEventModels.toJson).toList(),
    'is_complete': state.isComplete,
    'monster_turn_index': state.monsterTurnIndex,
    'monster_steps_remaining': state.monsterStepsRemaining,
    'event_turn_index': state.eventTurnIndex,
    'pending_decision': SaveJsonModels.decisionToJson(state.pendingDecision),
    'pending_event_monster_spawn':
        SaveJsonModels.pendingEventMonsterSpawnToJson(
          state.pendingEventMonsterSpawn,
        ),
  };

  /// Migrates [document] to the current version and reconstructs its state.
  GameState fromJson(Map<String, Object?> document) {
    final json = _migrator.migrate(document);
    final pendingDecision = _migrateLegacyPendingDecision(
      SaveJsonModels.decisionFromJson(json['pending_decision']),
    );
    return GameState(
      // GameState's schemaVersion describes the rules model, not the save file.
      schemaVersion: 1,
      seed: _int(json, 'seed'),
      prngState: _int(json, 'prng_state'),
      contentSetId: _string(json, 'content_set_id'),
      contentSetVersion: _string(json, 'content_set_version'),
      difficulty: _intOrDefault(json, 'difficulty', defaultValue: 1),
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
      reserveHeroes: _objectsOrDefault(
        json['reserve_heroes'],
        'reserve_heroes',
      ).map(SaveJsonModels.reserveHeroFromJson),
      queuedReplacements:
          _objectMapOrDefault(
            json['queued_replacements'],
            'queued_replacements',
          ).map(
            (playerId, hero) => MapEntry(
              playerId,
              SaveJsonModels.reserveHeroFromJson(hero),
            ),
          ),
      conditionCards: _objectMap(json, 'condition_cards').map(
        (id, value) => MapEntry(id, SaveJsonModels.conditionFromJson(value)),
      ),
      cardDefinitions:
          _objectMapOrDefault(
            json['card_definitions'],
            'card_definitions',
          ).map(
            (id, value) => MapEntry(
              id,
              SaveJsonModels.cardDefinitionFromJson(value),
            ),
          ),
      eventDefinitions:
          _objectMapOrDefault(
            json['event_definitions'],
            'event_definitions',
          ).map(
            (id, value) => MapEntry(id, Map<String, Object?>.from(value)),
          ),
      questDefinitions: _objectMapOrDefault(
        json['quest_definitions'],
        'quest_definitions',
      ),
      taskDefinitions: _objectMapOrDefault(
        json['task_definitions'],
        'task_definitions',
      ),
      monsterDefinitions: _objectMapOrDefault(
        json['monster_definitions'],
        'monster_definitions',
      ),
      contentTranslations: _stringMapOrDefault(
        json['content_translations'],
        'content_translations',
      ),
      pendingDamage: _objects(
        json,
        'pending_damage',
      ).map(SaveJsonModels.incomingDamageFromJson),
      chestCards: _stringsOrDefault(json['chest_cards']),
      decks: _objectMap(json, 'decks').map(
        (id, value) => MapEntry(id, SaveJsonModels.deckFromJson(value)),
      ),
      quests: SaveJsonModels.questsFromJson(_object(json, 'quests')),
      log: _strings(json, 'log'),
      gameEvents: _objects(
        json,
        'game_events',
      ).map(SaveJsonEventModels.fromJson),
      isComplete: _bool(json, 'is_complete'),
      monsterTurnIndex: _int(json, 'monster_turn_index'),
      monsterStepsRemaining: _int(json, 'monster_steps_remaining'),
      eventTurnIndex: _int(json, 'event_turn_index'),
      pendingDecision: pendingDecision,
      pendingEventMonsterSpawn: SaveJsonModels.pendingEventMonsterSpawnFromJson(
        json['pending_event_monster_spawn'],
      ),
    );
  }
}

PendingDecision? _migrateLegacyPendingDecision(PendingDecision? decision) {
  if (decision case AwaitingRerollChoice(
    :final dice,
    :final availableRerolls,
    :final window,
    context: SkillCheckContext(
      :final playerId,
      :final stat,
      :final difficulty,
      eventId: 'cabin-noise',
      eventBehaviorId: null,
      :final eventOptionIndex,
      :final questId,
    ),
    :final maxDicePerReroll,
  )) {
    // Version 1 saves written before event behavior IDs were persisted can
    // resume this released event without its data-driven behavior identifier.
    return AwaitingRerollChoice(
      dice: dice,
      availableRerolls: availableRerolls,
      window: window,
      maxDicePerReroll: maxDicePerReroll,
      context: SkillCheckContext(
        playerId: playerId,
        stat: stat,
        difficulty: difficulty,
        eventId: 'cabin-noise',
        eventBehaviorId: 'event_cabin_noise',
        eventOptionIndex: eventOptionIndex,
        questId: questId,
      ),
    );
  }
  return decision;
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

Iterable<Map<String, Object?>> _objectsOrDefault(Object? value, String key) {
  if (value == null) return const [];
  if (value is! List<dynamic>) throw FormatException('$key must be an array.');
  return value.map((entry) => _asObject(entry, key));
}

Map<String, Map<String, Object?>> _objectMapOrDefault(
  Object? value,
  String key,
) {
  if (value == null) return const {};
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return {
    for (final entry in value.entries) entry.key: _asObject(entry.value, key),
  };
}

Map<String, String> _stringMapOrDefault(Object? value, String key) {
  if (value == null) return const {};
  if (value is! Map<String, dynamic> ||
      value.values.any((entry) => entry is! String)) {
    throw FormatException('$key must map strings to strings.');
  }
  return value.cast<String, String>();
}

List<String> _strings(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<dynamic> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  return List<String>.from(value);
}

List<String> _stringsOrDefault(Object? value) {
  if (value == null) return const [];
  if (value is! List<dynamic> || value.any((entry) => entry is! String)) {
    throw const FormatException('chest_cards must be an array of strings.');
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
