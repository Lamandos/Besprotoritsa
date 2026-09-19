/// Reports that file exports are not available on this platform.
Future<void> writeSaveExportFile(String path, String document) =>
    Future<void>.error(
      UnsupportedError(
        'File import and export are unavailable on this platform.',
      ),
    );

/// Reports that file imports are not available on this platform.
Future<String> readSaveImportFile(String path) => Future<String>.error(
  UnsupportedError('File import and export are unavailable on this platform.'),
);
