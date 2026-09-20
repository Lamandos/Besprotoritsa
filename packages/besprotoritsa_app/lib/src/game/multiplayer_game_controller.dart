// Public data is documented on the containing types; member names are direct.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';

import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/game/projected_game_state_codec.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [GameSessionController] backed by the server's authoritative room.
///
/// It never applies a command locally. Instead it serializes the command,
/// waits for a newer server revision, and only then replaces the state and
/// enqueues the server-provided semantic animation events.
class MultiplayerGameController extends GameSessionController {
  MultiplayerGameController({
    required this.serverUri,
    required this.roomCode,
    required this.participantId,
    String? reconnectToken,
    GameState? placeholderState,
  }) : _reconnectToken = reconnectToken,
       _placeholderState = placeholderState;

  final Uri serverUri;
  final String roomCode;
  final String participantId;
  final GameState? _placeholderState;
  final ProjectedGameStateCodec _codec = const ProjectedGameStateCodec();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  String? _reconnectToken;
  int _nextCommand = 0;
  int _revision = -1;
  bool _waitingForConfirmation = false;
  bool _connected = false;
  String? _lastError;
  Completer<void>? _connectedCompleter;
  bool _isClosed = false;

  /// Opaque token used to resume this participant after a dropped socket.
  /// Persist this value with the session if the controller itself is recreated.
  String? get reconnectToken => _reconnectToken;

  /// Whether a command has been sent but has not yet been confirmed.
  bool get isWaitingForConfirmation => _waitingForConfirmation;

  /// Last rejection or transport error reported by the server.
  String? get lastError => _lastError;

  /// Completes when the initial projected state has arrived from the server.
  Future<void> get connected =>
      (_connectedCompleter ??= Completer<void>()).future;

  @override
  GameState build() {
    ref.onDispose(close);
    unawaited(connect());
    return _placeholderState ?? createMvpGameState();
  }

  /// Opens (or reopens) the room WebSocket.
  Future<void> connect() async {
    if (_channel != null) return connected;
    _isClosed = false;
    try {
      final channel = WebSocketChannel.connect(_gameUri());
      _channel = channel;
      await channel.ready;
      _subscription = channel.stream.listen(
        _onMessage,
        onDone: () => _onDisconnected(channel),
        onError: (_, _) => _onDisconnected(channel),
      );
    } on Object catch (error) {
      _lastError = error.toString();
      _channel = null;
      _scheduleReconnect();
    }
  }

