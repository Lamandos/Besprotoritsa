import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

import 'validate_schemas.dart';

const _catalogSchemas = <String, (String, String)>{
  'characters.json': ('character', 'characters'),
  'conditions.json': ('condition', 'cards'),
  'events.json': ('event', 'cards'),
  'hexes.json': ('hex', 'hexes'),
  'items.json': ('item', 'cards'),
  'monsters.json': ('monster', 'cards'),
  'quests.json': ('quest', 'quests'),
  'special_items.json': ('special_item', 'cards'),
  'supplies.json': ('supply', 'cards'),
  'tasks.json': ('task', 'tasks'),
};

const _mvpDirectories = <String, String>{
  'characters': 'character',
  'conditions': 'condition',
  'events': 'event',
  'hexes': 'hex',
  'items': 'item',
  'monsters': 'monster',
  'quests': 'quest',
};

final class ContentValidationReport {
  const ContentValidationReport(this.records, this.issues);

  final int records;
  final List<String> issues;
  bool get isValid => issues.isEmpty;
}

/// Validates the full editorial catalog and the selected runtime content set.
Future<ContentValidationReport> validateContent({
  required Directory contentDirectory,
  required String contentSetId,
}) async {
  final issues = <String>[];
  final catalog = await _loadCatalog(contentDirectory, issues);
  final selected = await _loadMvp(contentDirectory, contentSetId, issues);
  final allRecords = [...catalog, ...selected];
  _validateSchemas(allRecords, issues);
  _validateMetadata(allRecords, issues);
  _validateUniqueIds(allRecords, issues);
  _validateEffects(allRecords, issues);
  await _validateLocalization(allRecords, contentDirectory, issues);
  _validateReferences(catalog, selected, issues);
  await _validateCampaign(catalog, contentDirectory, issues);
  return ContentValidationReport(allRecords.length, List.unmodifiable(issues));
}

Future<List<_Record>> _loadCatalog(
  Directory content,
  List<String> issues,
) async {
  final records = <_Record>[];
  for (final entry in _catalogSchemas.entries) {
    final file = File('${content.path}/${entry.key}');
    if (!file.existsSync()) {
      issues.add(
        '${file.path} [id=<dataset>]: required content dataset is missing',
      );
      continue;
    }
    final root = await _read(file, issues);
    final raw = root?[entry.value.$2];
    if (raw is! List) {
      issues.add(
        '${file.path} [id=<dataset>]: expected ${entry.value.$2} array',
      );
      continue;
    }
    final declaredBatches = root?['batchSizes'];
    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map<String, Object?>) {
        issues.add(
          '${file.path} [id=<record-$index>]: record must be an object',
        );
        continue;
      }
      records.add(
        _Record(
          row,
          '${file.path} [${entry.value.$2}][$index]',
          entry.value.$1,
          'catalog:${entry.value.$1}',
        ),
      );
      final batch = row['importBatch'];
      if (declaredBatches is Map<String, Object?> &&
          batch is int &&
          !declaredBatches.containsKey('$batch')) {
        issues.add(
          '${file.path} [${entry.value.$2}][$index] '
          '[id=${row['id'] ?? '<missing>'}].importBatch: batch $batch '
          'is not declared in batchSizes',
        );
      }
    }
  }
  return records;
}

Future<List<_Record>> _loadMvp(
  Directory content,
  String id,
  List<String> issues,
) async {
  if (id != 'mvp') {
    issues.add('${content.path} [id=$id]: unsupported contentSetId');
    return const [];
  }
  final root = Directory('${content.path}/mvp');
  if (!root.existsSync()) {
    issues.add('${root.path} [id=$id]: selected content set is missing');
    return const [];
  }
  final records = <_Record>[];
  for (final entry in _mvpDirectories.entries) {
    final directory = Directory('${root.path}/${entry.key}');
    if (!directory.existsSync()) {
      issues.add(
        '${directory.path} [id=$id]: required content namespace is missing',
      );
      continue;
    }
    final files = await directory
        .list()
        .where((f) => f is File && f.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final row = await _read(file, issues);
      if (row != null) {
        records.add(_Record(row, file.path, entry.value, 'mvp:${entry.value}'));
      }
    }
  }
  return records;
}

Future<Map<String, Object?>?> _read(File file, List<String> issues) async {
  try {
    final value = jsonDecode(await file.readAsString());
    if (value is Map<String, dynamic>) return Map<String, Object?>.from(value);
    issues.add('${file.path} [id=<document>]: JSON root must be an object');
  } on FileSystemException catch (error) {
    issues.add('${file.path} [id=<document>]: $error');
  } on FormatException catch (error) {
    issues.add('${file.path} [id=<document>]: invalid JSON: $error');
  }
  return null;
}

