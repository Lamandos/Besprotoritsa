// The route has a single, self-describing construction dependency.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_app/src/menu/game_session_screen.dart';
import 'package:besprotoritsa_app/src/theme/besprotoritsa_theme.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:flutter/material.dart';

/// Lets the player prepare an expedition of two to four distinct heroes.
class RosterSelectionScreen extends StatefulWidget {
  const RosterSelectionScreen({required this.storage, super.key});

  final GameStorage storage;

  @override
  State<RosterSelectionScreen> createState() => _RosterSelectionScreenState();
}

class _RosterSelectionScreenState extends State<RosterSelectionScreen> {
  final ValueNotifier<Set<String>> _selected = ValueNotifier(<String>{
    'scientist',
    'guard',
  });

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.rosterTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D241C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF765A3C)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 30,
                      color: BesprotoritsaTheme.bronze,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.rosterSubtitle,
                            style: const TextStyle(
                              color: BesprotoritsaTheme.bark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: _selected,
                            builder: (context, selected, _) => Text(
                              strings.rosterCount(selected.length),
                              key: const ValueKey<String>('roster-count'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: BesprotoritsaTheme.bone,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.auto_awesome,
                      color: BesprotoritsaTheme.bronze,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selected,
                  builder: (context, selected, _) => _RosterList(
                    selected: selected,
                    onChanged: _toggleHero,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<Set<String>>(
                valueListenable: _selected,
                builder: (context, selected, _) => FilledButton(
                  key: const ValueKey<String>('start-game-button'),
                  onPressed: selected.length >= 2 && selected.length <= 4
                      ? () => _startGame(context, selected)
                      : null,
                  child: Text(strings.startGame),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleHero(String heroId) {
    final selected = Set<String>.of(_selected.value);
    if (!selected.remove(heroId) && selected.length < 4) selected.add(heroId);
    _selected.value = selected;
  }

  void _startGame(BuildContext context, Set<String> selected) {
    final roster = _heroes
        .where((hero) => selected.contains(hero.id))
        .map((hero) => hero.id)
        .toList(growable: false);
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => GameSessionScreen(
          initialState: createMvpGameState(characterIds: roster),
          storage: widget.storage,
        ),
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView.separated(
      itemCount: _heroes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hero = _heroes[index];
        final isSelected = selected.contains(hero.id);
        return Card(
          child: CheckboxListTile(
            key: ValueKey<String>('hero-${hero.id}'),
            value: isSelected,
            activeColor: BesprotoritsaTheme.bronze,
            checkColor: BesprotoritsaTheme.ink,
            onChanged: (_) => onChanged(hero.id),
            title: Text(hero.name(strings)),
            subtitle: Text(hero.stats(strings)),
            secondary: isSelected
                ? const Icon(Icons.verified, color: BesprotoritsaTheme.bronze)
                : const Icon(Icons.person_outline, color: Color(0xFFB6A68B)),
          ),
        );
      },
    );
  }
}

class _HeroOption {
  const _HeroOption({
    required this.id,
    required this.name,
    required this.stats,
  });

  final String id;
  final String Function(AppStrings strings) name;
  final String Function(AppStrings strings) stats;
}

final List<_HeroOption> _heroes = <_HeroOption>[
  _HeroOption(
    id: 'scientist',
    name: (strings) => strings.scientist,
    stats: (strings) => '${strings.science}: 4 · ${strings.strength}: 2',
  ),
  _HeroOption(
    id: 'guard',
    name: (strings) => strings.guard,
    stats: (strings) => '${strings.strength}: 3 · ${strings.repair}: 1',
  ),
  _HeroOption(
    id: 'mechanic',
    name: (strings) => strings.mechanic,
    stats: (strings) => '${strings.repair}: 3 · ${strings.strength}: 2',
  ),
  _HeroOption(
    id: 'healer',
    name: (strings) => strings.healer,
    stats: (strings) => '${strings.medicine}: 3 · ${strings.science}: 3',
  ),
];