  @override
  bool dispatch(GameCommand command) {
    if (_channel == null || _waitingForConfirmation) return false;
    _waitingForConfirmation = true;
    _lastError = null;
    _channel!.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'command',
        'commandId': '$participantId-${++_nextCommand}',
        'expectedRevision': _revision,
        'command': _commandToJson(command),
      }),
    );
    return true;
  }

  void _onMessage(Object? raw) {
    try {
      final envelope = _object(raw is String ? jsonDecode(raw) : raw);
      switch (envelope['type']) {
        case 'joined':
          final token = envelope['reconnectToken'];
          if (token is String && token.isNotEmpty) _reconnectToken = token;
        case 'state':
          final revision = _requiredInt(envelope['revision'], 'revision');
          if (revision < _revision) {
            return;
          }
          final events = _events(envelope['events']);
          state = _codec.decode(_object(envelope['state']));
          _revision = revision;
          _waitingForConfirmation = false;
          ref.read(eventQueueProvider).enqueue(events);
          if (!_connected) {
            _connected = true;
            (_connectedCompleter ??= Completer<void>()).complete();
          }
        case 'error':
          _waitingForConfirmation = false;
          _lastError = envelope['reason'] as String? ?? 'Command rejected.';
      }
    } on Object catch (error) {
      _lastError = error.toString();
      if (!_connected && !(_connectedCompleter?.isCompleted ?? false)) {
        (_connectedCompleter ??= Completer<void>()).completeError(error);
      }
    }
  }

  void _onDisconnected(WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;
    _channel = null;
    _waitingForConfirmation = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isClosed || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(milliseconds: 300), () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  /// Closes the game socket and cancels its listener.
  Future<void> close() async {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _gameUri() => serverUri.replace(
    scheme: serverUri.scheme == 'https' ? 'wss' : 'ws',
    path: '${serverUri.path}/rooms/$roomCode/ws'.replaceAll('//', '/'),
    queryParameters: <String, String>{
      'participantId': participantId,
      if (_reconnectToken case final token?) 'reconnectToken': token,
    },
  );
}

Map<String, Object?> _commandToJson(GameCommand command) => switch (command) {
  MoveCommand(:final target) => _coordCommand('move', target),
  AirlockMoveCommand(:final target, :final equipment) => <String, Object?>{
    ..._coordCommand('airlockMove', target),
    'hasSpaceSuit': equipment.hasSpaceSuit,
    'hasOxygenTank': equipment.hasOxygenTank,
  },
  CloseCorridorCommand(:final target) => _coordCommand('closeCorridor', target),
  AttackCommand(:final targetInstanceId) => <String, Object?>{
    'type': 'attack',
    'targetInstanceId': targetInstanceId,
  },
  SkillCheckCommand(:final stat) => <String, Object?>{
    'type': 'skillCheck',
    'stat': stat.name,
  },
  ResolvePendingDecisionCommand(:final choice) => <String, Object?>{
    'type': 'resolveDecision',
    'choice': _choiceToJson(choice),
  },
  EndTurnCommand() => const <String, Object?>{'type': 'endTurn'},
  HealCommand(:final amount) => <String, Object?>{
    'type': 'heal',
    'amount': amount,
  },
  EquipCommand(:final cardId, :final weaponSlot) => <String, Object?>{
    'type': 'equip',
    'cardId': cardId,
    'weaponSlot': weaponSlot,
  },
  UnequipCommand(:final slot, :final weaponSlot) => <String, Object?>{
    'type': 'unequip',
    'slot': slot.name,
    'weaponSlot': weaponSlot,
  },
  ReceiveCardCommand(:final cardId, :final implantImmediately) =>
    <String, Object?>{
      'type': 'receiveCard',
      'cardId': cardId,
      'implantImmediately': implantImmediately,
    },
  ImplantModificationCommand(:final cardId) => <String, Object?>{
    'type': 'implantModification',
    'cardId': cardId,
  },
  UseTerminalCommand() => const <String, Object?>{'type': 'useTerminal'},
  DepositIntoChestCommand(:final cardId) => <String, Object?>{
    'type': 'depositIntoChest',
    'cardId': cardId,
  },
  WithdrawFromChestCommand(:final cardId) => <String, Object?>{
    'type': 'withdrawFromChest',
    'cardId': cardId,
  },
  DepositCreditsIntoChestCommand(:final amount) => <String, Object?>{
    'type': 'depositCreditsIntoChest',
    'amount': amount,
  },
  ExchangeCommand(
    :final partnerId,
    :final giveCardId,
    :final receiveCardId,
    :final giveCredits,
    :final receiveCredits,
  ) =>
    <String, Object?>{
      'type': 'exchange',
      'partnerId': partnerId,
      'giveCardId': giveCardId,
      'receiveCardId': receiveCardId,
      'giveCredits': giveCredits,
      'receiveCredits': receiveCredits,
    },
};

Map<String, Object?> _coordCommand(String type, HexCoord coord) =>
    <String, Object?>{'type': type, 'q': coord.q, 'r': coord.r};

Map<String, Object?> _choiceToJson(DecisionChoice choice) => switch (choice) {
  KeepRollChoice() => const <String, Object?>{'type': 'keepRoll'},
  RerollChoice(:final diceIndexes) => <String, Object?>{
    'type': 'reroll',
    'diceIndexes': diceIndexes.toList(),
  },
  DodgeChoice() => const <String, Object?>{'type': 'dodge'},
  EventOptionChoice(:final option) => <String, Object?>{
    'type': 'eventOption',
    'option': option,
  },
  TerminalPickChoice(:final cardId) => <String, Object?>{
    'type': 'terminalPick',
    'cardId': cardId,
  },
  DeclineTerminalPickChoice() => const <String, Object?>{
    'type': 'declineTerminalPick',
  },
  SelectReplacementHeroChoice(:final characterId) => <String, Object?>{
    'type': 'selectReplacementHero',
    'characterId': characterId,
  },
};

Map<String, Object?> _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected JSON object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<GameEvent> _events(Object? raw) {
  if (raw is! List<Object?>) {
    return const <GameEvent>[];
  }
  return raw.map((item) {
    final json = _object(item);
    return switch (json['type']) {
      'hex_entered' => HexEntered(
        playerId: json['player_id']! as String,
        from: _eventCoord(_object(json['from'])),
        to: _eventCoord(_object(json['to'])),
      ),
      'colocation_triggered' => ColocationTriggered(
        playerId: json['player_id']! as String,
        coord: _eventCoord(_object(json['coord'])),
      ),
      'damage_dealt' => DamageDealt(
        playerId: json['player_id']! as String,
        amount: json['amount']! as int,
      ),
      'condition_drawn' => ConditionDrawn(
        playerId: json['player_id']! as String,
        conditionId: json['condition_id']! as String,
      ),
      'mvp_demonstration_completed' => MvpDemonstrationCompleted(
        questId: json['quest_id']! as String,
        playerId: json['player_id']! as String,
      ),
      'hero_died' => HeroDied(
        playerId: json['player_id']! as String,
        restlessInstanceId: json['restless_instance_id']! as String,
        coord: _eventCoord(_object(json['coord'])),
      ),
      _ => throw const FormatException('Unknown game event.'),
    };
  }).toList();
}

HexCoord _eventCoord(Map<String, Object?> json) => HexCoord(
  _requiredInt(json['q'], 'q'),
  _requiredInt(json['r'], 'r'),
);

int _requiredInt(Object? value, String name) {
  if (value is! int) throw FormatException('$name must be an integer.');
  return value;
}
