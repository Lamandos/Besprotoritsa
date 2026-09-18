import 'dart:convert';
import 'dart:io';

const _draft202012 = 'https://json-schema.org/draft/2020-12/schema';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    final count = await validateSchemaFiles(Directory('content/schemas'));
    stdout.writeln('Validated $count schema file(s).');
    return;
  }

  if (arguments.length == 4 &&
      arguments[0] == '--schema' &&
      arguments[2] == '--data') {
    await validateDataFile(
      schemaFile: File(arguments[1]),
      dataFile: File(arguments[3]),
    );
    stdout.writeln('Content data is valid.');
    return;
  }

  throw const SchemaValidationException(
    'Usage: dart run tool/validate_schemas.dart '
    '[--schema <schema.json> --data <content.json>]',
  );
}

Future<int> validateSchemaFiles(Directory directory) async {
  if (!directory.existsSync()) {
    throw SchemaValidationException(
      'Schema directory not found: ${directory.path}',
    );
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.schema.json'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));

  if (files.isEmpty) {
    throw SchemaValidationException(
      'No schema files found in ${directory.path}.',
    );
  }

  for (final file in files) {
    validateSchemaDefinition(await readJsonObject(file), file.path);
  }
  return files.length;
}

Future<void> validateDataFile({
  required File schemaFile,
  required File dataFile,
}) async {
  final schema = await readJsonObject(schemaFile);
  validateSchemaDefinition(schema, schemaFile.path);
  final data = await readJsonValue(dataFile);
  JsonSchemaValidator(schema).validate(data);
}

Future<Map<String, Object?>> readJsonObject(File file) async {
  final value = await readJsonValue(file);
  if (value is! Map<String, Object?>) {
    throw SchemaValidationException('${file.path}: expected a JSON object.');
  }
  return value;
}

Future<Object?> readJsonValue(File file) async {
  try {
    return _convertJsonValue(jsonDecode(await file.readAsString()));
  } on FileSystemException catch (error) {
    throw SchemaValidationException('Cannot read ${file.path}: $error');
  } on FormatException catch (error) {
    throw SchemaValidationException('Invalid JSON in ${file.path}: $error');
  }
}

Object? _convertJsonValue(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>(
      (key, entry) => MapEntry(key as String, _convertJsonValue(entry)),
    );
  }
  if (value is List) {
    return value.map(_convertJsonValue).toList();
  }
  return value;
}

void validateSchemaDefinition(Map<String, Object?> schema, String source) {
  _expect(
    schema[r'$schema'] == _draft202012,
    source,
    'must declare Draft 2020-12',
  );
  _expect(schema[r'$id'] is String, source, r'must declare a string $id');
  _validateSchemaNode(schema, source);
}

void _validateSchemaNode(Map<String, Object?> node, String source) {
  final type = node['type'];
  if (type != null) {
    _expect(type is String, source, '"type" must be a string');
  }
  final required = node['required'];
  if (required != null) {
    _expect(
      required is List && required.every((entry) => entry is String),
      source,
      '"required" must be a list of strings',
    );
  }
  final properties = node['properties'];
  if (properties is Map<String, Object?>) {
    for (final child in properties.values) {
      if (child is! Map<String, Object?>) {
        throw SchemaValidationException(
          '$source: a property schema must be an object.',
        );
      }
      _validateSchemaNode(child, source);
    }
  } else if (properties != null) {
    throw SchemaValidationException('$source: "properties" must be an object.');
  }
  _validateNestedSchema(node['items'], source, '"items"');
  _validateNestedSchema(
    node['additionalProperties'],
    source,
    '"additionalProperties"',
  );
  final defs = node[r'$defs'];
  if (defs is Map<String, Object?>) {
    for (final child in defs.values) {
      if (child is! Map<String, Object?>) {
        throw SchemaValidationException(
          '$source: a definition must be an object.',
        );
      }
      _validateSchemaNode(child, source);
    }
  } else if (defs != null) {
    throw SchemaValidationException('$source: \$defs must be an object.');
  }
}

void _validateNestedSchema(Object? value, String source, String keyword) {
  if (value == null || value is bool) {
    return;
  }
  if (value is Map<String, Object?>) {
    _validateSchemaNode(value, source);
    return;
  }
  throw SchemaValidationException(
    '$source: $keyword must be an object or boolean.',
  );
}

void _expect(bool condition, String source, String message) {
  if (!condition) {
    throw SchemaValidationException('$source: $message.');
  }
}

final class JsonSchemaValidator {
  JsonSchemaValidator(this._rootSchema);

  final Map<String, Object?> _rootSchema;

