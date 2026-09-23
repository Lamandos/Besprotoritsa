// Platform adapters expose only the internal identity storage API.
// ignore_for_file: public_member_api_docs

Future<String?> readIdentity(String key) async => null;

Future<void> writeIdentity(String key, String value) async {
  throw UnsupportedError('Network identity storage is unavailable.');
}
