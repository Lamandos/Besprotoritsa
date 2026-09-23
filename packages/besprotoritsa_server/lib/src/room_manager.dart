import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates and owns the authoritative game rooms served by one process.
///
/// A room is created from an already prepared [GameState]. Its players are
/// the available heroes; clients claim them in state order when they first
/// connect with a participant id.
final class RoomManager {
  /// Uses secure room-code generation and state-seeded dice by default.
  RoomManager({
    Random? random,
    DiceRoller Function(GameState state, int revision)? dice,
    Directory? persistenceDirectory,
    this.maxRooms = 1000,
    this.maxCommandJournalEntries = 10000,
  }) : _random = random ?? Random.secure(),
       _dice =
           dice ??
           ((state, revision) => SeededDiceRoller(state.seed ^ revision)),
       _persistence = persistenceDirectory == null
           ? null
           : FileRoomPersistence(persistenceDirectory) {
    if (maxRooms < 1) {
      throw ArgumentError.value(maxRooms, 'maxRooms', 'Must be positive.');
    }
    if (maxCommandJournalEntries < 1) {
      throw ArgumentError.value(
        maxCommandJournalEntries,
        'maxCommandJournalEntries',
        'Must be positive.',
      );
    }
    _restoreRooms();
  }

  final Random _random;
  final DiceRoller Function(GameState state, int revision) _dice;
  final FileRoomPersistence? _persistence;
  final Map<String, GameRoom> _rooms = <String, GameRoom>{};

  /// Upper bound for process-local rooms, protecting the server from unlimited
  /// unauthenticated room creation. Completed rooms can be archived separately.
  final int maxRooms;

  /// Upper bound for the durable idempotency journal of one active room.
  ///
  /// The journal is embedded in every snapshot, so leaving it unbounded turns
  /// a long-lived room into unbounded memory, disk, and write latency growth.
  final int maxCommandJournalEntries;

  /// Creates a room with a collision-free 128-bit uppercase invite code.
  GameRoom createRoom({required GameState state, bool started = false}) {
    if (state.players.length < 2 || state.players.length > 4) {
      throw ArgumentError.value(
        state.players.length,
        'state.players',
        'A room requires 2 to 4 heroes.',
      );
    }
    if (_rooms.length >= maxRooms) {
      throw const RoomCapacityExceeded(
        'The server has reached its room capacity.',
      );
    }
    late String code;
    do {
      code = _newRoomCode();
    } while (_rooms.containsKey(code));

    final room = GameRoom._(
      code: code,
      state: state,
      diceFactory: _dice,
      random: _random,
      persistence: _persistence,
      started: started,
      maxCommandJournalEntries: maxCommandJournalEntries,
    );
    _rooms[code] = room;
    room.persist();
    return room;
  }

  /// Restores every complete room snapshot found in the persistence directory.
  ///
  /// A malformed or interrupted file is ignored. Atomic replacement means that
  /// the preceding complete snapshot remains available after a process crash.
  void _restoreRooms() {
    final persistence = _persistence;
    if (persistence == null) return;
    for (final snapshot in persistence._loadSnapshots()) {
      if (_rooms.containsKey(snapshot.code)) continue;
      _rooms[snapshot.code] = GameRoom._(
        code: snapshot.code,
        state: snapshot.state,
        diceFactory: _dice,
        random: _random,
        persistence: persistence,
        participants: snapshot.participants,
        processedCommandIds: snapshot.processedCommandIds,
        commandJournal: snapshot.commandJournal,
        readyParticipantIds: snapshot.readyParticipantIds,
        revision: snapshot.revision,
        started: snapshot.started,
        maxCommandJournalEntries: maxCommandJournalEntries,
      );
    }
  }

  /// Finds a room by its case-insensitive invite code.
  GameRoom? room(String code) => _rooms[code.toUpperCase()];

  /// Shelf handler for room creation and game/lobby WebSockets.
  ///
  /// The participant id is supplied as the required `participantId` query
  /// parameter. A participant reconnects to their previously assigned hero.
  Handler get handler => _route;

