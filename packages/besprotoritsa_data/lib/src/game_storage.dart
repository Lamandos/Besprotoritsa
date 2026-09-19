import 'package:besprotoritsa_data/src/game_state_json_codec.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// The current on-disk document schema version.
const currentSaveSchemaVersion = 1;

/// Persists complete, authoritative game snapshots in named slots.
abstract interface class GameStorage {
  /// Replaces the snapshot saved under [slotId].
  Future<void> saveGame(String slotId, GameState state);

  /// Returns the snapshot in [slotId], or null when the slot is empty.
  Future<GameState?> loadGame(String slotId);
}

/// Optional capability for storage backends that persist player-facing slot
/// names alongside their game snapshots.
///
/// Keeping this separate from [GameStorage] preserves compatibility with hosts
/// that only need to persist a game state.
abstract interface class SaveSlotMetadataStorage {
  /// Stores a nullable display name for [slotId]. A null name clears it.
  Future<void> saveSlotName(String slotId, String? name);

  /// Reads the player-provided display name for [slotId], if one exists.
  Future<String?> loadSlotName(String slotId);
}

/// A single transformation from one save schema version to the next.
typedef SaveMigration =
    Map<String, Object?> Function(
      Map<String, Object?> document,
    );

/// Migrates persisted documents through registered, adjacent schema versions.
class SaveMigrator {
  /// Creates a migration registry ending at [currentVersion].
  SaveMigrator({
    required this.currentVersion,
    Map<int, SaveMigration> migrations = const {},
  }) : _migrations = Map.unmodifiable(migrations);

  /// The migration registry for schema version 1.
  factory SaveMigrator.standard() => SaveMigrator(
    currentVersion: currentSaveSchemaVersion,
    migrations: {0: _migrateVersionZero},
  );

  /// Target schema version expected by the current client.
  final int currentVersion;
  final Map<int, SaveMigration> _migrations;

  /// Produces a copy of [document] expressed in [currentVersion].
  Map<String, Object?> migrate(Map<String, Object?> document) {
    var migrated = Map<String, Object?>.of(document);
    var version = _readVersion(migrated);
    if (version > currentVersion) {
      throw UnsupportedError(
        'Save schema version $version is newer than supported.',
      );
    }
    while (version < currentVersion) {
      final migration = _migrations[version];
      if (migration == null) {
        throw UnsupportedError(
          'No migration registered for save schema $version.',
        );
      }
      migrated = migration(migrated);
      final nextVersion = _readVersion(migrated);
      if (nextVersion <= version) {
        throw StateError(
          'Migration from schema $version did not advance version.',
        );
      }
      version = nextVersion;
    }
    return migrated;
  }

  static int _readVersion(Map<String, Object?> document) {
    final version = document['schema_version'];
    if (version == null) return 0;
    if (version is! int || version < 0) {
      throw const FormatException(
        'schema_version must be a non-negative integer.',
      );
    }
    return version;
  }
}

Map<String, Object?> _migrateVersionZero(Map<String, Object?> document) {
  final migrated = Map<String, Object?>.of(document);
  final legacyVersion = migrated.remove('schemaVersion');
  if (legacyVersion != null && legacyVersion is! int) {
    throw const FormatException('Legacy schemaVersion must be an integer.');
  }
  migrated['schema_version'] = currentSaveSchemaVersion;
  return migrated;
}

/// A storage implementation useful for tests and hosts with their own backend.
class InMemoryGameStorage implements GameStorage, SaveSlotMetadataStorage {
  /// Creates an empty memory-backed storage using [codec].
  InMemoryGameStorage({GameStateJsonCodec? codec})
    : _codec = codec ?? GameStateJsonCodec();

  final GameStateJsonCodec _codec;
  final Map<String, String> _documents = <String, String>{};
  final Map<String, String> _slotNames = <String, String>{};

  @override
  Future<void> saveGame(String slotId, GameState state) async {
    _documents[_validateSlotId(slotId)] = _codec.encode(state);
  }

  @override
  Future<GameState?> loadGame(String slotId) async {
    final document = _documents[_validateSlotId(slotId)];
    return document == null ? null : _codec.decode(document);
  }

  @override
  Future<void> saveSlotName(String slotId, String? name) async {
    final validatedSlotId = _validateSlotId(slotId);
    if (name == null || name.trim().isEmpty) {
      _slotNames.remove(validatedSlotId);
    } else {
      _slotNames[validatedSlotId] = name.trim();
    }
  }

  @override
  Future<String?> loadSlotName(String slotId) async =>
      _slotNames[_validateSlotId(slotId)];

  /// Exposes the exact JSON document for persistence adapter tests.
  String? encodedSlot(String slotId) => _documents[_validateSlotId(slotId)];
}

/// Rejects empty slot identifiers before adapters derive a storage key or path.
String validateGameSlotId(String slotId) => _validateSlotId(slotId);

String _validateSlotId(String slotId) {
  if (slotId.trim().isEmpty) {
    throw ArgumentError.value(slotId, 'slotId', 'Slot id must not be empty.');
  }
  return slotId;
}
