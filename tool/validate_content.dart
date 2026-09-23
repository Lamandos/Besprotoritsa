import 'dart:io';

import 'validate_schemas.dart';

const _datasets = <({String path, String schema, String recordsKey})>[
  (
    path: 'content/characters.json',
    schema: 'character',
    recordsKey: 'characters',
  ),
  (
    path: 'content/conditions.json',
    schema: 'condition',
    recordsKey: 'cards',
  ),
  (path: 'content/hexes.json', schema: 'hex', recordsKey: 'hexes'),
  (path: 'content/quests.json', schema: 'quest', recordsKey: 'quests'),
  (path: 'content/tasks.json', schema: 'task', recordsKey: 'tasks'),
];

Future<void> main() async {
  var validated = 0;
  for (final dataset in _datasets) {
    final document = await readJsonObject(File(dataset.path));
    final records = document[dataset.recordsKey];
    if (records is! List<Object?>) {
      throw SchemaValidationException(
        '${dataset.path}.${dataset.recordsKey} must be an array.',
      );
    }
    final schema = await readJsonObject(
      File('content/schemas/${dataset.schema}.schema.json'),
    );
    final validator = JsonSchemaValidator(schema);
    for (var index = 0; index < records.length; index++) {
      validator.validate(records[index]);
      validated++;
    }
  }
  stdout.writeln(
    'Validated $validated records across ${_datasets.length} datasets.',
  );
}
