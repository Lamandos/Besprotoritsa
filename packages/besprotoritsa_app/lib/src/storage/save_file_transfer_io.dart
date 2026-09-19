import 'dart:io';

/// Uses a temporary sibling and rename, so an interrupted export never leaves
/// a partly-written destination file.
Future<void> writeSaveExportFile(String path, String document) async {
  final target = File(path);
  await target.parent.create(recursive: true);
  final temporary = File(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    await temporary.writeAsString(document, flush: true);
    await temporary.rename(target.path);
  } finally {
    // Cleanup stays asynchronous so a large export does not block the UI.
    // ignore: avoid_slow_async_io
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Reads a selected JSON file as text for validation by the save system.
Future<String> readSaveImportFile(String path) => File(path).readAsString();
