// Async identity writes keep this adapter from blocking the Flutter UI.
// ignore_for_file: avoid_slow_async_io, public_member_api_docs

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> readIdentity(String key) async {
  final file = await _file(key);
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeIdentity(String key, String value) async {
  final file = await _file(key);
  await file.parent.create(recursive: true);
  await file.writeAsString(value, flush: true);
}

Future<File> _file(String key) async {
  final directory = await getApplicationSupportDirectory();
  final filename = base64Url.encode(utf8.encode(key));
  return File('${directory.path}/network/$filename.json');
}
