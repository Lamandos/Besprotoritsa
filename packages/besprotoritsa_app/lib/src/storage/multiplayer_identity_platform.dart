// Platform adapters expose only the internal identity storage API.
// ignore_for_file: public_member_api_docs

export 'multiplayer_identity_platform_stub.dart'
    if (dart.library.js_interop) 'multiplayer_identity_platform_web.dart'
    if (dart.library.io) 'multiplayer_identity_platform_io.dart';
