import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

const _contentDirectory = 'content';
const _russianLocalizationPath = 'content/i18n/ru.json';
const _deckFiles = <String>[
  'items.json',
  'supplies.json',
  'special_items.json',
  'monsters.json',
  'events.json',
];
const _locationReferenceFields = <String>{
  'location',
  'locationId',
  'locations',
  'targetLocation',
  'targetLocationId',
};

void main() {
  late ContentIndex content;

  setUpAll(() async {
    content = await ContentIndex.load();
  });

  group('content referential integrity', () {
    test('every behaviorId resolves to a registered effect hook', () {
      final registeredIds = EffectRegistry.standard().behaviorIds.toSet();
      final errors = <String>[];

      for (final fileName in _deckFiles) {
        final document = content.documentNamed(fileName);
        if (document == null) continue;

        for (final reference in document.behaviorReferences) {
          if (!registeredIds.contains(reference.value)) {
            errors.add(
              '${reference.path} references unknown behaviorId '
              '"${reference.value}". Registered behaviorIds: '
              '${registeredIds.toList()..sort()}.',
            );
          }
        }
      }

      expect(
        errors,
        isEmpty,
        reason: _formatErrors('Broken behaviorId references', errors),
      );
    });

    test('quest and event locations exist in hexes.json', () {
      final hexes = content.documentNamed('hexes.json');
      final errors = <String>[];
      final references = <JsonReference>[
        ...?content.documentNamed('quests.json')?.locationReferences,
        ...?content.documentNamed('events.json')?.locationReferences,
      ];

      if (references.isNotEmpty && hexes == null) {
        errors.add(
          'Location references exist, but content/hexes.json is missing.',
        );
      }

      final hexIds =
          hexes?.records
              .map((record) => record.value['id'])
              .whereType<String>()
              .toSet() ??
          <String>{};
      for (final reference in references) {
        if (!hexIds.contains(reference.value)) {
          errors.add(
            '${reference.path} references location "${reference.value}", '
            'but no tile with that id exists in content/hexes.json.',
          );
        }
      }

      expect(
        errors,
        isEmpty,
        reason: _formatErrors('Broken location references', errors),
      );
    });

    test('the 29-quest graph has valid, reachable transitions', () {
      final quests = content.documentNamed('quests.json');
      if (quests == null) return;

      final errors = <String>[];
      final questById = <String, JsonRecord>{};
      for (final record in quests.records) {
        final id = record.value['id'];
        if (id is! String || id.isEmpty) {
          errors.add('${record.path}.id must be a non-empty string.');
          continue;
        }
        final previous = questById[id];
        if (previous != null) {
          errors.add(
            '${record.path}.id duplicates quest id "$id" declared at '
            '${previous.path}.id.',
          );
          continue;
        }
        questById[id] = record;
      }

      if (questById.length != 29) {
        errors.add(
          'content/quests.json must contain all 29 story quests; found '
          '${questById.length}.',
        );
      }

      final edges = <String, Set<String>>{
        for (final id in questById.keys) id: <String>{},
      };
      for (final entry in questById.entries) {
        final nextQuestIds = entry.value.value['nextQuestIds'];
        if (nextQuestIds is! List<Object?>) {
          errors.add('${entry.value.path}.nextQuestIds must be an array.');
          continue;
        }
        for (var index = 0; index < nextQuestIds.length; index++) {
          final nextId = nextQuestIds[index];
          final path = '${entry.value.path}.nextQuestIds[$index]';
          if (nextId is! String || nextId.isEmpty) {
            errors.add('$path must be a non-empty quest id.');
          } else if (!questById.containsKey(nextId)) {
            errors.add(
              '$path references unknown quest "$nextId".',
            );
          } else {
            edges[entry.key]!.add(nextId);
          }
        }
      }

      final initialQuestIds = _initialQuestIds(quests, questById);
      if (initialQuestIds.isEmpty) {
        errors.add(
          'Cannot identify quest 1. Declare initialQuestId(s), use an id '
          'such as "1" or "quest-1", or set number: 1.',
        );
      } else {
        final reachable = _reachableQuestIds(initialQuestIds, edges);
        final unreachable =
            questById.keys.where((id) => !reachable.contains(id)).toList()
              ..sort();
        if (unreachable.isNotEmpty) {
          errors.add(
            'Quest(s) are unreachable from quest 1: ${unreachable.join(', ')}.',
          );
        }
      }

      expect(
        errors,
        isEmpty,
        reason: _formatErrors('Invalid quest graph', errors),
      );
    });

    test('every nameKey and descKey is translated into Russian', () {
      final translations = content.russianTranslations;
      final errors = <String>[];

      for (final document in content.documents) {
        for (final reference in document.localizationReferences) {
          if (!translations.contains(reference.value)) {
            errors.add(
              '${reference.path} uses missing Russian translation key '
              '"${reference.value}".',
            );
          }
        }
      }

      expect(
        errors,
        isEmpty,
        reason: _formatErrors('Missing Russian translations', errors),
      );
    });
  });
}

Set<String> _initialQuestIds(
  ContentDocument document,
  Map<String, JsonRecord> questById,
) {
  const initialFields = {
    'initialQuestId',
    'initialQuestIds',
    'startQuestId',
    'startQuestIds',
  };
  final declared = <String>{};
  for (final field in initialFields) {
    final value = document.root[field];
    if (value is String && questById.containsKey(value)) declared.add(value);
    if (value is List<Object?>) {
      declared.addAll(value.whereType<String>().where(questById.containsKey));
    }
  }
  if (declared.isNotEmpty) return declared;

  for (final entry in questById.entries) {
    final number =
        entry.value.value['number'] ?? entry.value.value['questNumber'];
    if (number == 1 || number == '1') return {entry.key};
  }
  return questById.keys
      .where((id) => RegExp(r'^(?:quest[-_])?1$').hasMatch(id))
      .toSet();
}

