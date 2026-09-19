import 'package:besprotoritsa_app/src/storage/platform_game_storage_stub.dart'
    if (dart.library.js_interop) 'package:besprotoritsa_app/src/storage/web_local_storage_game_storage.dart'
    if (dart.library.io) 'package:besprotoritsa_app/src/storage/file_game_storage.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';

/// Creates the storage backend appropriate for the running Flutter platform.
GameStorage createPlatformGameStorage() => createGameStorage();
