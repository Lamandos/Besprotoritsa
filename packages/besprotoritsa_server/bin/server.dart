import 'dart:io';

import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--healthcheck') {
    await _runHealthCheck();
    return;
  }

  final port = _portFromEnvironment();
  final persistenceDirectory = Directory(
    Platform.environment['PERSISTENCE_DIRECTORY'] ?? '/data',
  );
  await persistenceDirectory.create(recursive: true);

  final manager = RoomManager(persistenceDirectory: persistenceDirectory);
  final server = await shelf_io.serve(
    manager.handler,
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('Besprotoritsa server listening on port ${server.port}.');

  await ProcessSignal.sigterm.watch().first;
  await server.close();
}

int _portFromEnvironment() {
  final value = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(value);
  if (port == null || port < 1 || port > 65535) {
    throw const FormatException('PORT must be an integer between 1 and 65535.');
  }
  return port;
}

Future<void> _runHealthCheck() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _portFromEnvironment(),
        path: '/healthz',
      ),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) exitCode = 1;
  } on SocketException {
    exitCode = 1;
  } on HttpException {
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
