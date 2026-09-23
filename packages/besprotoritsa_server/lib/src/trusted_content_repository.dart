import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Loads scenarios that are installed with the server, never supplied by a
/// network client.
final class TrustedContentRepository {
  /// Creates a repository rooted at the installed server content directory.
  TrustedContentRepository(this.rootDirectory);

  /// Root directory containing the trusted content sets.
  final Directory rootDirectory;

  /// Builds a new authoritative state for a supported content set.
  ///
  /// `mode` deliberately contains only gameplay switches. It cannot carry a
  /// board, deck, seed, player state, or any other authoritative state.
  GameState createGame({
    required String contentSetId,
    required int partySize,
    required Map<String, Object?> mode,
    required int seed,
  }) {
    if (contentSetId != 'mvp') {
      throw const FormatException('Unknown contentSetId.');
    }
    if (partySize < 2 || partySize > 4) {
      throw const FormatException('partySize must be between 2 and 4.');
    }
    if (mode.keys.any((key) => key != 'difficulty')) {
      throw const FormatException('Unsupported room mode parameter.');
    }
    final difficulty = mode['difficulty'];
    final difficultyLevel = switch (difficulty ?? 'normal') {
      'easy' => 1,
      'normal' => 2,
      'hard' => 3,
      _ => throw const FormatException(
        'mode.difficulty must be easy, normal, or hard.',
      ),
    };
    return _MvpContentLoader(rootDirectory).load(
      partySize: partySize,
      seed: seed,
      difficulty: difficultyLevel,
    );
  }
}

final class _MvpContentLoader {
  _MvpContentLoader(this._root);

  final Directory _root;

  GameState load({
    required int partySize,
    required int seed,
    required int difficulty,
  }) {
    final mvp = Directory('${_root.path}/mvp');
    if (!mvp.existsSync()) {
      throw const FormatException('Trusted MVP content is not installed.');
    }
    final characterIds = <String>['engineer', 'guard'];
    const optional = <String>['scientist', 'mechanic'];
    characterIds.addAll(optional.take(max(0, partySize - characterIds.length)));
    final characters = <String, Map<String, Object?>>{
      for (final id in characterIds)
        id: _document(File('${mvp.path}/characters/$id.json')),
    };
    final players = List<PlayerState>.generate(characterIds.length, (index) {
      final id = characterIds[index];
      final character = characters[id]!;
      return PlayerState(
        id: 'hero-${index + 1}',
        characterId: id,
        coord: const HexCoord(0, 0),
        damage: 0,
        health: _int(character, 'health'),
        credits: _int(character, 'startCredits'),
        backpack: _strings(character['startItems']),
        equipped: const EquippedGear(),
        carriedMods: const <String>[],
        implanted: const <String>[],
        conditions: const <String>[],
        alive: true,
        stats: PlayerStats(
          strength: _int(character, 'strength'),
          combatStrength: _int(character, 'combatStrength'),
          science: _int(character, 'science'),
          repair: _int(character, 'repair'),
          endurance: _int(character, 'endurance'),
          agility: _int(character, 'agility'),
        ),
      );
    });
    return GameState(
      seed: seed,
      difficulty: difficulty,
      round: 1,
      phase: GamePhase.playersTurn,
      activePlayerId: players.first.id,
      actionsLeft: 2,
      board: _board(mvp),
      players: players,
      monsters: <MonsterInstance>[
        MonsterInstance(
          instanceId: 'ghoul-1',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 1),
          damage: 0,
          health: 2,
          attack: 2,
        ),
      ],
      decks: <String, DeckState>{
        'conditions': DeckState(
          drawPile: const <String>['malaise', 'concussion'],
        ),
        'events': DeckState(drawPile: const <String>['cabin-noise']),
      },
      conditionCards: <String, ConditionCard>{
        'malaise': ConditionCard(
          id: 'malaise',
          statModifiers: const <StatType, int>{StatType.strength: -1},
        ),
      },
      quests: QuestState(storyQuestIds: const <String>['chapter-1-awakening']),
    );
  }

  List<HexTile> _board(Directory mvp) {
    final layout = _document(File('${mvp.path}/layout.json'));
    final coordinates = layout['coordinates'];
    if (coordinates is! List<Object?>) {
      throw const FormatException('Trusted layout has no coordinates.');
    }
    return coordinates.map((entry) {
      final position = _map(entry);
      final id = _string(position, 'hexId');
      final tile = _document(File('${mvp.path}/hexes/$id.json'));
      return HexTile(
        id: id,
        coord: HexCoord(_int(position, 'q'), _int(position, 'r')),
        type: HexTileType.values.byName(_string(tile, 'type')),
        opened: id == 'anabiosis',
        exits: _ints(
          tile['exits'],
        ).map((value) => HexEdge.values[value]).toSet(),
        locationId: id == 'crew-mess' ? id : null,
        hasTerminal: tile['hasTerminal'] == true,
        ventColor: VentColor.values.byName(_string(tile, 'ventColor')),
      );
    }).toList();
  }

  Map<String, Object?> _document(File file) {
    try {
      return _map(jsonDecode(file.readAsStringSync()));
    } on FileSystemException {
      throw FormatException('Missing trusted content file ${file.path}.');
    }
  }
}

Map<String, Object?> _map(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException('Expected object.');
  }
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _strings(Object? raw) => switch (raw) {
  final List<Object?> value when value.every((item) => item is String) =>
    value.cast<String>(),
  _ => throw const FormatException('Expected string array.'),
};

List<int> _ints(Object? raw) => switch (raw) {
  final List<Object?> value when value.every((item) => item is int) =>
    value.cast<int>(),
  _ => throw const FormatException('Expected integer array.'),
};
