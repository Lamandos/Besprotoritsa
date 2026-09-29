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
const _mvpHexDirections = <(int, int)>[
  (0, -1),
  (1, -1),
  (1, 0),
  (0, 1),
  (-1, 1),
  (-1, 0),
];

typedef _RuntimeHex = ({String id, int q, int r, Set<int> exits});

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
  final selected = switch (contentSetId) {
    'mvp' => await _loadMvp(contentDirectory, issues),
    'full' => catalog,
    _ => _loadUnsupported(contentDirectory, contentSetId, issues),
  };
  _validateMvpCharacterFiles(contentDirectory, contentSetId, issues);
  final allRecords = contentSetId == 'full'
      ? catalog
      : [...catalog, ...selected];
  _validateSchemas(allRecords, contentDirectory, issues);
  _validateMetadata(allRecords, issues);
  _validateRuntimeCompatibility(allRecords, issues);
  _validateUniqueIds(allRecords, issues);
  _validateEffects(allRecords, issues);
  await _validateLocalization(allRecords, contentDirectory, issues);
  _validateReferences(
    catalog,
    selected,
    issues,
    validateFullCharacterEquipment: contentSetId == 'full',
  );
  await _validateMvpLayout(contentDirectory, selected, issues);
  if (contentSetId == 'mvp') {
    await _validateMvpDecks(contentDirectory, selected, issues);
  }
  await _validateCampaign(catalog, contentDirectory, issues);
  return ContentValidationReport(allRecords.length, List.unmodifiable(issues));
}

Future<void> _validateMvpDecks(
  Directory content,
  List<_Record> selected,
  List<String> issues,
) async {
  final file = File('${content.path}/mvp/decks.json');
  final decks = await _read(file, issues);
  if (decks == null) return;
  const sources = <String, String>{
    'conditions': 'condition',
    'events': 'event',
    'storyQuests': 'quest',
  };
  for (final entry in sources.entries) {
    final rawIds = decks[entry.key];
    if (rawIds is! List) {
      issues.add('${file.path}.${entry.key}: expected an array of ids');
      continue;
    }
    final available = selected
        .where((record) => record.schema == entry.value)
        .map((record) => record.id)
        .whereType<String>()
        .toSet();
    final used = <String>{};
    for (var index = 0; index < rawIds.length; index++) {
      final id = rawIds[index];
      if (id is! String || !available.contains(id)) {
        issues.add(
          '${file.path}.${entry.key}[$index]: unknown MVP '
          '${entry.value} id "$id"',
        );
      } else if (!used.add(id)) {
        issues.add('${file.path}.${entry.key}[$index]: duplicate id "$id"');
      }
    }
  }
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

List<_Record> _loadUnsupported(
  Directory content,
  String id,
  List<String> issues,
) {
  issues.add('${content.path} [id=$id]: unsupported contentSetId');
  return const [];
}

Future<List<_Record>> _loadMvp(
  Directory content,
  List<String> issues,
) async {
  const id = 'mvp';
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
            final schema = Map<String, Object?>.from(decoded);
            validateSchemaDefinition(schema, schemaFile);
            return JsonSchemaValidator(schema);
          })
          .validate(record.value);
    } on SchemaValidationException catch (error) {
      issues.add(
        '${record.label} [id=${record.id ?? '<missing>'}]: '
        'schema $schemaFile: ${error.message}',
      );
    } on FileSystemException catch (error) {
      issues.add(
        '${record.label} [id=${record.id ?? '<missing>'}]: '
        'cannot read schema $schemaFile: $error',
      );
    } on FormatException catch (error) {
      issues.add(
        '${record.label} [id=${record.id ?? '<missing>'}]: '
        'invalid schema $schemaFile: $error',
      );
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
    if (record.namespace == 'catalog:item' && source == null) {
      issues.add(
        '${record.label}.sourceDeck: required for catalog item deck '
        'accounting',
      );
    }
    if (source != null && !allowedSources.contains(source)) {
      issues.add('${record.label}.sourceDeck: unsupported value "$source"');
    }
    if (record.namespace == 'catalog:item' &&
        source != null &&
        source != 'items' &&
        source != 'supplies') {
      issues.add(
        '${record.label}.sourceDeck: catalog item must use "items" or '
        '"supplies"; "specialItems" records belong in special_items.json',
      );
    }
    if (record.schema == 'supply' && source != null && source != 'supplies') {
      issues.add(
        '${record.label}.sourceDeck: supply record must use "supplies"',
      );
    }
  }
}