Set<String> _reachableQuestIds(
  Set<String> initialQuestIds,
  Map<String, Set<String>> edges,
) {
  final reachable = <String>{...initialQuestIds};
  final pending = <String>[...initialQuestIds];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    for (final next in edges[current] ?? const <String>{}) {
      if (reachable.add(next)) pending.add(next);
    }
  }
  return reachable;
}

String _formatErrors(String title, List<String> errors) => errors.isEmpty
    ? title
    : '$title:\n${errors.map((error) => ' - $error').join('\n')}';

final class ContentIndex {
  ContentIndex._({required this.documents, required this.russianTranslations});

  final List<ContentDocument> documents;
  final Set<String> russianTranslations;

  ContentDocument? documentNamed(String fileName) {
    for (final document in documents) {
      if (document.file.uri.pathSegments.last == fileName) return document;
    }
    return null;
  }

  static Future<ContentIndex> load() async {
    final content = Directory(_contentDirectory);
    final files = await content
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));

    final documents = <ContentDocument>[];
    var russianTranslations = <String>{};
    for (final file in files) {
      if (_isExcluded(file.path)) continue;
      final document = await ContentDocument.read(file);
      documents.add(document);
      if (file.path == _russianLocalizationPath) {
        russianTranslations = _translationKeys(document.root);
      }
    }
    return ContentIndex._(
      documents: documents,
      russianTranslations: russianTranslations,
    );
  }
}

// Schemas describe JSON rather than game content, while content/mvp is an
// isolated demonstration dataset with its own i18n_ru.json catalog.
bool _isExcluded(String path) =>
    path.contains('/mvp/') || path.contains('/schemas/');

final class ContentDocument {
  ContentDocument._({
    required this.file,
    required this.root,
    required this.records,
  });

  final File file;
  final Map<String, Object?> root;
  final List<JsonRecord> records;

  Iterable<JsonReference> get behaviorReferences =>
      _referencesForKeys(root, const {'behaviorId'}, _displayPath(file));

  Iterable<JsonReference> get locationReferences =>
      _referencesForKeys(root, _locationReferenceFields, _displayPath(file));

  Iterable<JsonReference> get localizationReferences => _referencesForKeys(
    root,
    const {'nameKey', 'descKey'},
    _displayPath(file),
  );

  static Future<ContentDocument> read(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    final Map<String, Object?> root;
    if (decoded is Map<String, dynamic>) {
      root = Map<String, Object?>.from(decoded);
    } else if (decoded is List<dynamic>) {
      root = {'entries': List<Object?>.from(decoded)};
    } else {
      throw FormatException(
        '${_displayPath(file)} must contain a JSON object or array.',
      );
    }
    return ContentDocument._(
      file: file,
      root: root,
      records: _records(root, _displayPath(file)),
    );
  }
}

final class JsonRecord {
  const JsonRecord(this.value, this.path);

  final Map<String, Object?> value;
  final String path;
}

final class JsonReference {
  const JsonReference(this.value, this.path);

  final String value;
  final String path;
}

List<JsonRecord> _records(Map<String, Object?> root, String path) {
  final records = <JsonRecord>[];
  void addRecords(Object? value, String valuePath) {
    if (value is List<Object?>) {
      for (var index = 0; index < value.length; index++) {
        final item = value[index];
        if (item is Map<String, dynamic>) {
          records.add(
            JsonRecord(Map<String, Object?>.from(item), '$valuePath[$index]'),
          );
        }
      }
    }
  }

  for (final entry in root.entries) {
    addRecords(entry.value, '$path.${entry.key}');
  }
  if (records.isEmpty) {
    for (final entry in root.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic> && value['id'] is String) {
        records.add(
          JsonRecord(Map<String, Object?>.from(value), '$path.${entry.key}'),
        );
      }
    }
  }
  if (records.isEmpty && root.containsKey('id')) {
    records.add(JsonRecord(root, path));
  }
  return records;
}

Iterable<JsonReference> _referencesForKeys(
  Object? value,
  Set<String> keys,
  String path,
) sync* {
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      final entryPath = '$path.${entry.key}';
      if (keys.contains(entry.key)) {
        final referenceValue = entry.value;
        if (referenceValue is String) {
          yield JsonReference(referenceValue, entryPath);
        } else if (referenceValue is List<Object?>) {
          for (var index = 0; index < referenceValue.length; index++) {
            final item = referenceValue[index];
            if (item is String) yield JsonReference(item, '$entryPath[$index]');
          }
        }
      }
      yield* _referencesForKeys(entry.value, keys, entryPath);
    }
  } else if (value is List<Object?>) {
    for (var index = 0; index < value.length; index++) {
      yield* _referencesForKeys(value[index], keys, '$path[$index]');
    }
  }
}

Set<String> _translationKeys(Map<String, Object?> root) {
  final keys = <String>{};
  void visit(Object? value, String prefix) {
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is String) keys.add(key);
        visit(entry.value, key);
      }
    }
  }

  visit(root, '');
  return keys;
}

String _displayPath(File file) => file.path.replaceFirst('./', '');