  FutureOr<Response> _route(Request request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: _corsHeaders);
    }
    final segments = request.url.pathSegments;
    if (request.method == 'GET' &&
        segments.length == 1 &&
        segments.first == 'healthz') {
      return Response.ok(
        'ok\n',
        headers: const <String, String>{
          'content-type': 'text/plain; charset=utf-8',
        },
      );
    }
    if (request.method == 'POST' &&
        segments.length == 1 &&
        segments[0] == 'rooms') {
      try {
        if (request.contentLength case final length?
            when length > _maxRoomRequestBytes) {
          return Response(413, body: 'Room state is too large.');
        }
        final decoded = jsonDecode(await _readBoundedRequest(request));
        if (decoded is! Map<Object?, Object?>) {
          return Response(400, body: 'Room state must be a JSON object.');
        }
        final room = createRoom(
          state: GameStateJsonCodec().fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
        return Response.ok(
          jsonEncode(<String, String>{'roomCode': room.code}),
          headers: const {
            'content-type': 'application/json',
            ..._corsHeaders,
          },
        );
      } on FormatException catch (error) {
        return Response(400, body: error.message);
        // GameState constructors use ArgumentError for invalid decoded input.
        // ignore: avoid_catching_errors
      } on ArgumentError catch (error) {
        return Response(400, body: error.message?.toString());
      } on RoomCapacityExceeded catch (error) {
        return Response(503, body: error.message);
      } on RequestTooLarge catch (error) {
        return Response(413, body: error.message);
      }
    }
    if (segments.isEmpty || segments.first != 'rooms') {
      return Response.notFound('Expected POST /rooms or a room WebSocket.');
    }
    final participantId = request.url.queryParameters['participantId'];
    if (!_isValidParticipantId(participantId)) {
      return Response(400, body: 'participantId must be 1..128 characters.');
    }
    if (segments.length == 4 && segments[2] == 'lobby' && segments[3] == 'ws') {
      return handlerForLobby(
        roomCode: segments[1],
        participantId: participantId!,
        reconnectToken: request.url.queryParameters['reconnectToken'],
      )(request);
    }
    if (segments.length != 3 || segments[2] != 'ws') {
      return Response.notFound('Expected /rooms/<code>/(lobby/)ws.');
    }
    return handlerForRoom(
      roomCode: segments[1],
      participantId: participantId!,
      reconnectToken: request.url.queryParameters['reconnectToken'],
    )(request);
  }

  /// Returns a handler for one room and participant, suitable for mounting at
  /// any application-specific route.
  Handler handlerForRoom({
    required String roomCode,
    required String participantId,
    String? reconnectToken,
  }) {
    return webSocketHandler((channel, protocol) {
      final room = this.room(roomCode);
      if (room == null) {
        channel.sink.close(1008, 'Unknown room.');
        return;
      }
      room.connect(channel, participantId, reconnectToken: reconnectToken);
    });
  }

  /// Returns a handler for the character-selection lobby of a room.
  Handler handlerForLobby({
    required String roomCode,
    required String participantId,
    String? reconnectToken,
  }) => webSocketHandler((channel, protocol) {
    final room = this.room(roomCode);
    if (room == null) {
      channel.sink.close(1008, 'Unknown room.');
      return;
    }
    room.connectLobby(channel, participantId, reconnectToken: reconnectToken);
  });

  String _newRoomCode() => List<String>.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join().toUpperCase();
}

const Map<String, String> _corsHeaders = <String, String>{
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
};

const int _maxRoomRequestBytes = 1024 * 1024;
const int _maxWebSocketMessageCharacters = 64 * 1024;
const int _maxParticipantIdCharacters = 128;

Future<String> _readBoundedRequest(Request request) async {
  final bytes = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in request.read()) {
    length += chunk.length;
    if (length > _maxRoomRequestBytes) {
      throw const RequestTooLarge('Room state is too large.');
    }
    bytes.add(chunk);
  }
  try {
    return utf8.decode(bytes.takeBytes());
  } on FormatException {
    throw const FormatException('Room state must be UTF-8 JSON.');
  }
}

bool _isValidParticipantId(String? value) =>
    value != null &&
    value.isNotEmpty &&
    value.length <= _maxParticipantIdCharacters;

/// Raised when a process has reached its configured room limit.
final class RoomCapacityExceeded implements Exception {
  /// Creates a capacity error with a client-safe explanation.
  const RoomCapacityExceeded(this.message);

  /// Explanation suitable for the HTTP response body.
  final String message;
}

/// Raised when a request or socket message exceeds a protocol memory limit.
final class RequestTooLarge implements Exception {
  /// Creates a client-safe size-limit error.
  const RequestTooLarge(this.message);

  /// Explanation suitable for the HTTP response body or WebSocket peer.
  final String message;
}

/// One authoritative game, its claimed heroes, and live client connections.
final class GameRoom {
  GameRoom._({
    required this.code,
    required GameState state,
    required DiceRoller Function(GameState state, int revision) diceFactory,
    required Random random,
    required FileRoomPersistence? persistence,
    required int maxCommandJournalEntries,
    Map<String, _Participant> participants = const <String, _Participant>{},
    Set<String> processedCommandIds = const <String>{},
    List<Map<String, Object?>> commandJournal = const <Map<String, Object?>>[],
    Set<String> readyParticipantIds = const <String>{},
    int revision = 0,
    bool started = false,
  }) : _state = state,
       _diceFactory = diceFactory,
       _random = random,
       _persistence = persistence,
       _participants = Map<String, _Participant>.from(participants),
       _processedCommandIds = Set<String>.from(processedCommandIds),
       _commandJournal = List<Map<String, Object?>>.from(commandJournal),
       _readyParticipantIds = Set<String>.from(readyParticipantIds),
       _revision = revision,
       _started = started,
       _maxCommandJournalEntries = maxCommandJournalEntries;

  /// Stable public join code.
  final String code;
  final DiceRoller Function(GameState state, int revision) _diceFactory;
  final Random _random;
  final FileRoomPersistence? _persistence;
  final Map<String, _Participant> _participants;
  final Set<String> _processedCommandIds;
  final List<Map<String, Object?>> _commandJournal;
  final Set<String> _readyParticipantIds;
  final int _maxCommandJournalEntries;

  GameState _state;
  int _revision;
  bool _started;

  /// Current state revision. It changes only after an accepted command.
  int get revision => _revision;

