import 'package:besprotoritsa_app/src/storage/save_file_transfer_stub.dart'
    if (dart.library.io) 'package:besprotoritsa_app/src/storage/save_file_transfer_io.dart';

/// Writes an exported JSON save to [path].
Future<void> writeSaveExport(String path, String document) =>
    writeSaveExportFile(path, document);

/// Reads an imported JSON save from [path].
Future<String> readSaveImport(String path) => readSaveImportFile(path);
