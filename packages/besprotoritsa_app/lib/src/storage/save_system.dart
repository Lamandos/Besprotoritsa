import 'package:besprotoritsa_app/src/storage/save_file_transfer.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// The fixed player-visible save slots. Autosave is deliberately separate from
/// the five manual slots, so it never overwrites a player checkpoint.
abstract final class SaveSlots {
  /// Identifier for the rolling recovery snapshot.
  static const String autosave = 'autosave';

  /// The five independent player-controlled checkpoint identifiers.
  static const List<String> manual = <String>[
    'slot-1',
    'slot-2',
    'slot-3',
    'slot-4',
    'slot-5',
  ];

  /// All supported slots, including the autosave.
  static const List<String> all = <String>[autosave, ...manual];

  /// Whether [slotId] can be explicitly named and overwritten by a player.
  static bool isManual(String slotId) => manual.contains(slotId);
}

/// A validated entrypoint for named slots and JSON backup interchange.
///
/// [GameStateJsonCodec.decode] invokes [SaveMigrator], validates
/// `schema_version`, and rebuilds [GameState], whose constructors validate
/// cross-object references before imported data is ever persisted.
class SaveSystem {
  /// Creates a save-system facade around an application storage backend.
  SaveSystem({required GameStorage storage, GameStateJsonCodec? codec})
    : _storage = storage,
      _codec = codec ?? GameStateJsonCodec();

  final GameStorage _storage;
  final GameStateJsonCodec _codec;
  final Map<String, String> _volatileNames = <String, String>{};

  /// Stores the rolling recovery snapshot. The autosave cannot be named.
  Future<void> autosave(GameState state) => _storage.saveGame(
    SaveSlots.autosave,
    state,
  );

  /// Stores a manual snapshot in one of the five independent slots.
  Future<void> saveManual(
    String slotId,
    GameState state, {
    String? name,
  }) async {
    _requireManualSlot(slotId);
    await _storage.saveGame(slotId, state);
    await _saveName(slotId, name);
  }

  /// Returns a validated snapshot, or null for an empty known slot.
  Future<GameState?> load(String slotId) async {
    _requireKnownSlot(slotId);
    return _storage.loadGame(slotId);
  }

  /// Reads the optional player-assigned display name.
  Future<String?> loadName(String slotId) async {
    _requireKnownSlot(slotId);
    if (_storage case final SaveSlotMetadataStorage storage) {
      return storage.loadSlotName(slotId);
    }
    return _volatileNames[slotId];
  }

  /// Exports exactly the authoritative game document from a saved slot.
  Future<String> exportSlot(String slotId) async {
    final state = await load(slotId);
    if (state == null) {
      throw StateError('Cannot export an empty save slot: $slotId.');
    }
    return _codec.encode(state);
  }

  /// Exports a slot as a text JSON file suitable for device transfer.
  Future<void> exportSlotToFile(String slotId, String path) async {
    await writeSaveExport(path, await exportSlot(slotId));
  }

  /// Validates, migrates and stores an imported JSON document.
  Future<GameState> importDocument(
    String slotId,
    String document, {
    String? name,
  }) async {
    _requireManualSlot(slotId);
    final state = _codec.decode(document);
    _validateReferences(state);
    await _storage.saveGame(slotId, state);
    await _saveName(slotId, name);
    return state;
  }

  /// Reads, validates and imports a JSON save file.
  Future<GameState> importFile(
    String slotId,
    String path, {
    String? name,
  }) async => importDocument(slotId, await readSaveImport(path), name: name);

  Future<void> _saveName(String slotId, String? name) async {
    if (_storage case final SaveSlotMetadataStorage storage) {
      await storage.saveSlotName(slotId, name);
      return;
    }
    if (name == null || name.trim().isEmpty) {
      _volatileNames.remove(slotId);
    } else {
      _volatileNames[slotId] = name.trim();
    }
  }

  void _requireKnownSlot(String slotId) {
    if (!SaveSlots.all.contains(slotId)) {
      throw ArgumentError.value(slotId, 'slotId', 'Unknown save slot.');
    }
  }

  void _requireManualSlot(String slotId) {
    if (!SaveSlots.isManual(slotId)) {
      throw ArgumentError.value(
        slotId,
        'slotId',
        'Expected a manual save slot.',
      );
    }
  }

  /// Rejects links that are valid JSON but do not resolve within this snapshot.
  /// The rules-state constructor covers its own invariants; this layer checks
  /// references carried by deferred decisions, damage and the event log.
  void _validateReferences(GameState state) {
    final playerIds = state.players.map((player) => player.id).toSet();
    final monsterIds = state.monsters
        .map((monster) => monster.instanceId)
        .toSet();
    final conditionIds = state.conditionCards.keys.toSet();
    final boardCoordinates = state.board.map((tile) => tile.coord).toSet();

    void requirePlayer(String? playerId, String field) {
      if (playerId != null && !playerIds.contains(playerId)) {
        throw FormatException('$field references unknown player "$playerId".');
      }
    }

    void requireMonster(String monsterId, String field) {
      if (!monsterIds.contains(monsterId)) {
        throw FormatException(
          '$field references unknown monster "$monsterId".',
        );
      }
    }

    for (final player in state.players) {
      if (!boardCoordinates.contains(player.coord)) {
        throw FormatException('Player "${player.id}" is outside the board.');
      }
      for (final conditionId in player.conditions) {
        if (!conditionIds.contains(conditionId)) {
          throw FormatException(
            'Player "${player.id}" references unknown condition '
            '"$conditionId".',
          );
        }
      }
    }
    for (final monster in state.monsters) {
      if (!boardCoordinates.contains(monster.coord)) {
        throw FormatException(
          'Monster "${monster.instanceId}" is outside the board.',
        );
      }
    }
    for (final damage in state.pendingDamage) {
      requirePlayer(damage.targetPlayerId, 'pending_damage.target_player_id');
    }
    for (final entry in state.quests.personalTasksByPlayer.entries) {
      requirePlayer(entry.key, 'quests.personal_tasks_by_player');
    }
    switch (state.pendingDecision) {
      case AwaitingRerollChoice(:final context):
        switch (context) {
          case SkillCheckContext(:final playerId):
            requirePlayer(playerId, 'pending_decision.context.player_id');
          case AttackRollContext(:final playerId, :final targetInstanceId):
            requirePlayer(playerId, 'pending_decision.context.player_id');
            requireMonster(
              targetInstanceId,
              'pending_decision.context.target_instance_id',
            );
          case null:
            break;
        }
      case AwaitingDodge(:final targetPlayerId):
        requirePlayer(targetPlayerId, 'pending_decision.target_player_id');
      case AwaitingEventOption(:final playerId):
        requirePlayer(playerId, 'pending_decision.player_id');
      case AwaitingTerminalPick(:final playerId):
        requirePlayer(playerId, 'pending_decision.player_id');
      case AwaitingHeroReplacement(:final playerId):
        requirePlayer(playerId, 'pending_decision.player_id');
      case null:
        break;
    }
    for (final event in state.gameEvents) {
      switch (event) {
        case HexEntered(:final playerId):
        case ColocationTriggered(:final playerId):
        case DamageDealt(:final playerId):
        case ConditionDrawn(:final playerId):
        case MvpDemonstrationCompleted(:final playerId):
          requirePlayer(playerId, 'game_events.player_id');
        case HeroDied(:final playerId, :final restlessInstanceId):
          requirePlayer(playerId, 'game_events.player_id');
          requireMonster(
            restlessInstanceId,
            'game_events.restless_instance_id',
          );
      }
    }
  }
}
