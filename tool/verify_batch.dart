import 'dart:convert';
import 'dart:io';

import 'validate_schemas.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2 || arguments.first != '--deck') {
    throw const FormatException(
      'Usage: dart run tool/verify_batch.dart --deck <items|supplies>',
    );
  }
  final deck = arguments[1];
  final path = 'content/$deck.json';
  final schemaPath =
      'content/schemas/${deck == 'items' ? 'item' : 'supply'}.schema.json';
  final decoded = jsonDecode(await File(path).readAsString());
  if (decoded is! Map<String, dynamic> || decoded['cards'] is! List<dynamic>) {
    throw FormatException('$path must contain a cards array.');
  }
  final cards = decoded['cards']! as List<dynamic>;
  final schema = await readJsonObject(File(schemaPath));
  final validator = JsonSchemaValidator(schema);
  final translations =
      jsonDecode(
            await File('content/i18n/ru.json').readAsString(),
          )
          as Map<String, dynamic>;
  final ids = <String>{};
  final batches = <int, int>{};
  for (final raw in cards) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Every card must be an object.');
    }
    final card = Map<String, Object?>.from(raw);
    validator.validate(card);
    _validateBehaviorIds(card, await _registeredBehaviorIds());
    final id = card['id']! as String;
    if (!ids.add(id)) throw FormatException('Duplicate card id: $id');
    final batch = card['importBatch']! as int;
    batches.update(batch, (count) => count + 1, ifAbsent: () => 1);
    for (final field in const ['nameKey', 'descKey']) {
      if (!_hasTranslation(translations, card[field]! as String)) {
        throw FormatException(
          'Missing Russian translation for ${card[field]}.',
        );
      }
    }
  }
  for (final entry in batches.entries) {
    if (entry.value > 10) {
      throw FormatException('Batch ${entry.key} has more than 10 cards.');
    }
  }
  await _validateGlobalBatchSizes();
  stdout.writeln(
    'Validated $deck: ${cards.length} cards in ${batches.length} batches.',
  );
}

void _validateBehaviorIds(
  Map<String, Object?> card,
  Set<String> registered,
) {
  final ids = <String>[
    if (card['behaviorId'] case final String behaviorId) behaviorId,
    if (card['behaviorIds'] case final List<dynamic> behaviorIds)
      ...behaviorIds.whereType<String>(),
  ];
  for (final behaviorId in ids) {
    if (!registered.contains(behaviorId)) {
      throw FormatException(
        '${card['id']} references unregistered behaviorId $behaviorId.',
      );
    }
  }
}

Set<String>? _behaviorIds;

Future<Set<String>> _registeredBehaviorIds() async {
  final cached = _behaviorIds;
  if (cached != null) return cached;
  final document = jsonDecode(
    await File('content/effects_inventory.json').readAsString(),
  );
  if (document is! Map<String, dynamic> || document['behaviors'] is! List) {
    throw const FormatException(
      'content/effects_inventory.json must contain behaviors.',
    );
  }
  final ids = <String>{};
  for (final raw in document['behaviors']! as List<dynamic>) {
    if (raw is Map<String, dynamic> && raw['behaviorId'] is String) {
      ids.add(raw['behaviorId']! as String);
    }
  }
  if (ids.isEmpty) {
    throw const FormatException('No behaviorIds found in effects inventory.');
  }
  return _behaviorIds = ids;
}

Future<void> _validateGlobalBatchSizes() async {
  final counts = <int, int>{};
  for (final path in const ['content/items.json', 'content/supplies.json']) {
    if (!File(path).existsSync()) {
      continue;
    }
    final document = jsonDecode(await File(path).readAsString());
    if (document is! Map<String, dynamic> || document['cards'] is! List) {
      throw FormatException('$path must contain a cards array.');
    }
    for (final raw in document['cards']! as List<dynamic>) {
      final batch = (raw as Map<String, dynamic>)['importBatch'];
      if (batch is! int) {
        throw FormatException('$path card has no importBatch.');
      }
      counts.update(batch, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final batches = counts.keys.toList()..sort();
  for (var index = 0; index < batches.length; index++) {
    final batch = batches[index];
    if (batch != index + 1) {
      throw FormatException('Missing import batch ${index + 1}.');
    }
    final isFinal = index == batches.length - 1;
    if ((!isFinal && counts[batch] != 10) || (isFinal && counts[batch]! > 10)) {
      throw FormatException(
        'Import batch $batch must contain 10 cards, except the final '
        'remainder.',
      );
    }
  }
}

bool _hasTranslation(Map<String, dynamic> root, String key) {
  dynamic current = root;
  for (final segment in key.split('.')) {
    if (current is! Map<String, dynamic>) return false;
    current = current[segment];
  }
  return current is String;
}
