// This conditional-imported adapter must access browser-only storage APIs.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:web/web.dart' as web;

const _databaseName = 'besprotoritsa';
const _databaseVersion = 1;
const _storeName = 'game_saves';
const _saveKeyPrefix = 'save.';
const _nameKeyPrefix = 'name.';
const _legacySaveKeyPrefix = 'besprotoritsa.save.';

/// Browser save adapter backed by origin-scoped IndexedDB.
///
/// IndexedDB is asynchronous and is not constrained by the small synchronous
/// quota of LocalStorage. On the first read, a save written by the preceding
/// LocalStorage release is migrated so existing players retain progress.
class WebIndexedDbGameStorage implements GameStorage, SaveSlotMetadataStorage {
  /// Creates browser storage using the supplied [codec].
  WebIndexedDbGameStorage({GameStateJsonCodec? codec})
    : _codec = codec ?? GameStateJsonCodec();

  final GameStateJsonCodec _codec;

  static final Future<web.IDBDatabase> _database = _openDatabase();

  @override
  Future<void> saveGame(String slotId, GameState state) async {
    await _write(_saveKeyFor(slotId), _codec.encode(state));
  }

  @override
  Future<GameState?> loadGame(String slotId) async {
    final document = await _read(
      _saveKeyFor(slotId),
      legacyKey: _legacyKeyFor(slotId),
    );
    return document == null ? null : _codec.decode(document);
  }

  @override
  Future<void> saveSlotName(String slotId, String? name) async {
    if (name == null || name.trim().isEmpty) {
      await _delete(_nameKeyFor(slotId));
    } else {
      await _write(_nameKeyFor(slotId), name.trim());
    }
  }

  @override
  Future<String?> loadSlotName(String slotId) => _read(
    _nameKeyFor(slotId),
    legacyKey: '${_legacyKeyFor(slotId)}.name',
  );

  static Future<web.IDBDatabase> _openDatabase() async {
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    final upgradeSubscription = web.EventStreamProviders.upgradeNeededEvent
        .forTarget(request)
        .listen((_) {
          final database = request.result! as web.IDBDatabase;
          if (!database.objectStoreNames.contains(_storeName)) {
            database.createObjectStore(_storeName);
          }
        });
    try {
      return await _requestResult<web.IDBDatabase>(
        request,
        (result) => result! as web.IDBDatabase,
      );
    } finally {
      await upgradeSubscription.cancel();
    }
  }

  Future<void> _write(String key, String value) async {
    final transaction = await _transaction('readwrite');
    final completed = _transactionCompleted(transaction);
    transaction.objectStore(_storeName).put(value.toJS, key.toJS);
    await completed;
  }

  Future<String?> _read(String key, {String? legacyKey}) async {
    final transaction = await _transaction('readonly');
    final completed = _transactionCompleted(transaction);
    final value = await _requestResult<JSAny?>(
      transaction.objectStore(_storeName).get(key.toJS),
      (result) => result,
    );
    await completed;
    if (value != null) {
      return (value as JSString).toDart;
    }

    final legacyValue = legacyKey == null
        ? null
        : web.window.localStorage.getItem(legacyKey);
    if (legacyValue != null) {
      await _write(key, legacyValue);
    }
    return legacyValue;
  }

  Future<void> _delete(String key) async {
    final transaction = await _transaction('readwrite');
    final completed = _transactionCompleted(transaction);
    transaction.objectStore(_storeName).delete(key.toJS);
    await completed;
  }

  Future<web.IDBTransaction> _transaction(String mode) =>
      // A String is a valid JavaScript IDB transaction mode.
      _database.then((database) => database.transaction(_storeName.toJS, mode));

  static Future<T> _requestResult<T>(
    web.IDBRequest request,
    T Function(JSAny? result) convert,
  ) {
    final completer = Completer<T>();
    late StreamSubscription<web.Event> successSubscription;
    late StreamSubscription<web.Event> errorSubscription;
    successSubscription = web.EventStreamProviders.successEvent
        .forTarget(request)
        .listen((_) {
          if (!completer.isCompleted) {
            completer.complete(convert(request.result));
            unawaited(errorSubscription.cancel());
          }
        });
    errorSubscription = web.EventStreamProviders.errorEvent
        .forTarget(request)
        .listen((_) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('IndexedDB request failed: ${request.error?.message}'),
            );
            unawaited(successSubscription.cancel());
          }
        });
    return completer.future;
  }

  static Future<void> _transactionCompleted(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    late StreamSubscription<web.Event> completeSubscription;
    late StreamSubscription<web.Event> errorSubscription;
    late StreamSubscription<web.Event> abortSubscription;
    completeSubscription = web.EventStreamProviders.completeEvent
        .forTarget(transaction)
        .listen((_) {
          if (!completer.isCompleted) {
            completer.complete();
            unawaited(errorSubscription.cancel());
            unawaited(abortSubscription.cancel());
          }
        });
    void completeError() {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'IndexedDB transaction failed: ${transaction.error?.message}',
          ),
        );
        unawaited(completeSubscription.cancel());
      }
    }

    errorSubscription = web.EventStreamProviders.errorEvent
        .forTarget(transaction)
        .listen((_) => completeError());
    abortSubscription = web.EventStreamProviders.abortEvent
        .forTarget(transaction)
        .listen((_) => completeError());
    return completer.future;
  }

  String _saveKeyFor(String slotId) =>
      '$_saveKeyPrefix${_encodedSlotId(slotId)}';

  String _nameKeyFor(String slotId) =>
      '$_nameKeyPrefix${_encodedSlotId(slotId)}';

  String _legacyKeyFor(String slotId) =>
      '$_legacySaveKeyPrefix${_encodedSlotId(slotId)}';

  String _encodedSlotId(String slotId) =>
      base64Url.encode(utf8.encode(validateGameSlotId(slotId)));
}

/// Selected by the conditional platform import on Web.
GameStorage createGameStorage() => WebIndexedDbGameStorage();