  /// Current authoritative state. Callers must not send this to clients;
  /// [projectFor] is applied for every outbound state message.
  GameState get state => _state;

  /// Connects [participantId], assigning an unclaimed hero on first connect.
  ///
  /// Existing participant identities require their opaque [reconnectToken].
  /// This prevents a caller from impersonating a hero merely by guessing an
  /// id embedded in a lobby message.
  void connect(
    WebSocketChannel channel,
    String participantId, {
    String? reconnectToken,
  }) {
    if (!_isValidParticipantId(participantId)) {
      channel.sink.close(1008, 'participantId must be 1..128 characters.');
      return;
    }

    if (!_started) {
      channel.sink.close(1008, 'The room has not started yet.');
      return;
    }
    final participant = _authenticate(participantId, reconnectToken);
    if (participant == null) {
      channel.sink.close(1008, 'Invalid reconnect token or no heroes remain.');
      return;
    }

    participant.channel?.sink.close(1000, 'Reconnected elsewhere.');
    participant.channel = channel;
    _send(
      participant,
      <String, Object?>{
        'type': 'joined',
        'roomCode': code,
        'participantId': participant.id,
        'heroId': participant.heroId,
        'reconnectToken': participant.reconnectToken,
        'revision': _revision,
      },
    );
    _sendState(participant);

    channel.stream.listen(
      (Object? message) => _onMessage(participant, message),
      onDone: () {
        if (identical(participant.channel, channel)) participant.channel = null;
      },
      onError: (_, _) {
        if (identical(participant.channel, channel)) {
          participant.channel = null;
        }
      },
    );
  }

