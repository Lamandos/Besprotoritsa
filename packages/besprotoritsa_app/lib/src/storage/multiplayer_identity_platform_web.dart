// Platform adapters expose only the internal identity storage API.
// ignore_for_file: public_member_api_docs

import 'package:web/web.dart' as web;

Future<String?> readIdentity(String key) async =>
    web.window.localStorage.getItem(key);

Future<void> writeIdentity(String key, String value) async {
  web.window.localStorage.setItem(key, value);
}
