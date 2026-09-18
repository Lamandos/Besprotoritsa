import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _expectedPdfCount = 13;

Future<void> main() async {
  final repository = Directory.current;
  final materialsDirectory = Directory('${repository.path}/materials');

  if (!materialsDirectory.existsSync()) {
    throw StateError(
      'Materials directory not found: ${materialsDirectory.path}',
    );
  }

  final files = _findPdfFiles(materialsDirectory);
  if (files.length != _expectedPdfCount) {
    throw StateError(
      'Expected $_expectedPdfCount PDF files in materials/, found ${files.length}.',
    );
  }

  final entries = await Future.wait(files.map(_buildManifestEntry));
  entries.sort((left, right) => left.path.compareTo(right.path));

  final output = File('${repository.path}/content/manifest.json');
  _writeAtomically(output, _encodeManifest(entries));
  stdout.writeln('Generated ${output.path} with ${entries.length} entries.');
}

List<File> _findPdfFiles(Directory directory) {
  return directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.pdf'))
      .toList();
}

Future<_ManifestEntry> _buildManifestEntry(File file) async {
  final stat = file.statSync();
  final digest = await sha256.bind(file.openRead()).first;
  final pageCount = await _readPdfPageCount(file);

  return _ManifestEntry(
    path: 'materials/${file.uri.pathSegments.last}',
    sha256: digest.toString(),
    sizeBytes: stat.size,
    pageCount: pageCount,
  );
}

Future<int> _readPdfPageCount(File file) async {
  final result = await Process.run('pdfinfo', <String>[file.path]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'pdfinfo',
      <String>[file.path],
      result.stderr.toString(),
      result.exitCode,
    );
  }

  final match = RegExp(
    r'^Pages:\s*(\d+)\s*$',
    multiLine: true,
  ).firstMatch(result.stdout.toString());
  final pageCount = match == null ? null : int.tryParse(match.group(1)!);

  if (pageCount == null || pageCount < 1) {
    throw StateError('Could not determine the page count for ${file.path}.');
  }

  return pageCount;
}

String _encodeManifest(List<_ManifestEntry> entries) {
  const encoder = JsonEncoder.withIndent('  ');

  return '${encoder.convert(<String, Object>{
    'files': entries.map((entry) => entry.toJson()).toList(),
  })}\n';
}

void _writeAtomically(File destination, String contents) {
  destination.parent.createSync(recursive: true);
  final temporary = File(
    '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  )..createSync();

  try {
    temporary
      ..writeAsStringSync(contents, flush: true)
      ..renameSync(destination.path);
  } on Object {
    if (temporary.existsSync()) {
      temporary.deleteSync();
    }
    rethrow;
  }
}

final class _ManifestEntry {
  const _ManifestEntry({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.pageCount,
  });

  final String path;
  final String sha256;
  final int sizeBytes;
  final int pageCount;

  Map<String, Object> toJson() => <String, Object>{
    'path': path,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'pageCount': pageCount,
  };
}