void _validateSchemas(List<_Record> records, List<String> issues) {
  final cache = <String, JsonSchemaValidator>{};
  for (final record in records) {
    final schemaFile = 'content/schemas/${record.schema}.schema.json';
    try {
      cache
          .putIfAbsent(schemaFile, () {
            final decoded = jsonDecode(File(schemaFile).readAsStringSync());
            return JsonSchemaValidator(
              Map<String, Object?>.from(decoded as Map),
            );
          })
          .validate(record.value);
    } on SchemaValidationException catch (error) {
      issues.add('${record.label}: schema $schemaFile: ${error.message}');
    } on FileSystemException catch (error) {
      issues.add('${record.label}: cannot read schema $schemaFile: $error');
    } on FormatException catch (error) {
      issues.add('${record.label}: invalid schema $schemaFile: $error');
    }
  }
}

void _validateMetadata(List<_Record> records, List<String> issues) {
  const allowedSources = {'items', 'supplies', 'specialItems'};
  for (final record in records) {
    for (final field in const ['importBatch', 'copies']) {
      final value = record.value[field];
      if (value != null && (value is! int || value < 1)) {
        issues.add('${record.label}.$field: expected a positive integer');
      }
    }
    final source = record.value['sourceDeck'];
    if (source != null && !allowedSources.contains(source)) {
      issues.add('${record.label}.sourceDeck: unsupported value "$source"');
    }
    if (record.schema == 'supply' && source != null && source != 'supplies') {
      issues.add(
        '${record.label}.sourceDeck: supply record must use "supplies"',
      );
    }
  }
}

void _validateUniqueIds(List<_Record> records, List<String> issues) {
  final seen = <String, _Record>{};
  for (final record in records) {
    final id = record.id;
    if (id == null || id.isEmpty) continue;
    final key = '${record.namespace}:$id';
    final previous = seen[key];
    if (previous != null) {
      issues.add(
        '${record.label}: duplicate id "$id" in ${record.namespace}; '
        'first at ${previous.label}',
      );
    } else {
      seen[key] = record;
    }
  }
}

void _validateEffects(List<_Record> records, List<String> issues) {
  final registry = EffectRegistry.standard();
  for (final record in records) {
    void validateEffect(String value, String path) {
      final hook = registry[value];
      if (hook == null) {
        issues.add('${record.label}.$path: unregistered effectId "$value"');
        return;
      }
      final isMonsterBehavior =
          record.schema == 'monster' && path == 'behaviorId';
      final isEventOption =
          record.schema == 'event' && path.endsWith('.behaviorId');
      final isConditionTrigger =
          record.schema == 'condition' && path == 'behaviorId';
      if (isMonsterBehavior && hook is! MonsterBehaviorHook) {
        issues.add(
          '${record.label}.$path: "$value" must register a MonsterBehaviorHook',
        );
      }
      if (isEventOption && hook is! CardBehaviorHook) {
        issues.add(
          '${record.label}.$path: "$value" must use an event/card trigger '
          'hook',
        );
      }
      if (isConditionTrigger && hook is! CardBehaviorHook) {
        issues.add(
          '${record.label}.$path: "$value" must register a condition/card '
          'trigger hook',
        );
      }
      if (record.schema != 'monster' && hook is MonsterBehaviorHook) {
        issues.add(
          '${record.label}.$path: "$value" has monster trigger type '
          'outside a monster behavior',
        );
      }
    }

    _visit(record.value, (key, value, path) {
      if (key == 'behaviorId' && value is String) {
        validateEffect(value, path);
      } else if (key == 'behaviorIds' && value is List) {
        for (var index = 0; index < value.length; index++) {
          final behaviorId = value[index];
          if (behaviorId is String) {
            validateEffect(behaviorId, '$path[$index]');
          }
        }
      }
    });
  }
}

Future<void> _validateLocalization(
  List<_Record> records,
  Directory content,
  List<String> issues,
) async {
  final catalogLocale = await _read(
    File('${content.path}/i18n/ru.json'),
    issues,
  );
  final mvpLocale = await _read(
    File('${content.path}/mvp/i18n_ru.json'),
    issues,
  );
  final translations = <String, Set<String>>{
    'catalog': _flattenTranslations(catalogLocale ?? {}),
    'mvp': _flattenTranslations(mvpLocale ?? {}),
  };
  for (final record in records) {
    final localeId = record.namespace.startsWith('mvp:') ? 'mvp' : 'catalog';
    _visit(record.value, (key, value, path) {
      if (!key.endsWith('Key') || value is! String) return;
      if (!(translations[localeId]?.contains(value) ?? false)) {
        issues.add(
          '${record.label}.$path: missing $localeId i18n key "$value"',
        );
      }
    });
  }
}

