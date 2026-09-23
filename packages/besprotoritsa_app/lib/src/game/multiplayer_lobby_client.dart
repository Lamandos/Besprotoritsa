// Public data is documented on the containing types; member names are direct.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// A server-advertised hero and its availability in a room lobby.
class LobbyHero {
  const LobbyHero({required this.id, required this.characterId});

  final String id;
  final String characterId;
}

/// One connected room member in a lobby snapshot.
class LobbyParticipant {
  const LobbyParticipant({
    required this.participantId,
    required this.heroId,
    required this.ready,
  });

  final String participantId;
  final String heroId;
  final bool ready;
}

/// A synchronized lobby roster. [started] is true only when every member is
/// ready and the room has at least two participants.
class LobbySnapshot {
  const LobbySnapshot({
    required this.roomCode,
    required this.heroes,
    required this.participants,
    required this.started,
  });

  final String roomCode;
  final List<LobbyHero> heroes;
  final List<LobbyParticipant> participants;
  final bool started;
}

/// Creates rooms over HTTP and synchronizes a pre-game lobby over WebSocket.
class MultiplayerLobbyClient {
  MultiplayerLobbyClient({
    required this.serverUri,
    required this.roomCode,
    required this.participantId,
    String? reconnectToken,
    this.onReconnectToken,
  }) : _reconnectToken = reconnectToken;

  final Uri serverUri;
  final String roomCode;
  final String participantId;
  final Future<void> Function(String token)? onReconnectToken;
  final StreamController<LobbySnapshot> _snapshots =
      StreamController<LobbySnapshot>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  String? _reconnectToken;
  Future<void> _identityWrite = Future<void>.value();

  /// A broadcast stream of the server's complete lobby snapshots.
  Stream<LobbySnapshot> get snapshots => _snapshots.stream;

  /// Token issued by the room; pass it to the game controller on transition.
  String? get reconnectToken => _reconnectToken;

  /// Creates a room from a content set installed on the authoritative server.
  static Future<String> createRoom({
    required Uri serverUri,
    required String contentSetId,
    required int partySize,
    Map<String, Object?> mode = const <String, Object?>{},
  }) async {
    final endpoint = serverUri.replace(
      scheme: serverUri.scheme == 'ws' ? 'http' : serverUri.scheme,
      path: '${serverUri.path}/rooms'.replaceAll('//', '/'),
    );
    final response = await http.post(
      endpoint,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(<String, Object?>{
        'contentSetId': contentSetId,
        'partySize': partySize,
        'mode': mode,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Could not create room: ${response.body}');
    }
    final json = _object(jsonDecode(response.body));
    final code = json['roomCode'];
    if (code is! String) {
      throw const FormatException('Server returned no room code.');
    }
    return code;
  }

  /// Opens the lobby socket.
  Future<void> connect() async {
    final channel = WebSocketChannel.connect(
      serverUri.replace(
        scheme: serverUri.scheme == 'https' ? 'wss' : 'ws',
        path: '${serverUri.path}/rooms/$roomCode/lobby/ws'.replaceAll(
          '//',
          '/',
        ),
      ),
    );
    _channel = channel;
    await channel.ready;
    channel.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'authenticate',
        'participantId': participantId,
        if (_reconnectToken case final token?) 'reconnectToken': token,
      }),
    );
    _subscription = channel.stream.listen(
      _onMessage,
      onError: _snapshots.addError,
    );
  }

  /// Claims [heroId] if it remains free. Changing a hero clears readiness.
  void selectHero(String heroId) => _send(<String, Object?>{
    'type': 'selectHero',
    'heroId': heroId,
  });

  /// Sets this participant's readiness flag on the server.
  void setReady({required bool ready}) => _send(<String, Object?>{
    'type': 'ready',
    'ready': ready,
  });

  void _send(Map<String, Object?> message) {
    final channel = _channel;
    if (channel == null) throw StateError('Lobby is not connected.');
    channel.sink.add(jsonEncode(message));
  }

  void _onMessage(Object? raw) {
    try {
      final json = _object(raw is String ? jsonDecode(raw) : raw);
      if (json['type'] == 'error') {
        _snapshots.addError(
          StateError(json['reason'] as String? ?? 'Lobby error.'),
        );
        return;
      }
      if (json['type'] == 'joined') {
        final token = json['reconnectToken'];
        if (token is String && token.isNotEmpty) {
          _reconnectToken = token;
          final persist = onReconnectToken;
          if (persist != null) {
            _identityWrite = _identityWrite.then((_) => persist(token));
          }
        }
        return;
      }
      if (json['type'] != 'lobby' && json['type'] != 'started') return;
      final heroes = _objects(json['heroes'])
          .map(
            (hero) => LobbyHero(
              id: hero['id']! as String,
              characterId: hero['characterId']! as String,
            ),
          )
          .toList();
      final participants = _objects(json['participants'])
          .map(
            (member) => LobbyParticipant(
              participantId: member['participantId']! as String,
              heroId: member['heroId']! as String,
              ready: member['ready'] == true,
            ),
          )
          .toList();
      _snapshots.add(
        LobbySnapshot(
          roomCode: json['roomCode']! as String,
          heroes: heroes,
          participants: participants,
          started: json['type'] == 'started',
        ),
      );
    } on Object catch (error) {
      _snapshots.addError(error);
    }
  }

  /// Releases sockets and the snapshots stream.
  Future<void> close() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _identityWrite;
    await _snapshots.close();
  }
}

Map<String, Object?> _object(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException('Expected JSON object.');
  }
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

List<Map<String, Object?>> _objects(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException('Expected JSON array.');
  }
  return value.map(_object).toList();
}
