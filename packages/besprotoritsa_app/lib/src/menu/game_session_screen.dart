// This small route adapter only exposes self-describing constructor members.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/mvp/mvp_game_screen.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs a game state selected by the shell and keeps the autosave current.
class GameSessionScreen extends StatelessWidget {
  const GameSessionScreen({
    required this.initialState,
    required this.storage,
    super.key,
  });

  final GameState initialState;
  final GameStorage storage;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(initialState: initialState),
      ),
    ],
    child: _AutosavingGame(storage: storage, initialState: initialState),
  );
}

class _AutosavingGame extends ConsumerStatefulWidget {
  const _AutosavingGame({required this.storage, required this.initialState});

  final GameStorage storage;
  final GameState initialState;

  @override
  ConsumerState<_AutosavingGame> createState() => _AutosavingGameState();
}

class _AutosavingGameState extends ConsumerState<_AutosavingGame> {
  @override
  void initState() {
    super.initState();
    unawaited(_save(widget.initialState));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameControllerProvider, (_, next) {
      unawaited(_save(next));
    });
    return const MvpGameScreen();
  }

  Future<void> _save(GameState state) async {
    try {
      await widget.storage.saveGame('autosave', state);
    } on Object {
      // Saving must not prevent an otherwise playable local game session.
    }
  }
}
