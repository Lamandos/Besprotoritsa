// This small route adapter only exposes self-describing constructor members.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/mvp/mvp_game_screen.dart';
import 'package:besprotoritsa_app/src/storage/save_system.dart';
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

class _AutosavingGameState extends ConsumerState<_AutosavingGame>
    with WidgetsBindingObserver {
  late final SaveSystem _saves;
  late GameState _latestState;
  Future<void> _saveChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _saves = SaveSystem(storage: widget.storage);
    _latestState = widget.initialState;
    WidgetsBinding.instance.addObserver(this);
    _queueAutosave(widget.initialState);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameControllerProvider, (_, next) {
      // This covers every state boundary, including the start of a new round
      // and an unresolved event/combat choice.
      _latestState = next;
      _queueAutosave(next);
    });
    return MvpGameScreen(onManualSaveRequested: _saveManual);
  }

  @override
  void dispose() {
    // A final queued snapshot records a back-navigation/app-close boundary.
    _queueAutosave(_latestState);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _queueAutosave(_latestState);
    }
  }

  void _queueAutosave(GameState state) {
    _saveChain = _saveChain.catchError((Object _) {}).then((_) async {
      try {
        await _saves.autosave(state);
      } on Object {
        // Saving must not prevent an otherwise playable local game session.
      }
    });
  }

  Future<void> _saveManual(GameState state) async {
    final selected = await _showManualSaveDialog();
    if (selected == null || !mounted) return;
    try {
      await _saves.saveManual(selected.slotId, state, name: selected.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Партия сохранена.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить партию.')),
        );
      }
    }
  }

  Future<_ManualSaveChoice?> _showManualSaveDialog() async {
    final controller = TextEditingController();
    var slotId = SaveSlots.manual.first;
    final result = await showDialog<_ManualSaveChoice>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Сохранить партию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: slotId,
                items: [
                  for (var index = 0; index < SaveSlots.manual.length; index++)
                    DropdownMenuItem<String>(
                      value: SaveSlots.manual[index],
                      child: Text('Слот ${index + 1}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => slotId = value);
                },
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Название'),
                maxLength: 80,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _ManualSaveChoice(slotId, controller.text),
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }
}

class _ManualSaveChoice {
  const _ManualSaveChoice(this.slotId, this.name);

  final String slotId;
  final String name;
}
