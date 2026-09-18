import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  group('materials manifest', () {
    late List<Map<String, Object?>> entries;

    setUpAll(() async {
      entries = await _readManifest();
    });

    test('contains exactly 13 entries', () {
      expect(entries, hasLength(13));
    });

    test('records a non-zero size for every file', () {
      for (final entry in entries) {
        expect(
          entry['sizeBytes'],
          isA<int>().having((value) => value, 'value', greaterThan(0)),
        );
      }
    });

    test('contains deterministic SHA-256 hashes', () async {
      for (final entry in entries) {
        final path = entry['path']! as String;
        final expectedHash = entry['sha256']! as String;
        final file = File(path);

        final firstHash = await sha256.bind(file.openRead()).first;
        final secondHash = await sha256.bind(file.openRead()).first;

        expect(firstHash.toString(), expectedHash);
        expect(secondHash.toString(), expectedHash);
      }
    });
  });
}

Future<List<Map<String, Object?>>> _readManifest() async {
  final manifest = File('content/manifest.json');
  final decoded =
      jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
  final files = decoded['files']! as List<dynamic>;

  return files
      .map((entry) => Map<String, Object?>.from(entry as Map<String, dynamic>))
      .toList();
}
