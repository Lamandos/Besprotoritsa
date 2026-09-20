// Route widgets and their constructor fields are documented by their names.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_app/src/menu/game_session_screen.dart';
import 'package:besprotoritsa_app/src/menu/multiplayer_lobby_screens.dart';
import 'package:besprotoritsa_app/src/menu/roster_selection_screen.dart';
import 'package:besprotoritsa_app/src/menu/tutorial_and_rules_screens.dart';
import 'package:besprotoritsa_app/src/storage/platform_game_storage.dart';
import 'package:besprotoritsa_app/src/storage/save_system.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage used by the main menu. Hosts and tests may replace it with memory.
final gameStorageProvider = Provider<GameStorage>(
  (ref) => createPlatformGameStorage(),
);

/// The player-facing entry point for starting, resuming, and learning a game.
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final storage = ref.read(gameStorageProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 460,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _MenuContents(storage: storage, strings: strings),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuContents extends StatelessWidget {
  const _MenuContents({required this.storage, required this.strings});

  final GameStorage storage;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        strings.appTitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 8),
      Text(
        strings.menuSubtitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 40),
      FilledButton(
        key: const ValueKey<String>('new-game-button'),
        onPressed: () =>
            _push(context, RosterSelectionScreen(storage: storage)),
        child: Text(strings.newGame),
      ),
      const SizedBox(height: 12),
      FilledButton.tonal(
        key: const ValueKey<String>('multiplayer-button'),
        onPressed: () => _push(context, const MultiplayerEntryScreen()),
        child: const Text('Сетевая игра'),
      ),
      const SizedBox(height: 12),
      FilledButton.tonal(
        key: const ValueKey<String>('continue-button'),
        onPressed: () => _continueGame(context, storage, strings),
        child: Text(strings.continueGame),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const ValueKey<String>('load-game-button'),
        onPressed: () => _push(context, SaveSlotsScreen(storage: storage)),
        child: Text(strings.loadGame),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const ValueKey<String>('tutorial-button'),
        onPressed: () => _push(context, const TutorialScreen()),
        child: Text(strings.tutorial),
      ),
      const SizedBox(height: 12),
      TextButton(
        key: const ValueKey<String>('rules-button'),
        onPressed: () => _push(context, const RulesReferenceScreen()),
        child: Text(strings.rulesReference),
      ),
    ],
  );
}

Future<void> _continueGame(
  BuildContext context,
  GameStorage storage,
  AppStrings strings,
) async {
  GameState? state;
  try {
    state = await storage.loadGame('autosave');
  } on Object {
    state = null;
  }
  if (!context.mounted) {
    return;
  }
  if (state == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.noAutosave)));
    return;
  }
  _push(context, GameSessionScreen(initialState: state, storage: storage));
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

/// Shows the autosave and five player-facing save slots.
class SaveSlotsScreen extends StatelessWidget {
  const SaveSlotsScreen({required this.storage, super.key});

  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.loadTitle)),
      body: FutureBuilder<List<_LoadedSlot>>(
        future: _loadSlots(storage),
        builder: (context, snapshot) {
          final saves = snapshot.data;
          if (saves == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _saveSlots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _SaveSlotTile(
              slot: _saveSlots[index],
              loaded: saves[index],
              storage: storage,
              strings: strings,
            ),
          );
        },
      ),
    );
  }
}

Future<List<_LoadedSlot>> _loadSlots(GameStorage storage) {
  final saves = SaveSystem(storage: storage);
  return Future.wait(
    _saveSlots.map((slot) async {
      try {
        return _LoadedSlot(
          state: await saves.load(slot.id),
          name: await saves.loadName(slot.id),
        );
      } on Object {
        return const _LoadedSlot();
      }
    }),
  );
}

class _SaveSlotTile extends StatelessWidget {
  const _SaveSlotTile({
    required this.slot,
    required this.loaded,
    required this.storage,
    required this.strings,
  });

  final _SaveSlot slot;
  final _LoadedSlot loaded;
  final GameStorage storage;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(loaded.name ?? slot.label(strings)),
      subtitle: Text(
        loaded.state == null
            ? strings.emptySlot
            : '${strings.savedGame} · '
                  '${strings.saveRound(loaded.state!.round)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: loaded.state != null,
      onTap: loaded.state == null
          ? null
          : () => _push(
              context,
              GameSessionScreen(initialState: loaded.state!, storage: storage),
            ),
    ),
  );
}

class _LoadedSlot {
  const _LoadedSlot({this.state, this.name});

  final GameState? state;
  final String? name;
}

class _SaveSlot {
  const _SaveSlot(this.id, this.label);

  final String id;
  final String Function(AppStrings strings) label;
}

final List<_SaveSlot> _saveSlots = <_SaveSlot>[
  _SaveSlot(SaveSlots.autosave, (strings) => strings.autosave),
  for (var index = 0; index < SaveSlots.manual.length; index++)
    _SaveSlot(
      SaveSlots.manual[index],
      (strings) => strings.saveSlot(index + 1),
    ),
];
