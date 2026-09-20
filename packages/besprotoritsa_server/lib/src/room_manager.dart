import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  RoomManager({Random? random, DiceRoller Function(GameState state)? dice})
    : _random = random ?? Random.secure(),
      _dice = dice ?? ((state) => SeededDiceRoller(state.seed));

  final Random _random;
  final DiceRoller Function(GameState state) _dice;
  final Map<String, GameRoom> _rooms = <String, GameRoom>{};

  /// Creates a room with a collision-free five-letter uppercase code.
  GameRoom createRoom({required GameState state}) {
    late String code;
    do {
      code = _newRoomCode();
    } while (_rooms.containsKey(code));

    final room = GameRoom._(
      code: code,
      state: state,
      dice: _dice(state),
    );
    _rooms[code] = room;
    return room;
  }

  /// Finds a room by its five-letter code.
  GameRoom? room(String code) => _rooms[code.toUpperCase()];

  /// Shelf handler exposing WebSockets at `/rooms/<code>/ws`.
  ///
  /// The participant id is supplied as the required `participantId` query
  /// parameter. A participant reconnects to their previously assigned hero.
  Handler get handler => _route;

  FutureOr<Response> _route(Request request) {
    final segments = request.url.pathSegments;
    if (segments.length != 3 || segments[0] != 'rooms' || segments[2] != 'ws') {
      return Response.notFound('Expected /rooms/<code>/ws.');
    }
    final participantId = request.url.queryParameters['participantId'];
    if (participantId == null || participantId.isEmpty) {
      return Response(400, body: 'participantId is required.');
    }
    return handlerForRoom(
      roomCode: segments[1],
      participantId: participantId,
    )(request);
  }

  /// Returns a handler for one room and participant, suitable for mounting at
  /// any application-specific route.
  Handler handlerForRoom({
    required String roomCode,
    required String participantId,
  }) {
    return webSocketHandler((channel, protocol) {
      final room = this.room(roomCode);
      if (room == null) {
        channel.sink.close(1008, 'Unknown room.');
        return;
      }
      room.connect(channel, participantId);
    });
  }

  String _newRoomCode() => String.fromCharCodes(
    List<int>.generate(5, (_) => 65 + _random.nextInt(26)),
  );
}

/// One authoritative game, its claimed heroes, and live client connections.
final class GameRoom {
  GameRoom._({
    required this.code,
    required GameState state,
    required DiceRoller dice,
  }) : _state = state,
       _dice = dice;

  /// Stable public join code.
  final String code;
  final DiceRoller _dice;
  final Map<String, _Participant> _participants = <String, _Participant>{};
  final Set<String> _processedCommandIds = <String>{};

  GameState _state;
  int _revision = 0;

  /// Current state revision. It changes only after an accepted command.
  int get revision => _revision;

  /// Current authoritative state. Callers must not send this to clients;
  /// [projectFor] is applied for every outbound state message.
  GameState get state => _state;

  /// Connects [participantId], assigning an unclaimed hero on first connect.
  void connect(WebSocketChannel channel, String participantId) {
    if (participantId.isEmpty) {
      channel.sink.close(1008, 'participantId must not be empty.');
      return;
    }

    final participant = _participants[participantId] ?? _assign(participantId);
    if (participant == null) {
      channel.sink.close(1008, 'No unassigned heroes remain.');
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
    final participant = _Participant(id: participantId, heroId: hero.id);
    _participants[participantId] = participant;
    return participant;
  }

  Future<void> _onMessage(_Participant participant, Object? message) async {
    try {
      final envelope = _jsonObject(message);
      if (envelope['type'] != 'command') {
        _sendError(participant, 'Unsupported message type.');
        return;
      }
      final commandId = _requiredString(envelope, 'commandId');
      if (!_processedCommandIds.add(commandId)) return;

      final command = _commandFromJson(_object(envelope, 'command'));
      if (_state.activePlayerId != participant.heroId) {
        _sendError(participant, 'Only the active hero may issue commands.');
        return;
      }
      final rejection = validate(_state, command);
      if (rejection != null) {
        _sendError(participant, rejection.runtimeType.toString());
        return;
      }

      final result = step(_state, command, _dice);
      if (!result.isAccepted) {
        _sendError(participant, result.rejection.runtimeType.toString());
        return;
      }
      _state = result.state;
      _revision++;
      _broadcastState();
    } on FormatException catch (error) {
      _sendError(participant, error.message);
      // Command constructors reject malformed numeric values with
      // ArgumentError.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      _sendError(participant, error.message?.toString() ?? 'Invalid command.');
    }
  }

  void _broadcastState() {
    for (final participant in _participants.values) {
      _sendState(participant);
    }
  }

  void _sendState(_Participant participant) {
    _send(
      participant,
      <String, Object?>{
        'type': 'state',
        'revision': _revision,
        'state': _projectedStateToJson(projectFor(_state, participant.heroId)),
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
}

final class _Participant {
  _Participant({required this.id, required this.heroId});

  final String id;
  final PlayerId heroId;
  WebSocketChannel? channel;
}

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

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('"$key" must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('"$key" must be an integer.');
  return value;
}

GameCommand _commandFromJson(Map<String, Object?> json) {
  final type = _requiredString(json, 'type');
  return switch (type) {
    'move' => MoveCommand(_coord(json)),
    'airlockMove' => AirlockMoveCommand(
      _coord(json),
      AirlockEquipment(
        hasSpaceSuit: json['hasSpaceSuit'] == true,
        hasOxygenTank: json['hasOxygenTank'] == true,
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
    'heal' => HealCommand(_requiredInt(json, 'amount')),
    'equip' => EquipCommand(
      _requiredString(json, 'cardId'),
      weaponSlot: (json['weaponSlot'] as int?) ?? 0,
    ),
    'unequip' => UnequipCommand(
      _enumByName(ItemSlot.values, json, 'slot'),
      weaponSlot: (json['weaponSlot'] as int?) ?? 0,
    ),
    'receiveCard' => ReceiveCardCommand(
      _requiredString(json, 'cardId'),
      implantImmediately: json['implantImmediately'] == true,
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
      giveCardId: json['giveCardId'] as String?,
      receiveCardId: json['receiveCardId'] as String?,
      giveCredits: (json['giveCredits'] as int?) ?? 0,
      receiveCredits: (json['receiveCredits'] as int?) ?? 0,
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
      diceIndexes: (json['diceIndexes'] as List<Object?>? ?? const <Object?>[])
          .map((index) {
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

Map<String, Object?> _projectedStateToJson(PlayerGameState state) =>
    <String, Object?>{
      'schemaVersion': state.schemaVersion,
      'seed': state.seed,
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
      'log': state.log,
      'pendingDecision': _pendingDecisionToJson(state.pendingDecision),
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
      'carriedGear': monster.carriedGear,
    };

Map<String, int> _coordToJson(HexCoord coord) => <String, int>{
  'q': coord.q,
  'r': coord.r,
};

Map<String, Object?>? _pendingDecisionToJson(PendingDecision? decision) {
  if (decision == null) return null;
  return switch (decision) {
    AwaitingRerollChoice(:final dice, :final availableRerolls) =>
      <String, Object?>{
        'type': 'reroll',
        'dice': dice,
        'availableRerolls': availableRerolls,
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
    AwaitingTerminalPick() => const <String, Object?>{'type': 'terminalPick'},
    AwaitingHeroReplacement(:final characterIds) => <String, Object?>{
      'type': 'heroReplacement',
      'characterIds': characterIds,
    },
  };
}
