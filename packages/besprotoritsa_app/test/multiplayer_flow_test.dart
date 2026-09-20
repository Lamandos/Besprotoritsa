import 'dart:async';
import 'dart:io';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:besprotoritsa_server/besprotoritsa_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  test(
    'two multiplayer clients receive the confirmed authoritative transition',
    () async {
      final manager = RoomManager();
      final room = manager.createRoom(
        state: createMvpGameState(),
        started: true,
      );
      final server = await shelf_io.serve(
        manager.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final endpoint = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      final ada = _container(endpoint, room.code, 'ada-client');
      final boris = _container(endpoint, room.code, 'boris-client');
      addTearDown(ada.dispose);
      addTearDown(boris.dispose);

      ada.read(gameControllerProvider);
      boris.read(gameControllerProvider);
      final adaController =
          ada.read(gameControllerProvider.notifier)
              as MultiplayerGameController;
      final borisController =
          boris.read(gameControllerProvider.notifier)
              as MultiplayerGameController;
      await Future.wait([
        adaController.connected,
        borisController.connected,
      ]).timeout(const Duration(seconds: 3));

      expect(ada.read(gameControllerProvider).activePlayerId, 'ada');
      expect(boris.read(gameControllerProvider).players, hasLength(2));

      expect(
        adaController.dispatch(const MoveCommand(HexCoord(0, 1))),
        isTrue,
      );
      expect(adaController.isWaitingForConfirmation, isTrue);

      await _until(() => ada.read(gameControllerProvider).actionsLeft == 0);
      await _until(() => boris.read(gameControllerProvider).actionsLeft == 0);

      expect(room.revision, 1);
      expect(
        ada.read(gameControllerProvider).players.first.coord,
        const HexCoord(0, 1),
      );
      expect(
        boris.read(gameControllerProvider).players.first.coord,
        const HexCoord(0, 1),
      );
      expect(adaController.isWaitingForConfirmation, isFalse);
      expect(ada.read(eventQueueProvider).history, hasLength(2));
      expect(boris.read(eventQueueProvider).history, hasLength(2));
    },
  );
}

ProviderContainer _container(
  Uri endpoint,
  String roomCode,
  String participantId,
) => ProviderContainer(
  overrides: [
    eventQueueProvider.overrideWith(
      (ref) => EventQueue(eventDuration: Duration.zero),
    ),
    gameControllerProvider.overrideWith(
      () => MultiplayerGameController(
        serverUri: endpoint,
        roomCode: roomCode,
        participantId: participantId,
      ),
    ),
  ],
);

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for multiplayer state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
