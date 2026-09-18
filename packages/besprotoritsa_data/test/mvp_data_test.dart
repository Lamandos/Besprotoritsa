import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../../../tool/validate_schemas.dart' as schema_tool;

const _mvp = 'content/mvp';

void main() {
  group('MVP dataset', () {
    late Map<String, Map<String, Object?>> data;

    setUpAll(() async {
      data = await _readMvpData();
    });

    test('validates every entity against its step 04 schema', () async {
      for (final entry in _schemaForDataPath.entries) {
        await schema_tool.validateDataFile(
          schemaFile: File('content/schemas/${entry.value}.schema.json'),
          dataFile: File(entry.key),
        );
      }
    });

    test('has the documented characters and their start equipment', () {
      final guard = data['$_mvp/characters/guard.json']!;
      final engineer = data['$_mvp/characters/engineer.json']!;

      expect(
        _stats(guard),
        equals({
          'health': 11,
          'strength': 3,
          'combatStrength': 3,
          'science': 1,
          'repair': 1,
          'endurance': 3,
          'agility': 3,
        }),
      );
      expect(
        _stats(engineer),
        equals({
          'health': 10,
          'strength': 3,
          'combatStrength': 3,
          'science': 2,
          'repair': 3,
          'endurance': 2,
          'agility': 1,
        }),
      );
      expect(guard['startItems'], equals(['pistol']));
      expect(guard['startCredits'], 3);
      expect(engineer['startItems'], equals(['gu4-rd']));
      expect(engineer['startCredits'], 3);
    });

    test('has a connected fixed layout with matching HexEdge ports', () async {
      final layout = await _readJsonObject('$_mvp/layout.json');
      final coordinates = layout['coordinates']! as List<Object?>;
      final positions = <String, Map<String, Object?>>{};

      for (final coordinate in coordinates) {
        final position = Map<String, Object?>.from(
          coordinate! as Map<String, dynamic>,
        );
        positions[_coordinateKey(
              position['q']! as int,
              position['r']! as int,
            )] =
            data['$_mvp/hexes/${position['hexId']}.json']!;
      }

      expect(positions.keys, unorderedEquals(['0,0', '0,1', '0,2']));
      expect(positions['0,0']!['type'], 'start');
      expect(positions['0,0']!['exits'], equals([3]));
      expect(positions['0,1']!['type'], 'corridor');
      expect(positions['0,1']!['exits'], equals([0, 3]));
      expect(positions['0,2']!['type'], 'compartment');
      expect(positions['0,2']!['id'], 'crew-mess');
      expect(positions['0,2']!['hasTerminal'], isFalse);
      expect(positions['0,2']!['ventColor'], 'none');

      _expectMatchingPorts(positions);
      expect(
        _reachablePositions(positions, '0,0'),
        equals(positions.keys.toSet()),
      );
    });

    test('keeps the MVP quest, event, monster, and conditions linked', () {
      final quest = data['$_mvp/quests/chapter-1-awakening.json']!;
      final event = data['$_mvp/events/cabin-noise.json']!;
      final ghoul = data['$_mvp/monsters/ghoul.json']!;

      expect(quest['chapter'], 1);
      expect(quest['targetLocation'], 'crew-mess');
      expect(quest['conditions'], equals(['science-check']));
      expect(quest['nextQuestIds'], isEmpty);
      expect(event['options'], isNotEmpty);
      final option =
          (event['options']! as List<Object?>).single! as Map<String, dynamic>;
      expect(
        option['skillCheck'],
        equals({'skill': 'agility', 'difficulty': 1}),
      );
      expect(option['successKey'], isNotEmpty);
      expect(option['failureKey'], isNotEmpty);
      expect(
        _stats(ghoul, const ['health', 'defense', 'attack', 'movement']),
        equals({'health': 2, 'defense': 0, 'attack': 2, 'movement': 1}),
      );
      expect(data['$_mvp/conditions/malaise.json']!['statModifiers'], {
        'strength': -1,
      });
      expect(data['$_mvp/conditions/concussion.json']!['statModifiers'], {
        'repair': -1,
      });
    });

    test('resolves every referenced localization string', () async {
      final translations = <String, String>{};
      _collectTranslations(
        await _readJsonObject('$_mvp/i18n_ru.json'),
        '',
        translations,
      );

      for (final entry in data.entries) {
        for (final key in _localizationFields) {
          final localizationKey = entry.value[key];
          if (localizationKey is String) {
            expect(
              translations[localizationKey],
              isNotEmpty,
              reason: entry.key,
            );
          }
        }
        final options = entry.value['options'];
        if (options is List<Object?>) {
          for (final option in options.cast<Map<String, dynamic>>()) {
            for (final key in _eventLocalizationFields) {
              expect(
                translations[option[key] as String],
                isNotEmpty,
                reason: entry.key,
              );
            }
          }
        }
      }
    });
  });
}

