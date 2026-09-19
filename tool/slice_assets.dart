import 'dart:async';
import 'dart:io';

const _defaultOutput = 'packages/besprotoritsa_app/assets/images';
const _supportedExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.svg',
  '.webp',
  '.pdf',
};

Future<void> main(List<String> arguments) async {
  final options = SliceOptions.parse(arguments);
  if (options.help) {
    stdout.write(SliceOptions.usage);
    return;
  }

  final inputs = await _inputFiles(options.input);
  if (inputs.isEmpty) {
    throw StateError('No supported source files found at ${options.input}.');
  }

  final outputDirectory = Directory(
    '${options.output}${Platform.pathSeparator}${options.kind.directoryName}',
  )..createSync(recursive: true);
  var generated = 0;
  for (final input in inputs) {
    generated += await _sliceSource(input, outputDirectory, options);
  }
  stdout.writeln(
    'Generated $generated WebP assets in ${outputDirectory.path}.',
  );
}

Future<List<File>> _inputFiles(String inputPath) async {
  final input = FileSystemEntity.typeSync(inputPath);
  if (input == FileSystemEntityType.file) {
    final file = File(inputPath);
    return _isSupported(file) ? <File>[file] : <File>[];
  }
  if (input != FileSystemEntityType.directory) return const <File>[];

  final files = await Directory(inputPath)
      .list(recursive: true)
      .where((entity) => entity is File)
      .map((entity) => File(entity.path))
      .where(_isSupported)
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

bool _isSupported(File file) =>
    _supportedExtensions.contains(_extensionOf(file.path));

Future<int> _sliceSource(
  File source,
  Directory outputDirectory,
  SliceOptions options,
) async {
  if (_extensionOf(source.path) != '.pdf') {
    await _encodeGrid(source, outputDirectory, _stemOf(source.path), options);
    return options.columns * options.rows;
  }

  final temporaryDirectory = await Directory.systemTemp.createTemp(
    'besprotoritsa-pages-',
  );
  try {
    final prefix = '${temporaryDirectory.path}/page';
    await _run('pdftoppm', <String>[
      '-png',
      '-r',
      '${options.pdfDpi}',
      source.path,
      prefix,
    ]);
    final pages = await _inputFiles(temporaryDirectory.path);
    var generated = 0;
    for (var index = 0; index < pages.length; index++) {
      final pageName = '${_stemOf(source.path)}-page-${_twoDigits(index + 1)}';
      await _encodeGrid(pages[index], outputDirectory, pageName, options);
      generated += options.columns * options.rows;
    }
    return generated;
  } finally {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

Future<void> _encodeGrid(
  File source,
  Directory outputDirectory,
  String sourceName,
  SliceOptions options,
) async {
  final temporaryDirectory = await Directory.systemTemp.createTemp(
    'besprotoritsa-tile-',
  );
  try {
    for (var row = 0; row < options.rows; row++) {
      for (var column = 0; column < options.columns; column++) {
        final tileNumber = row * options.columns + column + 1;
        final output = File(
          '${outputDirectory.path}${Platform.pathSeparator}'
          '$sourceName-${_twoDigits(tileNumber)}.webp',
        );
        final intermediate = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}'
          'tile-${_twoDigits(tileNumber)}.png',
        );
        final crop =
            'crop=iw/${options.columns}:ih/${options.rows}:'
            '$column*iw/${options.columns}:'
            '$row*ih/${options.rows}';
        final filters = <String>[crop];
        if (options.maxSize != null) {
          filters.add(
            'scale=w=${options.maxSize}:h=${options.maxSize}:'
            'force_original_aspect_ratio=decrease',
          );
        }
        await _run('ffmpeg', <String>[
          '-hide_banner',
          '-loglevel',
          'error',
          '-y',
          '-i',
          source.path,
          '-frames:v',
          '1',
          '-vf',
          filters.join(','),
          intermediate.path,
        ]);
        await _run('cwebp', <String>[
          '-quiet',
          '-q',
          '${options.quality}',
          '-m',
          '6',
          '-preset',
          'picture',
          intermediate.path,
          '-o',
          output.path,
        ]);
      }
    }
  } finally {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode == 0) return;
  final details = result.stderr.toString().trim();
  throw ProcessException(executable, arguments, details, result.exitCode);
}

String _extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}