  /// Connects a participant to the lobby and broadcasts its current roster.
  void connectLobby(
    WebSocketChannel channel,
    String participantId, {
    String? reconnectToken,
  }) {
    if (!_isValidParticipantId(participantId)) {
      channel.sink.close(1008, 'participantId must be 1..128 characters.');
      return;
    }
    final participant = _authenticate(participantId, reconnectToken);
    if (participant == null) {
      channel.sink.close(1008, 'Invalid reconnect token or no heroes remain.');
      return;
    }
    participant.lobbyChannel?.sink.close(1000, 'Reconnected elsewhere.');
    participant.lobbyChannel = channel;
    participant.lobbyChannel!.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'joined',
        'participantId': participant.id,
        'heroId': participant.heroId,
        'reconnectToken': participant.reconnectToken,
      }),
    );
    _broadcastLobby();
    channel.stream.listen(
      (Object? message) => _onLobbyMessage(participant, message),
      onDone: () {
        if (identical(participant.lobbyChannel, channel)) {
          participant.lobbyChannel = null;
          _readyParticipantIds.remove(participant.id);
          persist();
          _broadcastLobby();
        }
      },
      onError: (_, _) {},
    );
  }

  void _onLobbyMessage(_Participant participant, Object? message) {
    try {
      _rejectOversizedSocketMessage(message);
      final envelope = _jsonObject(message);
      if (_started) {
        _sendLobbyError(participant, 'The room has already started.');
        return;
      }
      switch (envelope['type']) {
        case 'selectHero':
          final heroId = _requiredString(envelope, 'heroId');
          final known = _state.players.any((player) => player.id == heroId);
          final taken = _participants.values.any(
            (other) => other.id != participant.id && other.heroId == heroId,
          );
          if (!known || taken) {
            _sendLobbyError(participant, 'Hero is not available.');
          } else {
            participant.heroId = heroId;
            _readyParticipantIds.remove(participant.id);
            persist();
            _broadcastLobby();
          }
        case 'ready':
          if (envelope['ready'] == true) {
            _readyParticipantIds.add(participant.id);
          } else {
            _readyParticipantIds.remove(participant.id);
          }
          if (_allParticipantsReady()) _started = true;
          persist();
          _broadcastLobby();
        default:
          _sendLobbyError(participant, 'Unsupported lobby message type.');
      }
    } on RequestTooLarge catch (error) {
      _sendLobbyError(participant, error.message);
      participant.lobbyChannel?.sink.close(1009, error.message);
    } on FormatException catch (error) {
      _sendLobbyError(participant, error.message);
    }
  }

  void _broadcastLobby() {
    final participants = _participants.values
        .map(
          (participant) => <String, Object?>{
            'participantId': participant.id,
            'heroId': participant.heroId,
            'ready': _readyParticipantIds.contains(participant.id),
          },
        )
        .toList();
    final allReady = _started || _allParticipantsReady();
    final message = <String, Object?>{
      'type': allReady ? 'started' : 'lobby',
      'roomCode': code,
      'participants': participants,
      'heroes': _state.players
          .map(
            (player) => <String, String>{
              'id': player.id,
              'characterId': player.characterId,
            },
          )
          .toList(),
    };
    for (final participant in _participants.values) {
      participant.lobbyChannel?.sink.add(jsonEncode(message));
    }
  }

  bool _allParticipantsReady() =>
      _participants.length >= 2 &&
      _participants.values
              .map((participant) => participant.heroId)
              .toSet()
              .length ==
          _state.players.length &&
      _state.players.every(
        (player) => _participants.values.any(
          (participant) => participant.heroId == player.id,
        ),
      ) &&
      _participants.keys.every(_readyParticipantIds.contains);

  void _sendLobbyError(_Participant participant, String reason) {
    participant.lobbyChannel?.sink.add(
      jsonEncode(<String, String>{'type': 'error', 'reason': reason}),
    );
  }

  _Participant? _assign(String participantId) {
    final assignedHeroIds = _participants.values
        .map((participant) => participant.heroId)
        .toSet();
    PlayerState? hero;
    for (final player in _state.players) {
      if (!assignedHeroIds.contains(player.id)) {
        hero = player;
        break;
      }
    }
    if (hero == null) return null;
    final participant = _Participant(
      id: participantId,
      heroId: hero.id,
      reconnectToken: _newReconnectToken(),
    );
    _participants[participantId] = participant;
    persist();
    return participant;
  }

  _Participant? _authenticate(String participantId, String? reconnectToken) {
    if (reconnectToken != null && reconnectToken.isNotEmpty) {
      for (final participant in _participants.values) {
        if (participant.reconnectToken == reconnectToken) {
          return participant.id == participantId ? participant : null;
        }
      }
      return null;
    }
    if (_participants.containsKey(participantId)) return null;
    return _assign(participantId);
  }

  String _newReconnectToken() => List<String>.generate(
    32,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  void _onMessage(_Participant participant, Object? message) {
    try {
      _rejectOversizedSocketMessage(message);
      final envelope = _jsonObject(message);
      if (envelope['type'] != 'command') {
        _sendError(participant, 'Unsupported message type.');
        return;
      }
      final commandId = _requiredString(
        envelope,
        'commandId',
        maxLength: _maxParticipantIdCharacters,
      );
      final expectedRevision = _requiredInt(envelope, 'expectedRevision');
      final commandJson = _object(envelope, 'command');
      final commandKey = '${participant.id}:$commandId';
      if (_processedCommandIds.contains(commandKey)) {
        final previousCommand = _previousCommand(commandKey);
        if (previousCommand == null ||
            _canonicalJson(previousCommand) != _canonicalJson(commandJson)) {
          _sendError(
            participant,
            'Command ID was already used for a different command.',
          );
          return;
        }
        // The original response may have been lost. Re-send the authoritative
        // outcome without applying or broadcasting the command again.
        _sendState(participant);
        return;
      }
      if (expectedRevision != _revision) {
        _sendError(participant, 'State revision is stale.');
        _sendState(participant);
        return;
      }
      if (_commandJournal.length >= _maxCommandJournalEntries) {
        _sendError(participant, 'Room command limit has been reached.');
        return;
      }

      final command = _commandFromJson(commandJson);
      final controller = command is ResolvePendingDecisionCommand
          ? _pendingDecisionOwner(
              _state.pendingDecision,
              _state.activePlayerId,
            )
          : _state.activePlayerId;
      if (controller != participant.heroId) {
        _sendError(
          participant,
          command is ResolvePendingDecisionCommand
              ? 'Only the hero awaiting this decision may resolve it.'
              : 'Only the active hero may issue commands.',
        );
        return;
      }
      final rejection = validate(_state, command);
      if (rejection != null) {
        _sendError(participant, rejection.runtimeType.toString());
        return;
      }

      final result = step(_state, command, _diceFactory(_state, _revision));
      if (!result.isAccepted) {
        _sendError(participant, result.rejection.runtimeType.toString());
        return;
      }
      final nextRevision = _revision + 1;
      final journalEntry = <String, Object?>{
        'revision': nextRevision,
        'participantId': participant.id,
        'heroId': participant.heroId,
        'commandId': commandId,
        'command': commandJson,
      };
      try {
        _saveSnapshot(
          state: result.state,
          revision: nextRevision,
          processedCommandIds: <String>{..._processedCommandIds, commandKey},
          commandJournal: <Map<String, Object?>>[
            ..._commandJournal,
            journalEntry,
          ],
          readyParticipantIds: _readyParticipantIds,
          started: _started,
        );
      } on FileSystemException catch (_) {
        _sendError(participant, 'Could not persist room state.');
        return;
      }
      _state = result.state;
      _revision = nextRevision;
      _processedCommandIds.add(commandKey);
      _commandJournal.add(journalEntry);
      _broadcastState(result.events);
    } on RequestTooLarge catch (error) {
      _sendError(participant, error.message);
      participant.channel?.sink.close(1009, error.message);
    } on FormatException catch (error) {
      _sendError(participant, error.message);
      // Command constructors reject malformed numeric values with
      // ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      _sendError(participant, error.message?.toString() ?? 'Invalid command.');
    }
  }

  void _broadcastState([List<GameEvent> events = const <GameEvent>[]]) {
    for (final participant in _participants.values) {
      _sendState(participant, events);
    }
  }

  Map<String, Object?>? _previousCommand(String commandKey) {
    for (final entry in _commandJournal) {
      final participantId = entry['participantId'];
      final commandId = entry['commandId'];
      if (participantId is String &&
          commandId is String &&
          '$participantId:$commandId' == commandKey) {
        final command = entry['command'];
        return command is Map<String, Object?> ? command : null;
      }
    }
    return null;
  }

  void _sendState(
    _Participant participant, [
    List<GameEvent> events = const <GameEvent>[],
  ]) {
    _send(
      participant,
      <String, Object?>{
        'type': 'state',
        'revision': _revision,
        'state': _projectedStateToJson(
          projectFor(_state, participant.heroId),
          participant.heroId,
        ),
        'events': events
            .where(
              (event) =>
                  event is! ConditionDrawn ||
                  event.playerId == participant.heroId,
            )
            .map(_eventToJson)
            .toList(),
      },
    );
  }

  void _sendError(_Participant participant, String reason) => _send(
    participant,
    <String, Object?>{
      'type': 'error',
      'revision': _revision,
      'reason': reason,
    },
  );

  void _send(_Participant participant, Map<String, Object?> message) {
    participant.channel?.sink.add(jsonEncode(message));
  }

  /// Makes initial room creation and participant claims crash-safe as well.
  void persist() => _saveSnapshot(
    state: _state,
    revision: _revision,
    processedCommandIds: _processedCommandIds,
    commandJournal: _commandJournal,
    readyParticipantIds: _readyParticipantIds,
    started: _started,
  );

  void _saveSnapshot({
    required GameState state,
    required int revision,
    required Set<String> processedCommandIds,
    required List<Map<String, Object?>> commandJournal,
    required Set<String> readyParticipantIds,
    required bool started,
  }) {
    _persistence?._save(
      _RoomSnapshot(
        code: code,
        state: state,
        revision: revision,
        participants: _participants,
        processedCommandIds: processedCommandIds,
        commandJournal: commandJournal,
        readyParticipantIds: readyParticipantIds,
        started: started,
      ),
    );
  }
}

