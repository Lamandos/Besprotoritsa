import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:path_provider/path_provider.dart';

/// File-backed saves for Android and macOS application support directories.
class FileGameStorage implements GameStorage {
  /// Creates file storage using the supplied [codec].
  FileGameStorage({GameStateJsonCodec? codec})
    : _codec = codec ?? GameStateJsonCodec();

  final GameStateJsonCodec _codec;

  @override
  Future<void> saveGame(String slotId, GameState state) async {
    final file = await _fileFor(slotId);
    // Disk writes must remain asynchronous to avoid blocking the Flutter UI.
    // ignore: avoid_slow_async_io
    await file.writeAsString(_codec.encode(state), flush: true);
  }

  @override
  Future<GameState?> loadGame(String slotId) async {
    final file = await _fileFor(slotId);
    // Disk existence checks remain asynchronous for the same UI safety reason.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return null;
    return _codec.decode(await file.readAsString());
  }

  Future<File> _fileFor(String slotId) async {
    final safeSlot = base64Url.encode(utf8.encode(validateGameSlotId(slotId)));
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}game_saves',
    );
    // Directory checks remain asynchronous for the same UI safety reason.
    // ignore: avoid_slow_async_io
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$safeSlot.json');
  }
}

/// Selected by the conditional platform import on Android and macOS.
GameStorage createGameStorage() => FileGameStorage();
