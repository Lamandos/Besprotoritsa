import 'dart:convert';
import 'dart:io';

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

        final content = await file.readAsBytes();
        final firstHash = _sha256(content);
        final secondHash = _sha256(content);

        expect(firstHash, expectedHash);
        expect(secondHash, expectedHash);
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

String _sha256(List<int> input) {
  const mask = 0xffffffff;
  const roundConstants = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final bytes = List<int>.of(input)..add(0x80);
  final bitLength = input.length * 8;

  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xff);
  }

  var hash0 = 0x6a09e667;
  var hash1 = 0xbb67ae85;
  var hash2 = 0x3c6ef372;
  var hash3 = 0xa54ff53a;
  var hash4 = 0x510e527f;
  var hash5 = 0x9b05688c;
  var hash6 = 0x1f83d9ab;
  var hash7 = 0x5be0cd19;

  for (var offset = 0; offset < bytes.length; offset += 64) {
    final words = List<int>.filled(64, 0);
    for (var index = 0; index < 16; index++) {
      final byteOffset = offset + (index * 4);
      words[index] =
          (bytes[byteOffset] << 24) |
          (bytes[byteOffset + 1] << 16) |
          (bytes[byteOffset + 2] << 8) |
          bytes[byteOffset + 3];
    }
    for (var index = 16; index < 64; index++) {
      final sigma0 =
          _rightRotate(words[index - 15], 7) ^
          _rightRotate(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final sigma1 =
          _rightRotate(words[index - 2], 17) ^
          _rightRotate(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + sigma0 + words[index - 7] + sigma1) & mask;
    }

    var a = hash0;
    var b = hash1;
    var c = hash2;
    var d = hash3;
    var e = hash4;
    var f = hash5;
    var g = hash6;
    var h = hash7;

    for (var index = 0; index < 64; index++) {
      final sum1 =
          _rightRotate(e, 6) ^ _rightRotate(e, 11) ^ _rightRotate(e, 25);
      final choice = (e & f) ^ ((~e) & g);
      final temporary1 =
          (h + sum1 + choice + roundConstants[index] + words[index]) & mask;
      final sum0 =
          _rightRotate(a, 2) ^ _rightRotate(a, 13) ^ _rightRotate(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temporary2 = (sum0 + majority) & mask;

      h = g;
      g = f;
      f = e;
      e = (d + temporary1) & mask;
      d = c;
      c = b;
      b = a;
      a = (temporary1 + temporary2) & mask;
    }

    hash0 = (hash0 + a) & mask;
    hash1 = (hash1 + b) & mask;
    hash2 = (hash2 + c) & mask;
    hash3 = (hash3 + d) & mask;
    hash4 = (hash4 + e) & mask;
    hash5 = (hash5 + f) & mask;
    hash6 = (hash6 + g) & mask;
    hash7 = (hash7 + h) & mask;
  }

  return [
    hash0,
    hash1,
    hash2,
    hash3,
    hash4,
    hash5,
    hash6,
    hash7,
  ].map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}

int _rightRotate(int value, int amount) =>
    ((value >>> amount) | (value << (32 - amount))) & 0xffffffff;
