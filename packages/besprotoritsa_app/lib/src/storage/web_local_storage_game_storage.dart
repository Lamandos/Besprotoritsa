// This conditional-imported adapter must access the browser LocalStorage API.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

const _saveKeyPrefix = 'besprotoritsa.save.';

/// Browser save adapter backed by the origin-scoped LocalStorage database.
class WebLocalStorageGameStorage
    implements GameStorage, SaveSlotMetadataStorage {
  /// Creates browser storage using the supplied [codec].
  WebLocalStorageGameStorage({GameStateJsonCodec? codec})
    : _codec = codec ?? GameStateJsonCodec();

  final GameStateJsonCodec _codec;

  @override
  Future<void> saveGame(String slotId, GameState state) async {
    html.window.localStorage[_keyFor(slotId)] = _codec.encode(state);
  }

  @override
  Future<GameState?> loadGame(String slotId) async {
    final document = html.window.localStorage[_keyFor(slotId)];
    return document == null ? null : _codec.decode(document);
  }

  @override
  Future<void> saveSlotName(String slotId, String? name) async {
    final key = '${_keyFor(slotId)}.name';
    if (name == null || name.trim().isEmpty) {
      html.window.localStorage.remove(key);
    } else {
      html.window.localStorage[key] = name.trim();
    }
  }

  @override
  Future<String?> loadSlotName(String slotId) async =>
      html.window.localStorage['${_keyFor(slotId)}.name'];

  String _keyFor(String slotId) =>
      '$_saveKeyPrefix'
      '${base64Url.encode(utf8.encode(validateGameSlotId(slotId)))}';
}

/// Selected by the conditional platform import on Web.
GameStorage createGameStorage() => WebLocalStorageGameStorage();