final class _Participant {
  _Participant({
    required this.id,
    required this.heroId,
    required this.reconnectToken,
  });

  final String id;
  PlayerId heroId;
  final String reconnectToken;
  WebSocketChannel? channel;
  WebSocketChannel? lobbyChannel;
}

/// Synchronous, file-backed storage for server-owned room snapshots.
///
/// The game loop writes a complete snapshot and complete command journal to
/// temporary sibling files, flushes them, then renames them into place. A
/// retained previous snapshot provides a recovery fallback if a filesystem or
/// host interrupts a replacement at an unfortunate moment.
final class FileRoomPersistence {
  /// Creates persistence rooted at [directory].
  FileRoomPersistence(Directory directory)
    : _directory = directory,
      _codec = GameStateJsonCodec() {
    if (!_directory.existsSync()) _directory.createSync(recursive: true);
  }

  final Directory _directory;
  final GameStateJsonCodec _codec;

  /// Writes an authoritative snapshot and its command journal atomically.
  void _save(_RoomSnapshot snapshot) {
    final encodedJournal = jsonEncode(<String, Object?>{
      'roomCode': snapshot.code,
      'commands': snapshot.commandJournal,
    });
    final encodedSnapshot = jsonEncode(<String, Object?>{
      'version': 1,
      'roomCode': snapshot.code,
      'revision': snapshot.revision,
      'state': _codec.toJson(snapshot.state),
      'participants': snapshot.participants.values
          .map(
            (participant) => <String, String>{
              'participantId': participant.id,
              'heroId': participant.heroId,
              'reconnectToken': participant.reconnectToken,
            },
          )
          .toList(),
      'processedCommandIds': snapshot.processedCommandIds.toList(),
      'readyParticipantIds': snapshot.readyParticipantIds.toList(),
      'started': snapshot.started,
      // Keeping the journal in the snapshot makes recovery independent of an
      // interrupted journal-file replacement.
      'commandJournal': snapshot.commandJournal,
    });
    _writeAtomically(_journalFile(snapshot.code), encodedJournal);
    _writeAtomically(_snapshotFile(snapshot.code), encodedSnapshot);
  }

  /// Reads the latest valid snapshot for every room. Invalid files are skipped
  /// and the previous complete snapshot is used when it exists.
  Iterable<_RoomSnapshot> _loadSnapshots() sync* {
    final candidates = <String>{
      for (final entity in _directory.listSync())
        if (entity is File && entity.path.endsWith('.room.json'))
          entity.uri.pathSegments.last.replaceFirst('.room.json', ''),
      for (final entity in _directory.listSync())
        if (entity is File && entity.path.endsWith('.room.json.bak'))
          entity.uri.pathSegments.last.replaceFirst('.room.json.bak', ''),
    };
    for (final code in candidates) {
      _RoomSnapshot? snapshot;
      for (final file in <File>[_snapshotFile(code), _backupFile(code)]) {
        if (!file.existsSync()) continue;
        try {
          snapshot = _decodeSnapshot(file.readAsStringSync());
          break;
        } on FormatException catch (_) {
          // Try the previous complete snapshot next.
        } on Object catch (_) {
          // A single damaged room must not prevent unrelated rooms restoring.
        }
      }
      if (snapshot != null) yield snapshot;
    }
  }

  File _snapshotFile(String code) => File('${_directory.path}/$code.room.json');
  File _journalFile(String code) =>
      File('${_directory.path}/$code.commands.json');
  File _backupFile(String code) => File('${_snapshotFile(code).path}.bak');

