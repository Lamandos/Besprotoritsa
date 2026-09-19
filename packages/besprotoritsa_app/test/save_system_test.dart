import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/storage/file_game_storage.dart';
import 'package:besprotoritsa_app/src/storage/save_system.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps five independent named manual slots plus an autosave', () async {
    final saves = SaveSystem(storage: InMemoryGameStorage());

    for (var index = 0; index < SaveSlots.manual.length; index++) {
      await saves.saveManual(
        SaveSlots.manual[index],
        _state(round: index + 1),
        name: 'Экспедиция ${index + 1}',
      );
    }
    await saves.autosave(_state(round: 9));

    for (var index = 0; index < SaveSlots.manual.length; index++) {
      expect((await saves.load(SaveSlots.manual[index]))!.round, index + 1);
      expect(
        await saves.loadName(SaveSlots.manual[index]),
        'Экспедиция ${index + 1}',
      );
    }
    expect((await saves.load(SaveSlots.autosave))!.round, 9);
    expect(await saves.loadName(SaveSlots.autosave), isNull);
  });

  test(
    'exports and imports JSON files, migrating an old schema on import',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'besprotoritsa-save-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = FileGameStorage(directoryProvider: () async => directory);
      final saves = SaveSystem(storage: storage);
      final codec = GameStateJsonCodec();
      final original = _state(round: 3);

      await saves.saveManual('slot-1', original, name: 'Перед боем');
      final exportPath =
          '${directory.path}${Platform.pathSeparator}backup.json';
      await saves.exportSlotToFile('slot-1', exportPath);

      final legacy =
          Map<String, dynamic>.from(
              jsonDecode(await File(exportPath).readAsString())
                  as Map<String, dynamic>,
            )
            ..remove('schema_version')
            ..['schemaVersion'] = 0;
      await File(exportPath).writeAsString(jsonEncode(legacy));

      final restored = await saves.importFile(
        'slot-2',
        exportPath,
        name: 'Перенесённая партия',
      );

      expect(restored.round, 3);
      expect(
        codec.toJson(restored)['schema_version'],
        currentSaveSchemaVersion,
      );
      expect((await saves.load('slot-2'))!.round, 3);
      expect(await saves.loadName('slot-2'), 'Перенесённая партия');
    },
  );

  test(
    'rejects invalid references and unsupported schema before overwriting',
    () async {
      final saves = SaveSystem(storage: InMemoryGameStorage());
      final codec = GameStateJsonCodec();
      await saves.saveManual('slot-1', _state(round: 2), name: 'Целая партия');

      final brokenReference =
          codec.toJson(
              _state(
                round: 7,
                decision: AwaitingEventOption(
                  options: const ['open-airlock'],
                  playerId: 'ada',
                ),
              ),
            )
            ..['pending_decision'] = <String, Object?>{
              'type': 'event_option',
              'options': <String>['open-airlock'],
              'player_id': 'missing-player',
              'event_id': null,
            };
      await expectLater(
        saves.importDocument('slot-1', jsonEncode(brokenReference)),
        throwsA(isA<FormatException>()),
      );
      expect((await saves.load('slot-1'))!.round, 2);

      final unsupportedSchema = codec.toJson(_state())
        ..['schema_version'] = currentSaveSchemaVersion + 1;
      await expectLater(
        saves.importDocument('slot-1', jsonEncode(unsupportedSchema)),
        throwsA(isA<UnsupportedError>()),
      );
      expect((await saves.load('slot-1'))!.round, 2);
    },
  );

  test(
    'reopens an intact save after an interrupted event-choice write',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'besprotoritsa-save-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final state = _state(
        round: 4,
        decision: AwaitingEventOption(
          options: const ['open-airlock', 'seal-airlock'],
          playerId: 'ada',
          eventId: 'cabin-noise',
        ),
      );
      final storage = FileGameStorage(directoryProvider: () async => directory);
      await storage.saveGame('slot-1', state);

      // This is the only artifact a process can leave before the atomic rename.
      final encodedSlot = base64Url.encode(utf8.encode('slot-1'));
      await File(
        '${directory.path}${Platform.pathSeparator}$encodedSlot.json.tmp-crash',
      ).writeAsString('{truncated');

      final reopened = FileGameStorage(
        directoryProvider: () async => directory,
      );
      final restored = await reopened.loadGame('slot-1');

      expect(restored, isNotNull);
      expect(restored!.round, 4);
      expect(restored.pendingDecision, isA<AwaitingEventOption>());
      expect((restored.pendingDecision! as AwaitingEventOption).options, [
        'open-airlock',
        'seal-airlock',
      ]);
    },
  );
}

GameState _state({int round = 1, PendingDecision? decision}) {
  final source = createMvpGameState();
  return GameState(
    seed: source.seed,
    round: round,
    phase: source.phase,
    activePlayerId: source.activePlayerId,
    actionsLeft: source.actionsLeft,
    board: source.board,
    players: source.players,
    monsters: source.monsters,
    boils: source.boils,
    reserveHeroes: source.reserveHeroes,
    queuedReplacements: source.queuedReplacements,
    conditionCards: source.conditionCards,
    cardDefinitions: source.cardDefinitions,
    pendingDamage: source.pendingDamage,
    chestCards: source.chestCards,
    decks: source.decks,
    quests: source.quests,
    log: source.log,
    gameEvents: source.gameEvents,
    isComplete: source.isComplete,
    monsterTurnIndex: source.monsterTurnIndex,
    monsterStepsRemaining: source.monsterStepsRemaining,
    eventTurnIndex: source.eventTurnIndex,
    actionsTakenThisTurn: source.actionsTakenThisTurn,
    pendingDecision: decision,
  );
}
