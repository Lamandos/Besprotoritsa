// The route has a single, self-describing construction dependency.
// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:besprotoritsa_app/src/menu/character_portrait.dart';
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
    _HeroOption(id: character['id']! as String, character: character),
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
                  leading: CharacterPortrait(
                    characterId: characterIds[index],
                    size: const Size(54, 54),
                  ),
                  title: Text(fullRuntimeCharacterName(characterIds[index])),
                  subtitle: Text(
                    _partyRosterSubtitle(strings, initialState.players[index]),
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
                        child: Text(strings.back),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(strings.startGame),
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

String _partyRosterSubtitle(AppStrings strings, PlayerState player) => [
  '${strings.health} ${player.health}',
  '${player.credits} ${strings.credits}',
  strings.starterItemCount(_starterItemCount(player)),
].join(' · ');

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final cardWidth = (constraints.maxWidth - spacing) / 2;
      return SingleChildScrollView(
        key: const ValueKey<String>('roster-hero-grid'),
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final hero in heroes)
              SizedBox(
                width: cardWidth,
                height: 390,
                child: _HeroCard(
                  key: ValueKey<String>('hero-${hero.id}'),
                  hero: hero,
                  selected: selected.contains(hero.id),
                  onTap: () => onChanged(hero.id),
                  onReadEntry: () => _showCharacterEntry(context, hero),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _HeroOption {
  const _HeroOption({required this.id, required this.character});

  final String id;
  final Map<String, Object?> character;

  int value(String key) => character[key]! as int;

  List<(String, int)> stats(AppStrings strings) => [
    (strings.strength, value('strength')),
    (strings.science, value('science')),
    (strings.repair, value('repair')),
    (strings.endurance, value('endurance')),
    (strings.agility, value('agility')),
  ];

  List<String> highestStats(AppStrings strings) {
    final rows = stats(strings);
    final maxValue = rows.map((row) => row.$2).reduce(max);
    return [
      for (final row in rows)
        if (row.$2 == maxValue) row.$1,
    ];
  }

  List<String> get startingItems =>
      (character['startItems']! as List<Object?>).cast<String>();
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.hero,
    required this.selected,
    required this.onTap,
    required this.onReadEntry,
    super.key,
  });

  final _HeroOption hero;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onReadEntry;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? const Color(0xFF463421) : const Color(0xFF2D241C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? BesprotoritsaTheme.bronze : const Color(0xFF765A3C),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CharacterPortrait(
                    characterId: hero.id,
                    size: const Size(66, 66),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fullRuntimeCharacterName(hero.id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: BesprotoritsaTheme.bone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? BesprotoritsaTheme.bronze
                        : const Color(0xFFB6A68B),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${strings.health}: ${hero.value('health')}',
                style: const TextStyle(
                  color: BesprotoritsaTheme.bone,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${strings.highestStats}: '
                '${hero.highestStats(strings).join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD4C6AB),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                strings.characterDescription,
                style: const TextStyle(
                  color: BesprotoritsaTheme.bone,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: onReadEntry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  child: Text(
                    strings.readEntry,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              for (final (label, value) in hero.stats(strings))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD4C6AB),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '$value',
                        style: const TextStyle(
                          color: BesprotoritsaTheme.bone,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 10, color: Color(0xFF765A3C)),
              Text(
                '${strings.startingEquipment}: '
                '${hero.startingItems.map(fullRuntimeItemName).join(', ')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFD4C6AB), fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${hero.value('startCredits')} ${strings.credits}',
                style: const TextStyle(
                  color: BesprotoritsaTheme.bone,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCharacterEntry(BuildContext context, _HeroOption hero) async {
  final strings = AppStrings.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: CharacterPortrait(
              characterId: hero.id,
              size: const Size(148, 148),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullRuntimeCharacterName(hero.id),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            strings.characterDescription,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(fullRuntimeCharacterDescription(hero.id)),
        ],
      ),
    ),
  );
}
