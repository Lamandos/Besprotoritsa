import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('core package keeps its production dependency boundary', () {
    final dependencies = _readDependencies(_findOwnPubspec());

    const allowedDependencies = {'collection', 'meta'};
    const networkDependencyPrefixes = {
      'chopper',
      'dio',
      'firebase',
      'flutter',
      'graphql',
      'grpc',
      'http',
      'retrofit',
      'shelf',
      'socket_io',
      'supabase',
      'web_socket',
      'websocket',
    };

    final flutterDependencies = dependencies
        .where((name) => name == 'flutter' || name.startsWith('flutter_'))
        .toSet();
    final networkDependencies = dependencies
        .where(
          (name) => networkDependencyPrefixes.any(
            (prefix) => name == prefix || name.startsWith('${prefix}_'),
          ),
        )
        .toSet();

    expect(
      flutterDependencies,
      isEmpty,
      reason: 'The rules package must not depend on Flutter.',
    );
    expect(
      networkDependencies,
      isEmpty,
      reason: 'The rules package must not depend on network libraries.',
    );
    expect(
      dependencies,
      allowedDependencies,
      reason: 'Only meta and collection are permitted production dependencies.',
    );
  });
}

Set<String> _readDependencies(File pubspec) {
  final lines = pubspec.readAsLinesSync();
  final dependencies = <String>{};
  var inDependencies = false;

  for (final line in lines) {
    if (line == 'dependencies:') {
      inDependencies = true;
      continue;
    }

    if (!inDependencies) {
      continue;
    }

    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      break;
    }

    final match = RegExp('^  ([a-z0-9_-]+):').firstMatch(line);
    if (match != null) {
      dependencies.add(match.group(1)!);
    }
  }

  return dependencies;
}

File _findOwnPubspec() {
  const packageRelativePath = 'packages/besprotoritsa_rules/pubspec.yaml';
  final candidates = [File('pubspec.yaml'), File(packageRelativePath)];

  return candidates.firstWhere(
    (file) =>
        file.existsSync() &&
        file.readAsStringSync().contains('name: besprotoritsa_rules'),
    orElse: () =>
        throw StateError('Could not find besprotoritsa_rules/pubspec.yaml.'),
  );
}