const _schemaForDataPath = {
  'content/mvp/characters/guard.json': 'character',
  'content/mvp/characters/engineer.json': 'character',
  'content/mvp/items/pistol.json': 'item',
  'content/mvp/items/gu4-rd.json': 'item',
  'content/mvp/hexes/anabiosis.json': 'hex',
  'content/mvp/hexes/corridor.json': 'hex',
  'content/mvp/hexes/crew-mess.json': 'hex',
  'content/mvp/monsters/ghoul.json': 'monster',
  'content/mvp/conditions/malaise.json': 'condition',
  'content/mvp/conditions/concussion.json': 'condition',
  'content/mvp/events/cabin-noise.json': 'event',
  'content/mvp/quests/chapter-1-awakening.json': 'quest',
};

const _localizationFields = [
  'diaryKey',
  'nameKey',
  'descKey',
  'locationNameKey',
];
const _eventLocalizationFields = [
  'actionKey',
  'successKey',
  'failureKey',
];

Future<Map<String, Map<String, Object?>>> _readMvpData() async {
  final data = <String, Map<String, Object?>>{};
  for (final path in _schemaForDataPath.keys) {
    data[path] = await _readJsonObject(path);
  }
  return data;
}

Future<Map<String, Object?>> _readJsonObject(String path) async {
  final decoded = jsonDecode(await File(path).readAsString());
  return Map<String, Object?>.from(decoded as Map<String, dynamic>);
}

Map<String, int> _stats(
  Map<String, Object?> entity, [
  List<String> names = const [
    'health',
    'strength',
    'combatStrength',
    'science',
    'repair',
    'endurance',
    'agility',
  ],
]) => {for (final name in names) name: entity[name]! as int};

void _expectMatchingPorts(Map<String, Map<String, Object?>> positions) {
  for (final entry in positions.entries) {
    final coordinate = entry.key.split(',').map(int.parse).toList();
    final exits = entry.value['exits']! as List<Object?>;
    for (final exit in exits.cast<int>()) {
      final neighbor = _neighborKey(coordinate[0], coordinate[1], exit);
      expect(
        positions[neighbor],
        isNotNull,
        reason: '${entry.key}:$exit has no neighbor',
      );
      final opposite = (exit + 3) % 6;
      expect(
        positions[neighbor]!['exits'],
        contains(opposite),
        reason: '${entry.key}:$exit does not match $neighbor:$opposite',
      );
    }
  }
}

Set<String> _reachablePositions(
  Map<String, Map<String, Object?>> positions,
  String start,
) {
  final visited = <String>{start};
  final pending = <String>[start];
  while (pending.isNotEmpty) {
    final position = pending.removeLast();
    for (final edge in positions[position]!['exits']! as List<Object?>) {
      final coordinate = position.split(',').map(int.parse).toList();
      final neighbor = _neighborKey(coordinate[0], coordinate[1], edge! as int);
      if (visited.add(neighbor)) {
        pending.add(neighbor);
      }
    }
  }
  return visited;
}

String _coordinateKey(int q, int r) => '$q,$r';

String _neighborKey(int q, int r, int edge) => switch (edge) {
  0 => _coordinateKey(q, r - 1),
  1 => _coordinateKey(q + 1, r - 1),
  2 => _coordinateKey(q + 1, r),
  3 => _coordinateKey(q, r + 1),
  4 => _coordinateKey(q - 1, r + 1),
  5 => _coordinateKey(q - 1, r),
  _ => throw ArgumentError.value(edge, 'edge', 'must be in 0..5'),
};

void _collectTranslations(
  Object? value,
  String prefix,
  Map<String, String> result,
) {
  if (value is String) {
    result[prefix] = value;
  } else if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      final childPrefix = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      _collectTranslations(entry.value, childPrefix, result);
    }
  }
}
