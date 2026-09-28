import 'dart:convert';
import 'dart:io';

import 'validate_schemas.dart';

const _decks = <String, ({String path, String schema})>{
  'monsters': (path: 'content/monsters.json', schema: 'monster'),
  'items': (path: 'content/items.json', schema: 'item'),
  'supplies': (path: 'content/supplies.json', schema: 'supply'),
  'events': (path: 'content/events.json', schema: 'event'),
  'special-items': (
    path: 'content/special_items.json',
    schema: 'special_item',
  ),
};

const _sources = <String, List<String>>{
  'monsters': ['materials/монстры.pdf', 'materials/монстры жетоны.pdf'],
  'events': ['materials/события.pdf'],
};

Future<void> main(List<String> arguments) async {
  final selected = _parseDeck(arguments);
  final deckNames = selected == null ? _decks.keys : [selected];
  for (final name in deckNames) {
    await _report(name, _decks[name]!);
  }
}

String? _parseDeck(List<String> arguments) {
  if (arguments.isEmpty) return null;
  if (arguments.length != 2 || arguments.first != '--deck') {
    throw const FormatException(
      'Usage: dart run tool/content_report.dart [--deck '
      'monsters|items|supplies|events|special-items]',
    );
  }
  final deck = arguments[1];
  if (!_decks.containsKey(deck)) {
    throw FormatException('Unknown deck "$deck". Available: ${_decks.keys}.');
  }
  return deck;
}

Future<void> _report(
  String name,
  ({String path, String schema}) definition,
) async {
  final document = _readObject(definition.path);
  final rawCards = document['cards'];
  if (rawCards is! List) {
    throw FormatException('${definition.path}.cards must be an array.');
  }
  final cards = rawCards.whereType<Map<String, dynamic>>().where((card) {
    return name != 'items' || card['sourceDeck'] == 'items';
  }).toList();
  final schema = JsonSchemaValidator(
    _readObject('content/schemas/${definition.schema}.schema.json'),
  );
  for (final card in cards) {
    schema.validate(card);
  }
  final ids = cards.map((card) => card['id']).toList();
  if (ids.any((id) => id is! String || id.isEmpty) ||
      ids.toSet().length != ids.length) {
    throw FormatException('$name contains missing or duplicate card ids.');
  }

  final copiesByBatch = <String, int>{};
  final recordsByBatch = <String, int>{};
  var physicalCopies = 0;
  for (final card in cards) {
    final copies = card['copies'] ?? 1;
    if (copies is! int || copies < 1) {
      throw FormatException('${card['id']} has invalid copies: $copies.');
    }
    physicalCopies += copies;
    final batch = card['importBatch'];
    final batchName = batch == null ? 'unassigned' : batch.toString();
    recordsByBatch.update(
      batchName,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    copiesByBatch.update(
      batchName,
      (count) => count + copies,
      ifAbsent: () => copies,
    );
  }

  final sourcePaths =
      _sources[name] ??
      [if (document['source'] is String) document['source']! as String];
  final availableSources = sourcePaths
      .where((path) => File(path).existsSync())
      .toList();
  _write('Deck: $name');
  _write('  Dataset: ${definition.path}');
  _write('  Unique card records: ${cards.length}');
  _write('  Physical copies declared: $physicalCopies');
  for (final batch in copiesByBatch.keys.toList()..sort()) {
    _write(
      '  Batch $batch: ${recordsByBatch[batch]} card records, '
      '${copiesByBatch[batch]} physical copies declared',
    );
  }
  _write(
    '  Source PDFs: ${availableSources.length}/${sourcePaths.length} available',
  );
  for (final sourcePath in sourcePaths) {
    _write(
      '    ${File(sourcePath).existsSync() ? 'found' : 'missing'}: $sourcePath',
    );
  }
  if (availableSources.length != sourcePaths.length) {
    _write(
      '  Completeness: source comparison is incomplete because a PDF is '
      'missing.',
    );
  } else {
    _write(
      '  Completeness: PDF sources are available; review card faces against '
      'the declared records and copies.',
    );
  }
}

void _write(String line) => stdout.writeln(line);

Map<String, dynamic> _readObject(String path) {
  final value = jsonDecode(File(path).readAsStringSync());
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must contain a JSON object.');
  }
  return value;
}
