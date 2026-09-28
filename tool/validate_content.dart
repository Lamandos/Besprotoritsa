import 'dart:io';

import 'content_validator.dart';

Future<void> main(List<String> arguments) async {
  var contentSetId = 'mvp';
  if (arguments.length == 2 && arguments[0] == '--content-set') {
    contentSetId = arguments[1];
  } else if (arguments.isNotEmpty) {
    stderr.writeln(
      'Usage: dart run tool/validate_content.dart [--content-set <id>]',
    );
    exitCode = 64;
    return;
  }

  final report = await validateContent(
    contentDirectory: Directory('content'),
    contentSetId: contentSetId,
  );
  if (!report.isValid) {
    for (final issue in report.issues) {
      stderr.writeln('ERROR $issue');
    }
    stderr.writeln(
      'Content validation failed: ${report.issues.length} issue(s), '
      '${report.records} records inspected (contentSetId=$contentSetId).',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Validated ${report.records} catalog and selected-set records '
    '(contentSetId=$contentSetId); references, translations, schemas, '
    'effects and campaign reachability are valid.',
  );
}
