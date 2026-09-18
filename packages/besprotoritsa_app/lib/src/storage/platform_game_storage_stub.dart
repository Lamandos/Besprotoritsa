import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Fallback storage for unsupported platforms.
GameStorage createGameStorage() => const _UnsupportedGameStorage();

class _UnsupportedGameStorage implements GameStorage {
  const _UnsupportedGameStorage();

  @override
  Future<GameState?> loadGame(String slotId) =>
      Future<GameState?>.error(UnsupportedError('Game saves are unavailable.'));

  @override
  Future<void> saveGame(String slotId, GameState state) =>
      Future<void>.error(UnsupportedError('Game saves are unavailable.'));
}
