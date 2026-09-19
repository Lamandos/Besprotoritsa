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
    if (raw is! Map<String, dynamic>)
      throw FormatException('Every card must be an object.');
    final card = Map<String, Object?>.from(raw);
    validator.validate(card);
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
    if (entry.value > 10)
      throw FormatException('Batch ${entry.key} has more than 10 cards.');
  }
  stdout.writeln(
    'Validated $deck: ${cards.length} cards in ${batches.length} batches.',
  );
}

bool _hasTranslation(Map<String, dynamic> root, String key) {
  dynamic current = root;
  for (final segment in key.split('.')) {
    if (current is! Map<String, dynamic>) return false;
    current = current[segment];
  }
  return current is String;
}