  void validate(Object? value) => _validate(value, _rootSchema, r'$');

  void _validate(Object? value, Map<String, Object?> schema, String path) {
    final reference = schema[r'$ref'];
    if (reference != null) {
      _validate(value, _resolveReference(reference, path), path);
      return;
    }
    _validateEnum(value, schema['enum'], path);
    _validateType(value, schema['type'], path);
    _validateNumbers(value, schema, path);
    _validateString(value, schema['pattern'], path);
    _validateObject(value, schema, path);
    _validateArray(value, schema, path);
  }

  Map<String, Object?> _resolveReference(Object? reference, String path) {
    if (reference is! String || !reference.startsWith(r'#/$defs/')) {
      throw SchemaValidationException(
        '$path: unsupported reference $reference.',
      );
    }
    final name = reference.substring(r'#/$defs/'.length);
    final definitions = _rootSchema[r'$defs'];
    if (definitions is! Map<String, Object?> ||
        definitions[name] is! Map<String, Object?>) {
      throw SchemaValidationException(
        '$path: unresolved reference $reference.',
      );
    }
    return definitions[name]! as Map<String, Object?>;
  }

  void _validateEnum(Object? value, Object? values, String path) {
    if (values is List && !values.contains(value)) {
      throw SchemaValidationException(
        '$path: expected one of $values, got $value.',
      );
    }
  }

  void _validateType(Object? value, Object? type, String path) {
    if (type is String && !_matchesType(value, type)) {
      throw SchemaValidationException(
        '$path: expected $type, got ${_typeName(value)}.',
      );
    }
  }

  bool _matchesType(Object? value, String type) => switch (type) {
    'object' => value is Map<String, Object?>,
    'array' => value is List,
    'string' => value is String,
    'boolean' => value is bool,
    'integer' => value is int,
    'number' => value is num,
    _ => false,
  };

  String _typeName(Object? value) => switch (value) {
    null => 'null',
    String() => 'string',
    bool() => 'boolean',
    int() => 'integer',
    num() => 'number',
    List() => 'array',
    Map() => 'object',
    _ => value.runtimeType.toString(),
  };

  void _validateNumbers(
    Object? value,
    Map<String, Object?> schema,
    String path,
  ) {
    if (value is! num) {
      return;
    }
    final minimum = schema['minimum'];
    final maximum = schema['maximum'];
    if (minimum is num && value < minimum) {
      throw SchemaValidationException('$path: must be at least $minimum.');
    }
    if (maximum is num && value > maximum) {
      throw SchemaValidationException('$path: must be at most $maximum.');
    }
  }

  void _validateString(Object? value, Object? pattern, String path) {
    if (value is String &&
        pattern is String &&
        !RegExp(pattern).hasMatch(value)) {
      throw SchemaValidationException('$path: does not match $pattern.');
    }
  }

  void _validateObject(
    Object? value,
    Map<String, Object?> schema,
    String path,
  ) {
    if (value is! Map<String, Object?>) {
      return;
    }
    final required = schema['required'];
    if (required is List) {
      for (final name in required.cast<String>()) {
        if (!value.containsKey(name)) {
          throw SchemaValidationException(
            '$path: missing required property $name.',
          );
        }
      }
    }
    final properties = schema['properties'] as Map<String, Object?>?;
    final additional = schema['additionalProperties'];
    for (final entry in value.entries) {
      final propertySchema = properties?[entry.key];
      if (propertySchema is Map<String, Object?>) {
        _validate(entry.value, propertySchema, '$path.${entry.key}');
      } else if (additional is Map<String, Object?>) {
        _validate(entry.value, additional, '$path.${entry.key}');
      } else if (additional == false) {
        throw SchemaValidationException(
          '$path: unexpected property ${entry.key}.',
        );
      }
    }
  }

  void _validateArray(Object? value, Map<String, Object?> schema, String path) {
    if (value is! List) {
      return;
    }
    final minItems = schema['minItems'];
    if (minItems is int && value.length < minItems) {
      throw SchemaValidationException(
        '$path: requires at least $minItems item(s).',
      );
    }
    if (schema['uniqueItems'] == true && value.toSet().length != value.length) {
      throw SchemaValidationException('$path: items must be unique.');
    }
    final itemSchema = schema['items'];
    if (itemSchema is Map<String, Object?>) {
      for (var index = 0; index < value.length; index++) {
        _validate(value[index], itemSchema, '$path[$index]');
      }
    }
  }
}

final class SchemaValidationException implements Exception {
  const SchemaValidationException(this.message);

  final String message;

  @override
  String toString() => 'SchemaValidationException: $message';
}
