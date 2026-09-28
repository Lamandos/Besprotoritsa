import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../../../tool/content_validator.dart' as validator;

const _repoContentPath = 'content';
const _fixturePath = 'packages/besprotoritsa_data/test/fixtures/content-audit';

void main() {
  group('content audit', () {
    test('accepts the full catalog and selected mvp content set', () async {
      final report = await validator.validateContent(
        contentDirectory: Directory(_repoContentPath),
        contentSetId: 'mvp',
      );

      expect(report.isValid, isTrue, reason: report.issues.join('\n'));
      expect(report.records, greaterThan(200));
    });

    for (final fixtureName in const [
      'quest_link',
      'location_link',
      'terminal_reachability',
      'i18n_key',
      'schema',
      'import_batch',
      'source_deck',
      'copies',
      'effect_id',
      'effect_trigger',
      'enum',
      'character_start_item',
      'unavailable_content_set',
      'duplicate_id',
      'duplicate_card_id',
      'initial_quest_link',
      'initial_quest_non_string',
      'event_location_link',
      'layout_missing',
      'layout_malformed',
      'layout_hex_link',
      'layout_duplicate_coordinate',
      'layout_duplicate_hex_id',
      'required_runtime_character',
      'schema_root_type',
      'quest_condition_required_field',
      'prerequisite_cycle',
    ]) {
      test(
        'rejects $fixtureName fixture with record ID and file path',
        () async {
          final fixture = await _readFixture(fixtureName);
          final tempRoot = await Directory.systemTemp.createTemp(
            'besprotoritsa-content-audit-',
          );
          addTearDown(() => tempRoot.delete(recursive: true));
          final copiedContent = Directory('${tempRoot.path}/content');
          await _copyDirectory(Directory(_repoContentPath), copiedContent);

          final operation = fixture['operation'];
          if (operation == 'duplicate') {
            final source = File('${copiedContent.path}/${fixture['source']}');
            final destination = File(
              '${copiedContent.path}/${fixture['destination']}',
            );
            await destination.parent.create(recursive: true);
            await source.copy(destination.path);
          } else if (operation == 'delete') {
            await File('${copiedContent.path}/${fixture['file']}').delete();
          } else {
            final relativePath = fixture['file']! as String;
            final file = File('${copiedContent.path}/$relativePath');
            final root = jsonDecode(await file.readAsString());
            final segments = fixture['path']! as List<Object?>;
            final updated = _replaceAtPath(root, segments, fixture['value']);
            await file.writeAsString(
              const JsonEncoder.withIndent('  ').convert(updated),
            );
          }

          final report = await validator.validateContent(
            contentDirectory: copiedContent,
            contentSetId: 'mvp',
          );
          final match = report.issues.where(
            (issue) => issue.contains(fixture['expected']! as String),
          );
          expect(match, isNotEmpty, reason: report.issues.join('\n'));
          expect(match.join('\n'), contains('[id='));
          expect(match.join('\n'), contains('content'));
        },
      );
    }

    test('uses schemas from the requested content tree', () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'besprotoritsa-content-schema-root-',
      );
      addTearDown(() => tempRoot.delete(recursive: true));
      final copiedContent = Directory('${tempRoot.path}/content');
      await _copyDirectory(Directory(_repoContentPath), copiedContent);

      final schemaFile = File(
        '${copiedContent.path}/schemas/hex.schema.json',
      );
      final schema = jsonDecode(await schemaFile.readAsString()) as Map;
      (schema['required']! as List).add('auditOnlyRequiredField');
      await schemaFile.writeAsString(jsonEncode(schema));

      final report = await validator.validateContent(
        contentDirectory: copiedContent,
        contentSetId: 'mvp',
      );
      final match = report.issues.where(
        (issue) => issue.contains('auditOnlyRequiredField'),
      );
      expect(match, isNotEmpty, reason: report.issues.join('\n'));
      expect(match.join('\n'), contains('[id='));
      expect(match.join('\n'), contains(schemaFile.path));
    });
  });
}

Future<Map<String, Object?>> _readFixture(String name) async =>
    Map<String, Object?>.from(
      jsonDecode(
            await File('$_fixturePath/$name.json').readAsString(),
          )
          as Map,
    );

Object? _replaceAtPath(Object? root, List<Object?> path, Object? value) {
  if (path.isEmpty) return value;
  final head = path.first;
  final tail = path.skip(1).toList();
  if (root is Map<String, Object?> && head is String) {
    final updated = Map<String, Object?>.of(root);
    updated[head] = _replaceAtPath(root[head], tail, value);
    return updated;
  }
  if (root is List<Object?> && head is int) {
    final updated = List<Object?>.of(root);
    updated[head] = _replaceAtPath(updated[head], tail, value);
    return updated;
  }
  throw StateError('Invalid fixture path: $path');
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list()) {
    final relativePath = entity.path.substring(source.path.length + 1);
    final targetPath = '${destination.path}/$relativePath';
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}
