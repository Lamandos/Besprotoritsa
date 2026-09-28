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

const _requiredMvpCharacterFiles = ['engineer', 'guard'];

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
  _validateMvpCharacterFiles(contentDirectory, contentSetId, issues);
  final allRecords = [...catalog, ...selected];
  _validateSchemas(allRecords, contentDirectory, issues);
  _validateMetadata(allRecords, issues);
  _validateUniqueIds(allRecords, issues);
  _validateEffects(allRecords, issues);
  await _validateLocalization(allRecords, contentDirectory, issues);
  _validateReferences(catalog, selected, issues);
  await _validateMvpLayout(contentDirectory, selected, issues);
  await _validateCampaign(catalog, contentDirectory, issues);
  return ContentValidationReport(allRecords.length, List.unmodifiable(issues));
}

void _validateMvpCharacterFiles(
  Directory content,
  String contentSetId,
  List<String> issues,
) {
  if (contentSetId != 'mvp') return;
  for (final id in _requiredMvpCharacterFiles) {
    final file = File('${content.path}/mvp/characters/$id.json');
    if (!file.existsSync()) {
      issues.add(
        '${file.path} [id=$id]: required runtime character file is missing',
      );
    }
  }
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
          _catalogNamespace(entry.value.$1, row),
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

String _catalogNamespace(String schema, Map<String, Object?> value) {
  if (schema == 'item' && value['sourceDeck'] == 'supplies') {
    return 'catalog:supply';
  }
  return 'catalog:$schema';
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

void _validateSchemas(
  List<_Record> records,
  Directory content,
  List<String> issues,
) {
  final cache = <String, JsonSchemaValidator>{};
  for (final record in records) {
    final schemaFile = '${content.path}/schemas/${record.schema}.schema.json';
    try {
      cache
          .putIfAbsent(schemaFile, () {
            final decoded = jsonDecode(File(schemaFile).readAsStringSync());
            if (decoded is! Map) {
              throw const SchemaValidationException(
                'schema root must be a JSON object',
              );
            }
            return JsonSchemaValidator(
              Map<String, Object?>.from(decoded),
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
      }
      if (record.schema == 'quest' || record.schema == 'event') {
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

Future<void> _validateMvpLayout(
  Directory content,
  List<_Record> selected,
  List<String> issues,
) async {
  final file = File('${content.path}/mvp/layout.json');
  final layout = await _read(file, issues);
  if (layout == null) return;
  final coordinates = layout['coordinates'];
  if (coordinates is! List || coordinates.isEmpty) {
    issues.add(
      '${file.path} [id=<layout>].coordinates: expected a non-empty array',
    );
    return;
  }
  final hexIds = selected
      .where((record) => record.schema == 'hex')
      .map((record) => record.id)
      .whereType<String>()
      .toSet();
  final coordinateIndexes = <String, int>{};
  final hexIndexes = <String, int>{};
  for (var index = 0; index < coordinates.length; index++) {
    final row = coordinates[index];
    final recordId = '<coordinate-$index>';
    if (row is! Map<String, Object?>) {
      issues.add(
        '${file.path} [id=$recordId]: coordinate must be an object',
      );
      continue;
    }
    final q = row['q'];
    final r = row['r'];
    if (q is! int || r is! int) {
      issues.add(
        '${file.path} [id=$recordId]: q and r must be integers',
      );
    } else {
      final coordinate = '$q,$r';
      final firstIndex = coordinateIndexes.putIfAbsent(
        coordinate,
        () => index,
      );
      if (firstIndex != index) {
        issues.add(
          '${file.path} [id=$recordId]: duplicate coordinate "$coordinate"; '
          'first used by coordinate $firstIndex',
        );
      }
    }
    final hexId = row['hexId'];
    if (hexId is! String || !hexIds.contains(hexId)) {
      issues.add(
        '${file.path} [id=${hexId is String ? hexId : recordId}].hexId: '
        'unknown mvp hex "$hexId"',
      );
    } else {
      final firstIndex = hexIndexes.putIfAbsent(hexId, () => index);
      if (firstIndex != index) {
        issues.add(
          '${file.path} [id=$hexId]: duplicate layout hexId "$hexId"; '
          'first used by coordinate $firstIndex',
        );
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
  final questFile = File('${content.path}/quests.json');
  final root = await _read(questFile, issues);
  final initial = root?['initialQuestIds'];
  if (initial is List) {
    for (var index = 0; index < initial.length; index++) {
      final id = initial[index];
      if (id is! String || !byId.containsKey(id)) {
        issues.add(
          '${questFile.path} [id=<campaign>].initialQuestIds[$index]: '
          'unknown initial quest "$id"',
        );
      } else {
        starts.add(id);
      }
    }
  } else {
    issues.add(
      '${questFile.path} [id=<campaign>].initialQuestIds: '
      'expected an array of quest IDs',
    );
  }
  _reportPrerequisiteCycles(byId, issues);
  final reachableTerminals = _reachableCampaignTerminals(byId, starts);
  final terminals = quests
      .where((quest) => quest.value['endsGame'] == true)
      .toList();
  if (starts.isEmpty || terminals.isEmpty) {
    issues.add(
      '${questFile.path} [id=<campaign>]: initial quest and terminal '
      'endsGame quest are required',
    );
  } else {
    for (final terminal in terminals.where(
      (quest) => !reachableTerminals.contains(quest.id),
    )) {
      issues.add(
        '${terminal.label}: terminal quest is unreachable from '
        '${starts.join(', ')} with its prerequisites',
      );
    }
  }
}

void _reportPrerequisiteCycles(
  Map<String, _Record> quests,
  List<String> issues,
) {
  final state = <String, int>{};
  final path = <String>[];
  final reported = <String>{};

  void visit(String id) {
    state[id] = 1;
    path.add(id);
    final prerequisites = quests[id]!.value['prerequisiteQuestIds'];
    if (prerequisites is List) {
      for (final prerequisite in prerequisites.whereType<String>()) {
        if (!quests.containsKey(prerequisite)) continue;
        if (state[prerequisite] == 1) {
          final cycleStart = path.indexOf(prerequisite);
          final cycle = [...path.skip(cycleStart), prerequisite];
          final cycleKey = cycle.toSet().toList()..sort();
          if (reported.add(cycleKey.join('|'))) {
            issues.add(
              '${quests[id]!.label}.prerequisiteQuestIds: prerequisite '
              'cycle ${cycle.join(' -> ')}',
            );
          }
        } else if (state[prerequisite] == null) {
          visit(prerequisite);
        }
      }
    }
    path.removeLast();
    state[id] = 2;
  }

  for (final id in quests.keys) {
    if (state[id] == null) visit(id);
  }
}

Set<String> _reachableCampaignTerminals(
  Map<String, _Record> quests,
  Set<String> starts,
) {
  final pending = <({Set<String> active, Set<String> completed})>[
    (active: {...starts}, completed: <String>{}),
  ];
  final visited = <String>{};
  final reachableTerminals = <String>{};
  var cursor = 0;

  while (cursor < pending.length) {
    final current = pending[cursor++];
    final activeIds = current.active.toList()..sort();
    final completedIds = current.completed.toList()..sort();
    final key = '${activeIds.join(',')}|${completedIds.join(',')}';
    if (!visited.add(key)) continue;

    for (final id in current.active) {
      final quest = quests[id];
      if (quest == null) continue;
      final prerequisites = quest.value['prerequisiteQuestIds'];
      final required = prerequisites is List
          ? prerequisites.whereType<String>()
          : const <String>[];
      if (!required.every(current.completed.contains)) continue;

      final completed = {...current.completed, id};
      if (quest.value['endsGame'] == true) {
        reachableTerminals.add(id);
        continue;
      }
      final active = {...current.active}..remove(id);
      final nextIds = quest.value['nextQuestIds'];
      if (nextIds is List) {
        for (final nextId in nextIds.whereType<String>()) {
          final next = quests[nextId];
          if (next == null || completed.contains(nextId)) continue;
          final nextPrerequisites = next.value['prerequisiteQuestIds'];
          final nextRequired = nextPrerequisites is List
              ? nextPrerequisites.whereType<String>()
              : const <String>[];
          if (nextRequired.every(completed.contains)) active.add(nextId);
        }
      }
      pending.add((active: active, completed: completed));
    }
  }
  return reachableTerminals;
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