  _RoomSnapshot _decodeSnapshot(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException('Room snapshot must be an object.');
    }
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final code = _requiredString(json, 'roomCode');
    final revision = _requiredInt(json, 'revision');
    final state = _codec.fromJson(_object(json, 'state'));
    final participants = <String, _Participant>{};
    final participantJson = json['participants'];
    if (participantJson is! List<Object?>) {
      throw const FormatException('participants must be an array.');
    }
    for (final rawParticipant in participantJson) {
      final participant = _jsonObject(rawParticipant);
      final id = _requiredString(participant, 'participantId');
      participants[id] = _Participant(
        id: id,
        heroId: _requiredString(participant, 'heroId'),
        reconnectToken: _requiredString(participant, 'reconnectToken'),
      );
    }
    final processed = json['processedCommandIds'];
    final ready = json['readyParticipantIds'];
    final journal = json['commandJournal'];
    // Snapshots written before lobby state was persisted represented rooms that
    // were immediately playable, so retain that behaviour on upgrade.
    final started = json['started'] ?? true;
    if (processed is! List<Object?> ||
        ready is! List<Object?> ||
        journal is! List<Object?> ||
        started is! bool) {
      throw const FormatException('Room snapshot has an invalid command log.');
    }
    final commandJournal = journal
        .map<Map<String, Object?>>(_jsonObject)
        .toList();
    return _RoomSnapshot(
      code: code,
      state: state,
      revision: revision,
      participants: participants,
      processedCommandIds: _migrateProcessedCommandIds(
        processed,
        commandJournal,
      ),
      readyParticipantIds: ready.map((id) {
        if (id is! String) {
          throw const FormatException('Ready participant ids must be strings.');
        }
        return id;
      }).toSet(),
      commandJournal: commandJournal,
      started: started,
    );
  }

  Set<String> _migrateProcessedCommandIds(
    List<Object?> processed,
    List<Map<String, Object?>> commandJournal,
  ) {
    for (final id in processed) {
      if (id is! String) {
        throw const FormatException('Command ids must be strings.');
      }
    }
    // Snapshots before participant-scoped idempotency stored bare command
    // ids. Every accepted command is journaled, so rebuild the current keys
    // from that authoritative participant metadata during restoration.
    return commandJournal.map(_commandKeyFromJournal).toSet();
  }

  String _commandKeyFromJournal(Map<String, Object?> entry) {
    final participantId = _requiredString(entry, 'participantId');
    final commandId = _requiredString(entry, 'commandId');
    return '$participantId:$commandId';
  }

  void _writeAtomically(File target, String contents) {
    final temporary = File(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    final backup = File('${target.path}.bak');
    try {
      temporary.writeAsStringSync(contents, flush: true);
      if (target.existsSync()) target.copySync(backup.path);
      temporary.renameSync(target.path);
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }
}

final class _RoomSnapshot {
  const _RoomSnapshot({
    required this.code,
    required this.state,
    required this.revision,
    required this.participants,
    required this.processedCommandIds,
    required this.readyParticipantIds,
    required this.commandJournal,
    required this.started,
  });

  final String code;
  final GameState state;
  final int revision;
  final Map<String, _Participant> participants;
  final Set<String> processedCommandIds;
  final Set<String> readyParticipantIds;
  final List<Map<String, Object?>> commandJournal;
  final bool started;
}

Map<String, Object?> _eventToJson(GameEvent event) => switch (event) {
  HexEntered() => <String, Object?>{
    'type': 'hex_entered',
    'player_id': event.playerId,
    'from': _coordToJson(event.from),
    'to': _coordToJson(event.to),
  },
  ColocationTriggered() => <String, Object?>{
    'type': 'colocation_triggered',
    'player_id': event.playerId,
    'coord': _coordToJson(event.coord),
  },
  DamageDealt() => <String, Object?>{
    'type': 'damage_dealt',
    'player_id': event.playerId,
    'amount': event.amount,
  },
  ConditionDrawn() => <String, Object?>{
    'type': 'condition_drawn',
    'player_id': event.playerId,
    'condition_id': event.conditionId,
  },
  MvpDemonstrationCompleted() => <String, Object?>{
    'type': 'mvp_demonstration_completed',
    'quest_id': event.questId,
    'player_id': event.playerId,
  },
  HeroDied() => <String, Object?>{
    'type': 'hero_died',
    'player_id': event.playerId,
    'restless_instance_id': event.restlessInstanceId,
    'coord': _coordToJson(event.coord),
  },
};

Map<String, Object?> _jsonObject(Object? raw) {
  final decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is! Map<Object?, Object?>) {
    throw const FormatException('Message must be a JSON object.');
  }
  return decoded.map((key, value) {
    if (key is! String) {
      throw const FormatException('Message keys must be strings.');
    }
    return MapEntry(key, value);
  });
}

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<Object?, Object?>) {
    throw FormatException('"$key" must be an object.');
  }
  return value.map((nestedKey, nestedValue) {
    if (nestedKey is! String) {
      throw FormatException('"$key" contains a non-string key.');
    }
    return MapEntry(nestedKey, nestedValue);
  });
}

String _canonicalJson(Object? value) => jsonEncode(_canonicalJsonValue(value));

