// The route has a single, self-describing construction dependency.
// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_app/src/menu/game_session_screen.dart';
import 'package:besprotoritsa_app/src/theme/besprotoritsa_theme.dart';
import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.fullContentSet,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _selected,
                  builder: (context, selected, _) => _RosterList(
                    selected: selected,
                    onChanged: _toggleHero,
                    heroes: _availableHeroes(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<Set<String>>(
                valueListenable: _selected,
                builder: (context, selected, _) => FilledButton(
                  key: const ValueKey<String>('start-game-button'),
                  onPressed: selected.length >= 2 && selected.length <= 4
                      ? () => _reviewParty(context, selected)
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

  void _reviewParty(BuildContext context, Set<String> selected) {
    final roster = _availableHeroes()
        .where((hero) => selected.contains(hero.id))
        .map((hero) => hero.id)
        .toList(growable: false);
    final initialState = createFullGameState(
      characterIds: roster,
      seed: Random.secure().nextInt(0x7fffffff),
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FullPartyReviewScreen(
          characterIds: roster,
          initialState: initialState,
          storage: widget.storage,
        ),
      ),
    );
  }
}

List<_HeroOption> _availableHeroes() => [
  for (final character in fullRuntimeCharacters)
    _HeroOption(
      id: character['id']! as String,
      name: (_) => fullRuntimeCharacterName(character['id']! as String),
      stats: (strings) =>
          '${strings.science}: ${character['science']} · '
          '${strings.strength}: ${character['strength']} · '
          '${strings.repair}: ${character['repair']} · '
          'Выносливость: ${character['endurance']} · '
          'Ловкость: ${character['agility']}',
    ),
];

/// Shows the generated full party and asks for an explicit start confirmation.
class FullPartyReviewScreen extends StatelessWidget {
  const FullPartyReviewScreen({
    required this.characterIds,
    required this.initialState,
    required this.storage,
    super.key,
  });

  final List<String> characterIds;
  final GameState initialState;
  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.partyReviewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(strings.partyReviewSubtitle),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(
                  'Игровое поле: ${initialState.board.length} отсеков',
                ),
                subtitle: Text(
                  'Раунд ${initialState.round} · '
                  '${initialState.players.length} героя · '
                  '${initialState.decks.length} колод · '
                  '${initialState.questDefinitions.length} сюжетных заданий',
                ),
              ),
            ),
            for (var index = 0; index < characterIds.length; index++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(fullRuntimeCharacterName(characterIds[index])),
                  subtitle: Text(
                    'Здоровье ${initialState.players[index].health} · '
                    'Кредиты ${initialState.players[index].credits} · '
                    '${_starterItemCount(initialState.players[index])} '
                    'стартовых предмета',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('confirm-start-game-button'),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(strings.confirmStart),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(strings.confirmStartTitle),
                    content: Text(strings.confirmStartBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Вернуться'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Начать'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                Navigator.of(context).pushReplacement<void, void>(
                  MaterialPageRoute<void>(
                    builder: (_) => GameSessionScreen(
                      initialState: initialState,
                      storage: storage,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

int _starterItemCount(PlayerState player) =>
    player.backpack.length +
    [
      player.equipped.weapon,
      player.equipped.armor,
      player.equipped.clothing,
      player.equipped.robot,
    ].where((item) => item != null).length;

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.selected,
    required this.onChanged,
    required this.heroes,
  });

  final Set<String> selected;
  final ValueChanged<String> onChanged;
  final List<_HeroOption> heroes;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView.separated(
      itemCount: heroes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hero = heroes[index];
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
