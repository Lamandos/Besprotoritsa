import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:path_provider/path_provider.dart';

/// File-backed saves for Android and macOS application support directories.
class FileGameStorage implements GameStorage, SaveSlotMetadataStorage {
  /// Creates file storage using the supplied [codec].
  FileGameStorage({
    GameStateJsonCodec? codec,
    Future<Directory> Function()? directoryProvider,
  }) : _codec = codec ?? GameStateJsonCodec(),
       _directoryProvider = directoryProvider ?? _defaultDirectory;

  final GameStateJsonCodec _codec;
  final Future<Directory> Function() _directoryProvider;

  @override
  Future<void> saveGame(String slotId, GameState state) async {
    final file = await _fileFor(slotId);
    await _writeAtomically(file, _codec.encode(state));
  }

  @override
  Future<GameState?> loadGame(String slotId) async {
    final file = await _fileFor(slotId);
    // Disk existence checks remain asynchronous for the same UI safety reason.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return null;
    return _codec.decode(await file.readAsString());
  }

  @override
  Future<void> saveSlotName(String slotId, String? name) async {
    final names = await _loadNames();
    final validatedSlotId = validateGameSlotId(slotId);
    if (name == null || name.trim().isEmpty) {
      names.remove(validatedSlotId);
    } else {
      names[validatedSlotId] = name.trim();
    }
    await _writeAtomically(await _metadataFile(), jsonEncode(names));
  }

  @override
  Future<String?> loadSlotName(String slotId) async =>
      (await _loadNames())[validateGameSlotId(slotId)];

  Future<File> _fileFor(String slotId) async {
    final safeSlot = base64Url.encode(utf8.encode(validateGameSlotId(slotId)));
    final directory = await _saveDirectory();
    return File('${directory.path}${Platform.pathSeparator}$safeSlot.json');
  }

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}game_saves');
  }

  Future<Directory> _saveDirectory() async {
    final directory = await _directoryProvider();
    // Directory checks remain asynchronous for the same UI safety reason.
    // ignore: avoid_slow_async_io
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _metadataFile() async {
    final directory = await _saveDirectory();
    return File('${directory.path}${Platform.pathSeparator}slot_names.json');
  }

  Future<Map<String, String>> _loadNames() async {
    final file = await _metadataFile();
    // Metadata existence checks remain asynchronous for UI safety.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return <String, String>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded.values.any((value) => value is! String)) {
      throw const FormatException('Save slot names must be a JSON object.');
    }
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  /// Writes a complete temporary sibling first, so an interrupted write leaves
  /// the previous save intact. Renaming a sibling is atomic on supported app
  /// storage filesystems.
  Future<void> _writeAtomically(File target, String contents) async {
    final temporary = File(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(target.path);
    } finally {
      // Cleanup is asynchronous to keep file operations off the UI isolate.
      // ignore: avoid_slow_async_io
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

/// Selected by the conditional platform import on Android and macOS.
GameStorage createGameStorage() => FileGameStorage();