void _rejectOversizedSocketMessage(Object? message) {
  if (message is String && message.length > _maxWebSocketMessageCharacters) {
    throw const RequestTooLarge('WebSocket message is too large.');
  }
  if (message is List<int> && message.length > _maxWebSocketMessageCharacters) {
    throw const RequestTooLarge('WebSocket message is too large.');
  }
}

Object? _canonicalJsonValue(Object? value) {
  if (value is List<Object?>) {
    return value.map(_canonicalJsonValue).toList();
  }
  if (value is Map) {
    final entries =
        value.entries
            .map(
              (entry) => MapEntry(
                entry.key.toString(),
                _canonicalJsonValue(entry.value),
              ),
            )
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return Map<String, Object?>.fromEntries(entries);
  }
  return value;
}

String _requiredString(
  Map<String, Object?> json,
  String key, {
  int? maxLength,
}) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      (maxLength != null && value.length > maxLength)) {
    throw FormatException('"$key" must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('"$key" must be an integer.');
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('"$key" must be an integer.');
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('"$key" must be a non-empty string or null.');
  }
  return value;
}

List<Object?> _optionalList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const <Object?>[];
  if (value is! List<Object?>) {
    throw FormatException('"$key" must be an array.');
  }
  return value;
}

bool _optionalBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return false;
  if (value is! bool) throw FormatException('"$key" must be a boolean.');
  return value;
}

GameCommand _commandFromJson(Map<String, Object?> json) {
  final type = _requiredString(json, 'type');
  return switch (type) {
    'move' => MoveCommand(_coord(json)),
    'airlockMove' => AirlockMoveCommand(
      _coord(json),
      AirlockEquipment(
        hasSpaceSuit: _optionalBool(json, 'hasSpaceSuit'),
        hasOxygenTank: _optionalBool(json, 'hasOxygenTank'),
      ),
    ),
    'closeCorridor' => CloseCorridorCommand(_coord(json)),
    'attack' => AttackCommand(_requiredString(json, 'targetInstanceId')),
    'skillCheck' => SkillCheckCommand(
      _enumByName(StatType.values, json, 'stat'),
    ),
    'resolveDecision' => ResolvePendingDecisionCommand(
      _choiceFromJson(_object(json, 'choice')),
    ),
    'endTurn' => const EndTurnCommand(),
    'equip' => EquipCommand(
      _requiredString(json, 'cardId'),
      weaponSlot: _optionalInt(json, 'weaponSlot') ?? 0,
    ),
    'unequip' => UnequipCommand(
      _enumByName(ItemSlot.values, json, 'slot'),
      weaponSlot: _optionalInt(json, 'weaponSlot') ?? 0,
    ),
    'implantModification' => ImplantModificationCommand(
      _requiredString(json, 'cardId'),
    ),
    'useTerminal' => const UseTerminalCommand(),
    'depositIntoChest' => DepositIntoChestCommand(
      _requiredString(json, 'cardId'),
    ),
    'withdrawFromChest' => WithdrawFromChestCommand(
      _requiredString(json, 'cardId'),
    ),
    'depositCreditsIntoChest' => DepositCreditsIntoChestCommand(
      _requiredInt(json, 'amount'),
    ),
    'exchange' => ExchangeCommand(
      partnerId: _requiredString(json, 'partnerId'),
      giveCardId: _optionalString(json, 'giveCardId'),
      receiveCardId: _optionalString(json, 'receiveCardId'),
      giveCredits: _optionalInt(json, 'giveCredits') ?? 0,
      receiveCredits: _optionalInt(json, 'receiveCredits') ?? 0,
    ),
    _ => throw FormatException('Unknown command type "$type".'),
  };
}

HexCoord _coord(Map<String, Object?> json) => HexCoord(
  _requiredInt(json, 'q'),
  _requiredInt(json, 'r'),
);

T _enumByName<T extends Enum>(
  List<T> values,
  Map<String, Object?> json,
  String key,
) {
  final name = _requiredString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $key "$name".');
}

DecisionChoice _choiceFromJson(Map<String, Object?> json) {
  return switch (_requiredString(json, 'type')) {
    'keepRoll' => const KeepRollChoice(),
    'reroll' => RerollChoice(
      diceIndexes: _optionalList(json, 'diceIndexes').map((index) {
        if (index is! int) {
          throw const FormatException('diceIndexes must contain integers.');
        }
        return index;
      }),
    ),
    'dodge' => const DodgeChoice(),
    'eventOption' => EventOptionChoice(_requiredString(json, 'option')),
    'terminalPick' => TerminalPickChoice(_requiredString(json, 'cardId')),
    'declineTerminalPick' => const DeclineTerminalPickChoice(),
    'selectReplacementHero' => SelectReplacementHeroChoice(
      _requiredString(json, 'characterId'),
    ),
    final type => throw FormatException('Unknown decision type "$type".'),
  };
}

