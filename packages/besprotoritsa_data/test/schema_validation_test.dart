import 'dart:io';

import 'package:test/test.dart';
import '../../../tool/validate_schemas.dart' as schema_tool;

void main() {
  group('content schema validation', () {
    test('accepts every checked-in schema definition', () async {
      final count = await schema_tool.validateSchemaFiles(
        Directory('content/schemas'),
      );

      expect(count, 10);
    });

    test('rejects content with a value of the wrong type', () async {
      await expectLater(
        schema_tool.validateDataFile(
          schemaFile: File('content/schemas/character.schema.json'),
          dataFile: File(
            'packages/besprotoritsa_data/test/fixtures/invalid_character.json',
          ),
        ),
        throwsA(
          isA<schema_tool.SchemaValidationException>().having(
            (error) => error.message,
            'message',
            contains(r'$.health: expected integer'),
          ),
        ),
      );
    });
  });
}
