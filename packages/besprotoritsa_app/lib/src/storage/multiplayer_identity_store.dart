// Public data is documented by this storage facade.
// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:besprotoritsa_app/src/storage/multiplayer_identity_platform.dart'
    as platform;

/// A reconnect identity for one server and room.
class MultiplayerIdentity {
  const MultiplayerIdentity({required this.participantId, this.reconnectToken});

  final String participantId;
  final String? reconnectToken;
}

/// Persists client identity so a restarted app can reclaim its network seat.
abstract final class MultiplayerIdentityStore {
  static String _key(Uri serverUri, String roomCode) =>
      'multiplayer.${base64Url.encode(utf8.encode('$serverUri|$roomCode'))}';

  static Future<MultiplayerIdentity?> load(
    Uri serverUri,
    String roomCode,
  ) async {
    final value = await platform.readIdentity(_key(serverUri, roomCode));
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> || json['participantId'] is! String) {
        return null;
      }
      final token = json['reconnectToken'];
      return MultiplayerIdentity(
        participantId: json['participantId']! as String,
        reconnectToken: token is String ? token : null,
      );
    } on FormatException {
      return null;
    }
  }

  static Future<void> save(
    Uri serverUri,
    String roomCode,
    MultiplayerIdentity identity,
  ) => platform.writeIdentity(
    _key(serverUri, roomCode),
    jsonEncode(<String, Object?>{
      'participantId': identity.participantId,
      if (identity.reconnectToken case final token?) 'reconnectToken': token,
    }),
  );
}