Map<String, Object?> _projectedStateToJson(
  PlayerGameState state,
  PlayerId viewerId,
) => <String, Object?>{
  'schemaVersion': state.schemaVersion,
  'round': state.round,
  'phase': state.phase.name,
  'activePlayerId': state.activePlayerId,
  'actionsLeft': state.actionsLeft,
  'board': state.board.map(_projectedTileToJson).toList(),
  'players': state.players.map(_projectedPlayerToJson).toList(),
  'monsters': state.monsters.map(_monsterToJson).toList(),
  'decks': {
    for (final entry in state.decks.entries)
      entry.key: entry.value.cardsRemaining,
  },
  'quests': {
    'storyQuestIds': state.quests.storyQuestIds,
    'personalTasks': state.quests.personalTasks,
    'hiddenPersonalTaskCounts': state.quests.hiddenPersonalTaskCounts,
  },
  'log': const <String>[],
  'pendingDecision': _pendingDecisionToJson(
    state.pendingDecision,
    viewerId,
    state.activePlayerId,
  ),
};

Map<String, Object?> _projectedTileToJson(ProjectedHexTile tile) =>
    <String, Object?>{
      'coord': _coordToJson(tile.coord),
      'isFogged': tile.isFogged,
      if (tile.tile case final visible?)
        'tile': <String, Object?>{
          'id': visible.id,
          'type': visible.type.name,
          'exits': visible.exits.map((edge) => edge.index).toList(),
          'locationId': visible.locationId,
          'hasTerminal': visible.hasTerminal,
          'ventColor': visible.ventColor.name,
          'isBlocked': visible.isBlocked,
        },
    };

Map<String, Object?> _projectedPlayerToJson(ProjectedPlayerState player) =>
    <String, Object?>{
      'id': player.id,
      'characterId': player.characterId,
      'coord': _coordToJson(player.coord),
      'damage': player.damage,
      'health': player.health,
      'credits': player.credits,
      'equipped': {
        'weapon': player.equipped.weapon,
        'secondWeapon': player.equipped.secondWeapon,
        'armor': player.equipped.armor,
        'clothing': player.equipped.clothing,
        'robot': player.equipped.robot,
      },
      'alive': player.alive,
      'isViewer': player.isViewer,
      'backpack': player.backpack,
      'carriedMods': player.carriedMods,
      'implanted': player.implanted,
      'conditions': player.conditions,
      'hiddenCardCount': player.hiddenCardCount,
    };

Map<String, Object?> _monsterToJson(MonsterInstance monster) =>
    <String, Object?>{
      'instanceId': monster.instanceId,
      'monsterId': monster.monsterId,
      'coord': _coordToJson(monster.coord),
      'damage': monster.damage,
      'health': monster.health,
      'defense': monster.defense,
      'attack': monster.attack,
      'movement': monster.movement,
    };

Map<String, int> _coordToJson(HexCoord coord) => <String, int>{
  'q': coord.q,
  'r': coord.r,
};

Map<String, Object?>? _pendingDecisionToJson(
  PendingDecision? decision,
  PlayerId viewerId,
  PlayerId? activePlayerId,
) {
  if (decision == null) return null;
  final ownerId = _pendingDecisionOwner(decision, activePlayerId);
  if (ownerId != null && ownerId != viewerId) {
    return <String, Object?>{
      'type': 'hidden',
      'awaitingPlayerId': ownerId,
    };
  }
  return switch (decision) {
    AwaitingRerollChoice(:final dice, :final availableRerolls) =>
      <String, Object?>{
        'type': 'reroll',
        'dice': dice,
        'availableRerolls': availableRerolls,
        'maxDicePerReroll': decision.maxDicePerReroll,
      },
    AwaitingDodge(:final monsterDamage, :final requiredAgilitySuccesses) =>
      <String, Object?>{
        'type': 'dodge',
        'monsterDamage': monsterDamage,
        'requiredAgilitySuccesses': requiredAgilitySuccesses,
      },
    AwaitingEventOption(:final options) => <String, Object?>{
      'type': 'eventOption',
      'options': options,
    },
    AwaitingTerminalPick(:final playerId, :final offeredCards) =>
      <String, Object?>{
        'type': 'terminalPick',
        'playerId': playerId,
        'offeredCards': offeredCards,
      },
    AwaitingHeroReplacement(:final playerId, :final characterIds) =>
      <String, Object?>{
        'type': 'heroReplacement',
        'playerId': playerId,
        'characterIds': characterIds,
      },
    AwaitingOtherPlayerDecision(:final awaitingPlayerId) => <String, Object?>{
      'type': 'hidden',
      'awaitingPlayerId': awaitingPlayerId,
    },
  };
}

/// Returns the only hero permitted to resolve the current pending decision.
///
/// The resolver is deliberately shared by authorization and serialization so a
/// client never sees a decision that its participant cannot answer.
PlayerId? _pendingDecisionOwner(
  PendingDecision? decision,
  PlayerId? activePlayerId,
) {
  if (decision == null) return null;
  return switch (decision) {
    AwaitingRerollChoice(:final context) => switch (context) {
      AttackRollContext(:final playerId) => playerId,
      SkillCheckContext(:final playerId) => playerId,
      null => activePlayerId,
    },
    AwaitingDodge(:final targetPlayerId) => targetPlayerId ?? activePlayerId,
    AwaitingEventOption(:final playerId) => playerId ?? activePlayerId,
    AwaitingTerminalPick(:final playerId) => playerId,
    AwaitingHeroReplacement(:final playerId) => playerId,
    AwaitingOtherPlayerDecision(:final awaitingPlayerId) => awaitingPlayerId,
  };
}