void _validateRuntimeCompatibility(
  List<_Record> records,
  List<String> issues,
) {
  const cardStats = {
    'strength',
    'combatStrength',
    'science',
    'repair',
    'endurance',
    'agility',
    'health',
    'defense',
  };
  for (final record in records) {
    if (record.namespace == 'catalog:quest') {
      final number = record.value['number'];
      if (number is! int || number < 1) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].number: '
          'catalog quest number must be a positive integer',
        );
      }
      final conditions = record.value['conditions'];
      if (conditions is! List) continue;
      final conditionIds = <String>{};
      for (var index = 0; index < conditions.length; index++) {
        final condition = conditions[index];
        final path = '${record.label}.conditions[$index]';
        if (condition is! Map<String, Object?>) {
          issues.add(
            '$path [id=${record.id ?? '<missing>'}]: catalog quest '
            'conditions must be objects',
          );
          continue;
        }
        final conditionId = condition['id'];
        if (conditionId is String && !conditionIds.add(conditionId)) {
          issues.add(
            '$path [id=${record.id ?? '<missing>'}].id: duplicate condition '
            'id "$conditionId" within quest',
          );
        }
      }
    }
    if (record.namespace == 'catalog:task') {
      final target = record.value['targetValue'];
      if (target is! int || target < 1) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].targetValue: '
          'expected a positive integer for runtime task loading',
        );
      }
    }
    if (record.namespace == 'catalog:item' ||
        record.namespace == 'catalog:supply' ||
        record.namespace == 'catalog:special_item' ||
        record.namespace.startsWith('mvp:item')) {
      final stats = record.value['stats'];
      if (stats is Map) {
        for (final entry in stats.entries) {
          if (entry.key is! String || !cardStats.contains(entry.key)) {
            issues.add(
              '${record.label} [id=${record.id ?? '<missing>'}].stats.'
              '${entry.key}: unknown runtime card stat',
            );
          } else if (entry.value is! int) {
            issues.add(
              '${record.label} [id=${record.id ?? '<missing>'}].stats.'
              '${entry.key}: expected an integer runtime card stat',
            );
          }
        }
      }
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
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].$path: '
          'unregistered effectId "$value"',
        );
        return;
      }
      final isMonsterBehavior =
          record.schema == 'monster' && path == 'behaviorId';
      final isEventBehavior = record.schema == 'event';
      final isConditionTrigger =
          record.schema == 'condition' && path == 'behaviorId';
      if (isMonsterBehavior && hook is! MonsterBehaviorHook) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].$path: '
          '"$value" must register a MonsterBehaviorHook',
        );
      }
      if (isEventBehavior && hook is! CardBehaviorHook) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].$path: '
          '"$value" must use an event/card trigger '
          'hook',
        );
      }
      if (isConditionTrigger && hook is! CardBehaviorHook) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].$path: '
          '"$value" must register a condition/card '
          'trigger hook',
        );
      }
      if (record.schema != 'monster' && hook is MonsterBehaviorHook) {
        issues.add(
          '${record.label} [id=${record.id ?? '<missing>'}].$path: '
          '"$value" has monster trigger type '
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
  List<String> issues, {
  bool validateFullCharacterEquipment = false,
}) {
  final groups = validateFullCharacterEquipment
      ? [selected]
      : [catalog, selected];
  for (final group in groups) {
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
    final monsterIds = idsBySchema['monster'] ?? <String>{};
    final itemIds = <String>{
      ...?idsBySchema['item'],
      ...?idsBySchema['supply'],
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
                  '${record.label} [id=${record.id ?? '<missing>'}].$field: '
                  'unknown $prefix quest "$target"',
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
              '${record.label} [id=${record.id ?? '<missing>'}].$path: '
              'unknown $prefix location "$value"',
            );
          }
          if (record.schema == 'quest' &&
              key == 'monsterId' &&
              value is String &&
              !monsterIds.contains(value)) {
            issues.add(
              '${record.label} [id=${record.id ?? '<missing>'}].$path: '
              'unknown $prefix monster "$value"',
            );
          }
          if (record.schema == 'quest' &&
              key == 'itemId' &&
              value is String &&
              !const {'item', 'supply'}.contains(value) &&
              !itemIds.contains(value)) {
            issues.add(
              '${record.label} [id=${record.id ?? '<missing>'}].$path: '
              'unknown $prefix card "$value"',
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
      if (validateFullCharacterEquipment && record.schema == 'character') {
        final starts = record.value['startItems'];
        if (starts is List) {
          for (var index = 0; index < starts.length; index++) {
            final id = starts[index];
            if (id is String && !itemIds.contains(id)) {
              issues.add(
                '${record.label}.startItems[$index]: card "$id" is '
                'unavailable in full',
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
  if (selected.isNotEmpty && !selected.first.namespace.startsWith('mvp:')) {
    return;
  }
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
  final hexRecords = selected.where((record) => record.schema == 'hex');
  final hexIds = <String>{};
  final hexesById = <String, _Record>{};
  for (final record in hexRecords) {
    final id = record.id;
    if (id == null) continue;
    hexIds.add(id);
    hexesById.putIfAbsent(id, () => record);
  }
  final coordinateIndexes = <String, int>{};
  final hexIndexes = <String, int>{};
  final hexIdsByCoordinate = <String, String>{};
  final tilesByCoordinate = <String, _RuntimeHex>{};
  for (var index = 0; index < coordinates.length; index++) {
    final row = coordinates[index];
    final recordId = '<coordinate-$index>';
    if (row is! Map<String, Object?>) {
      issues.add(
        '${file.path} [id=$recordId]: coordinate must be an object',
      );
      continue;
    }
    final hexId = row['hexId'];
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
      if (hexId is String) {
        hexIdsByCoordinate.putIfAbsent(coordinate, () => hexId);
        final exits = hexesById[hexId]?.value['exits'];
        if (!coordinateIndexes.containsKey(coordinate) ||
            coordinateIndexes[coordinate] == index) {
          if (exits is List && exits.every((edge) => edge is int)) {
            tilesByCoordinate[coordinate] = (
              id: hexId,
              q: q,
              r: r,
              exits: exits.cast<int>().toSet(),
            );
          }
        }
      }
    }
    if (hexId is! String || !hexIds.contains(hexId)) {
      issues.add(
        '${file.path} [id=${hexId is String ? hexId : recordId}].hexId: '
        'unknown mvp hex "$hexId"',
      );
    } else {
      final runtimeHexFile = File(
        '${content.path}/mvp/hexes/$hexId.json',
      );
      if (!runtimeHexFile.existsSync()) {
        issues.add(
          '${file.path} [id=$hexId].hexId: runtime hex file is missing at '
          '${runtimeHexFile.path}',
        );
      }
      final firstIndex = hexIndexes.putIfAbsent(hexId, () => index);
      if (firstIndex != index) {
        issues.add(
          '${file.path} [id=$hexId]: duplicate layout hexId "$hexId"; '
          'first used by coordinate $firstIndex',
        );
      }
    }
  }
  if (hexIdsByCoordinate['0,0'] != 'anabiosis') {
    issues.add(
      '${file.path} [id=anabiosis].coordinates: runtime heroes spawn at '
      '(0,0); anabiosis must occupy that coordinate',
    );
  }
  final startHex = hexesById['anabiosis'];
  if (startHex != null && startHex.value['type'] != 'start') {
    issues.add(
      '${startHex.label}.type: runtime opens the anabiosis tile as the start '
      'location, so its type must be "start"',
    );
  }
  if (!hexIdsByCoordinate.containsKey('0,1')) {
    issues.add(
      '${file.path} [id=ghoul-1].coordinates: the initial monster spawns at '
      '(0,1), which must contain a layout hex',
    );
  }

  final linksByCoordinate = <String, Set<String>>{
    for (final coordinate in tilesByCoordinate.keys) coordinate: <String>{},
  };
  for (final entry in tilesByCoordinate.entries) {
    final coordinate = entry.key;
    final tile = entry.value;
    for (var edge = 0; edge < _mvpHexDirections.length; edge++) {
      final direction = _mvpHexDirections[edge];
      final adjacentCoordinate =
          '${tile.q + direction.$1},${tile.r + direction.$2}';
      final adjacent = tilesByCoordinate[adjacentCoordinate];
      if (adjacent == null || coordinate.compareTo(adjacentCoordinate) >= 0) {
        continue;
      }
      final hasExit = tile.exits.contains(edge);
      final hasOppositeExit = adjacent.exits.contains((edge + 3) % 6);
      if (hasExit != hasOppositeExit) {
        issues.add(
          '${file.path} [id=${tile.id}].exits: port $edge toward '
          '${adjacent.id} does not match its opposite exit',
        );
      } else if (hasExit) {
        linksByCoordinate[coordinate]!.add(adjacentCoordinate);
        linksByCoordinate[adjacentCoordinate]!.add(coordinate);
      }
    }
  }

  final reachableCoordinates = <String>{};
  final pendingCoordinates = <String>[];
  if (tilesByCoordinate.containsKey('0,0')) {
    reachableCoordinates.add('0,0');
    pendingCoordinates.add('0,0');
  }
  for (var index = 0; index < pendingCoordinates.length; index++) {
    for (final adjacent
        in linksByCoordinate[pendingCoordinates[index]] ?? const <String>{}) {
      if (reachableCoordinates.add(adjacent)) pendingCoordinates.add(adjacent);
    }
  }

  final requiredQuestLocations = <String, String>{};
  for (final quest in selected.where((record) => record.schema == 'quest')) {
    if (quest.id == 'chapter-1-awakening' &&
        quest.value['targetLocation'] != 'crew-mess') {
      issues.add(
        '${quest.label} [id=${quest.id}].targetLocation: runtime opening '
        'quest must target "crew-mess"',
      );
    }
    _visit(quest.value, (key, value, path) {
      if ((key == 'targetLocation' || key == 'locationId') && value is String) {
        requiredQuestLocations.putIfAbsent(
          value,
          () => '${quest.label}.$path',
        );
      }
    });
  }
  for (final entry in requiredQuestLocations.entries) {
    String? coordinate;
    for (final tile in tilesByCoordinate.entries) {
      if (tile.value.id == entry.key) {
        coordinate = tile.key;
        break;
      }
    }
    if (coordinate == null) {
      issues.add(
        '${entry.value}: required quest location "${entry.key}" is not '
        'placed in ${file.path}',
      );
    } else if (!reachableCoordinates.contains(coordinate)) {
      issues.add(
        '${entry.value}: required quest location "${entry.key}" is '
        'unreachable from anabiosis through reciprocal exits in ${file.path}',
      );
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
  final declaredStarts = <String>{};
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
        if (!declaredStarts.add(id)) {
          issues.add(
            '${questFile.path} [id=<campaign>].initialQuestIds[$index]: '
            'duplicate initial quest "$id"',
          );
        } else {
          starts.add(id);
        }
      }
    }
  } else {
    issues.add(
      '${questFile.path} [id=<campaign>].initialQuestIds: '
      'expected an array of quest IDs',
    );
  }
  _reportPrerequisiteCycles(byId, issues);
  final reachableQuests = _reachableCampaignQuests(byId, starts);
  for (final quest in quests.where(
    (quest) => !reachableQuests.contains(quest.id),
  )) {
    issues.add(
      '${quest.label} [id=${quest.id ?? '<missing>'}]: quest is unreachable '
      'from initial quest(s) '
      '${starts.join(', ')}',
    );
  }
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

Set<String> _reachableCampaignQuests(
  Map<String, _Record> quests,
  Set<String> starts,
) {
  final reachable = <String>{...starts};
  final pending = <String>[...starts];
  for (var cursor = 0; cursor < pending.length; cursor++) {
    final record = quests[pending[cursor]];
    final next = record?.value['nextQuestIds'];
    if (next is! List) continue;
    for (final id in next.whereType<String>()) {
      if (quests.containsKey(id) && reachable.add(id)) pending.add(id);
    }
  }
  return reachable;
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
