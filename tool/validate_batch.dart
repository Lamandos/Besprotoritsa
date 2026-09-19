import 'dart:convert';
import 'dart:io';

import 'validate_schemas.dart';

Future<void> main(List<String> arguments) async {
  final request = BatchRequest.parse(arguments);
  if (request.deck != 'monsters') {
    throw const FormatException('Only the monsters deck is supported.');
  }

  final document = await _readObject('content/monsters.json');
  final cards = _cardsForBatch(document, request.batch);
  _require(cards.length == 10, 'Batch ${request.batch} must contain 10 cards.');
  _requireUniqueIds(cards);
  await _validateCards(cards);
  await _validateTranslations(cards);
  stdout.writeln(
    'Validated monsters batch ${request.batch}: ${cards.length} card types.',
  );
}

Future<Map<String, Object?>> _readObject(String path) async {
  final value = jsonDecode(await File(path).readAsString());
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must contain a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _cardsForBatch(
  Map<String, Object?> document,
  int batch,
) {
  final rawCards = document['cards'];
  if (rawCards is! List<dynamic>) {
    throw const FormatException(
      'content/monsters.json must have a cards array.',
    );
  }
  return [
    for (final rawCard in rawCards)
      if (rawCard is Map<String, dynamic> && rawCard['importBatch'] == batch)
        Map<String, Object?>.from(rawCard),
  ];
}

void _requireUniqueIds(List<Map<String, Object?>> cards) {
  final ids = cards.map((card) => card['id']).toList();
  _require(
    ids.every((id) => id is String && id.isNotEmpty),
    'Every card needs an id.',
  );
  _require(
    ids.toSet().length == ids.length,
    'Card ids in a batch must be unique.',
  );
}

Future<void> _validateCards(List<Map<String, Object?>> cards) async {
  final schema = await readJsonObject(
    File('content/schemas/monster.schema.json'),
  );
  final validator = JsonSchemaValidator(schema);
  for (final card in cards) {
    validator.validate(card);
  }
}

Future<void> _validateTranslations(List<Map<String, Object?>> cards) async {
  final translations = await _readObject('content/i18n/ru.json');
  for (final card in cards) {
    for (final field in const ['nameKey', 'descKey']) {
      final key = card[field];
      _require(
        key is String && _hasTranslation(translations, key),
        'Missing Russian translation for $key.',
      );
    }
  }
}

bool _hasTranslation(Map<String, Object?> translations, String key) {
  Object? current = translations;
  for (final segment in key.split('.')) {
    if (current is! Map<String, Object?>) return false;
    current = current[segment];
  }
  return current is String;
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

final class BatchRequest {
  const BatchRequest({required this.deck, required this.batch});

  factory BatchRequest.parse(List<String> arguments) {
    if (arguments.length != 4 ||
        arguments[0] != '--deck' ||
        arguments[2] != '--batch') {
      throw const FormatException(
        'Usage: dart run tool/validate_batch.dart --deck <deck> --batch <number>',
      );
    }
    final batch = int.tryParse(arguments[3]);
    if (batch == null || batch < 1) {
      throw const FormatException('Batch must be a positive integer.');
    }
    return BatchRequest(deck: arguments[1], batch: batch);
  }

  final String deck;
  final int batch;
}