void _validateReferences(
  List<_Record> catalog,
  List<_Record> selected,
  List<String> issues,
) {
  for (final group in [catalog, selected]) {
    final prefix = group.isNotEmpty && group.first.namespace.startsWith('mvp:')
        ? 'mvp'
        : 'catalog';
    final idsBySchema = <String, Set<String>>{};
    for (final record in group) {
      final id = record.id;
      if (id != null) idsBySchema.putIfAbsent(record.schema, () => {}).add(id);
    }
    final hexIds = idsBySchema['hex'] ?? <String>{};
    final questIds = idsBySchema['quest'] ?? <String>{};
    final itemIds = <String>{
      ...?idsBySchema['item'],
      ...?idsBySchema['special_item'],
    };
    for (final record in group) {
      if (record.schema == 'quest') {
        for (final field in const ['nextQuestIds', 'prerequisiteQuestIds']) {
          final values = record.value[field];
          if (values is List) {
            for (final target in values.whereType<String>()) {
              if (!questIds.contains(target)) {
                issues.add(
                  '${record.label}.$field: unknown $prefix quest "$target"',
                );
              }
            }
          }
        }
        _visit(record.value, (key, value, path) {
          if ((key == 'targetLocation' || key == 'locationId') &&
              value is String &&
              !hexIds.contains(value)) {
            issues.add(
              '${record.label}.$path: unknown $prefix location "$value"',
            );
          }
        });
      }
      if (prefix == 'mvp' && record.schema == 'character') {
        final starts = record.value['startItems'];
        if (starts is List) {
          for (var index = 0; index < starts.length; index++) {
            final id = starts[index];
            if (id is String && !itemIds.contains(id)) {
              issues.add(
                '${record.label}.startItems[$index]: card "$id" is '
                'unavailable in $prefix',
              );
            }
          }
        }
      }
    }
  }
}

Future<void> _validateCampaign(
  List<_Record> records,
  Directory content,
  List<String> issues,
) async {
  final quests = records.where((record) => record.schema == 'quest').toList();
  if (quests.isEmpty || quests.first.namespace.startsWith('mvp:')) return;
  final byId = {
    for (final quest in quests)
      if (quest.id != null) quest.id!: quest,
  };
  final starts = <String>{};
  final root = await _read(File('${content.path}/quests.json'), issues);
  final initial = root?['initialQuestIds'];
  if (initial is List) {
    starts.addAll(initial.whereType<String>().where(byId.containsKey));
  }
  final reachable = <String>{...starts};
  final queue = <String>[...starts];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    final next = byId[id]?.value['nextQuestIds'];
    if (next is List) {
      for (final target in next.whereType<String>()) {
        if (reachable.add(target)) queue.add(target);
      }
    }
  }
  final terminals = quests
      .where((quest) => quest.value['endsGame'] == true)
      .toList();
  if (starts.isEmpty || terminals.isEmpty) {
    issues.add(
      'content/quests.json [id=<campaign>]: initial quest and terminal '
      'endsGame quest are required',
    );
  } else {
    for (final terminal in terminals.where(
      (quest) => !reachable.contains(quest.id),
    )) {
      issues.add(
        '${terminal.label}: terminal quest is unreachable from '
        '${starts.join(', ')}',
      );
    }
  }
}

Set<String> _flattenTranslations(Map<String, Object?> root) {
  final result = <String>{};
  void visit(Object? value, String prefix) {
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        final text = entry.value;
        if (text is String && text.trim().isNotEmpty) {
          result
            ..add(path)
            ..add(path.startsWith('content.') ? path.substring(8) : path);
        }
        visit(entry.value, path);
      }
    }
  }

  visit(root, '');
  return result;
}

void _visit(
  Object? value,
  void Function(String key, Object? value, String path) action, [
  String path = '',
]) {
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      final childPath = path.isEmpty ? entry.key : '$path.${entry.key}';
      action(entry.key, entry.value, childPath);
      _visit(entry.value, action, childPath);
    }
  } else if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _visit(value[index], action, '$path[$index]');
    }
  }
}

final class _Record {
  const _Record(this.value, this.path, this.schema, this.namespace);
  final Map<String, Object?> value;
  final String path;
  final String schema;
  final String namespace;
  String get label => '$path [id=${id ?? '<missing>'}]';
  String? get id => switch (value['id']) {
    final String id => id,
    _ => null,
  };
}