String _stemOf(String path) {
  final fileName = path.split(Platform.pathSeparator).last;
  final dot = fileName.lastIndexOf('.');
  return dot < 0 ? fileName : fileName.substring(0, dot);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

enum SliceKind {
  tiles('tiles'),
  monsterTokens('monster-tokens'),
  cardIcons('card-icons');

  const SliceKind(this.directoryName);

  final String directoryName;

  static SliceKind parse(String value) => switch (value) {
    'tiles' => SliceKind.tiles,
    'monster-tokens' => SliceKind.monsterTokens,
    'card-icons' => SliceKind.cardIcons,
    _ => throw FormatException(
      'Unknown --kind "$value". Use tiles, monster-tokens, or card-icons.',
    ),
  };
}

final class SliceOptions {
  const SliceOptions({
    required this.input,
    required this.output,
    required this.kind,
    required this.columns,
    required this.rows,
    required this.quality,
    required this.maxSize,
    required this.pdfDpi,
    required this.help,
  });

  factory SliceOptions.parse(List<String> arguments) {
    final values = <String, String>{};
    var help = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help' || argument == '-h') {
        help = true;
        continue;
      }
      if (!argument.startsWith('--') || index + 1 >= arguments.length) {
        throw const FormatException('Every option needs a value. Use --help.');
      }
      values[argument.substring(2)] = arguments[++index];
    }
    if (help) {
      return const SliceOptions(
        input: '',
        output: _defaultOutput,
        kind: SliceKind.tiles,
        columns: 1,
        rows: 1,
        quality: 82,
        maxSize: null,
        pdfDpi: 180,
        help: true,
      );
    }

    final input = values['input'];
    final kind = values['kind'];
    if (input == null || kind == null) {
      throw const FormatException(
        '--input and --kind are required. Use --help for examples.',
      );
    }
    final columns = _positiveInt(values, 'columns', 1);
    final rows = _positiveInt(values, 'rows', 1);
    final quality = _boundedInt(values, 'quality', 82, 1, 100);
    final maxSize = values['max-size'] == null
        ? null
        : _positiveInt(values, 'max-size', 0);
    return SliceOptions(
      input: input,
      output: values['output'] ?? _defaultOutput,
      kind: SliceKind.parse(kind),
      columns: columns,
      rows: rows,
      quality: quality,
      maxSize: maxSize,
      pdfDpi: _positiveInt(values, 'pdf-dpi', 180),
      help: false,
    );
  }

  static const usage = r'''
Asset slicing pipeline

Usage:
  dart run tool/slice_assets.dart --input <file-or-directory> --kind <kind>
      [--columns <n>] [--rows <n>] [--quality <1..100>]
      [--max-size <px>] [--pdf-dpi <dpi>] [--output <directory>]

Kinds: tiles, monster-tokens, card-icons
Input: PNG/JPEG/WebP/SVG raster sources or PDF pages.
Output: packages/besprotoritsa_app/assets/images/<kind>/*.webp

Example:
  dart run tool/slice_assets.dart --input tmp/pdfs/tokens-1.jpg \
    --kind monster-tokens --columns 4 --rows 4 --max-size 512
''';

  final String input;
  final String output;
  final SliceKind kind;
  final int columns;
  final int rows;
  final int quality;
  final int? maxSize;
  final int pdfDpi;
  final bool help;
}

int _positiveInt(Map<String, String> values, String name, int fallback) {
  final value = values[name] == null ? fallback : int.tryParse(values[name]!);
  if (value == null || value < 1) {
    throw FormatException('--$name must be a positive integer.');
  }
  return value;
}

int _boundedInt(
  Map<String, String> values,
  String name,
  int fallback,
  int minimum,
  int maximum,
) {
  final value = values[name] == null ? fallback : int.tryParse(values[name]!);
  if (value == null || value < minimum || value > maximum) {
    throw FormatException('--$name must be between $minimum and $maximum.');
  }
  return value;
}
