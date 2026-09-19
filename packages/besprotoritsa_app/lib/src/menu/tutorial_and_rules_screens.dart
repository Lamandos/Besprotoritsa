// The public routes are documented and need no member-level boilerplate.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_app/src/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// A guided, self-contained prologue that teaches the first three rounds.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final ValueNotifier<int> _step = ValueNotifier(0);

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.tutorialTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<int>(
                valueListenable: _step,
                builder: (context, step, _) => _TutorialStage(
                  step: step,
                  onAction: _advance,
                  onComplete: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _advance() => _step.value++;
}

class _TutorialStage extends StatelessWidget {
  const _TutorialStage({
    required this.step,
    required this.onAction,
    required this.onComplete,
  });

  final int step;
  final VoidCallback onAction;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (step == _tutorialActions.length) {
      return _TutorialComplete(onPressed: onComplete);
    }
    final action = _tutorialActions[step](strings);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.tutorialRound(action.round),
          key: const ValueKey<String>('tutorial-round'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(action.hint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: ValueKey<String>('tutorial-action-$step'),
          onPressed: onAction,
          child: Text(action.label),
        ),
      ],
    );
  }
}

class _TutorialComplete extends StatelessWidget {
  const _TutorialComplete({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.workspace_premium,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          strings.tutorialComplete,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onPressed, child: Text(strings.back)),
      ],
    );
  }
}

class _TutorialAction {
  const _TutorialAction({
    required this.round,
    required this.label,
    required this.hint,
  });

  final int round;
  final String label;
  final String hint;
}

final List<_TutorialAction Function(AppStrings strings)> _tutorialActions =
    <_TutorialAction Function(AppStrings strings)>[
      (strings) => _TutorialAction(
        round: 1,
        label: strings.move,
        hint: strings.tutorialMoveHint,
      ),
      (strings) => _TutorialAction(
        round: 1,
        label: strings.inspect,
        hint: strings.tutorialInspectHint,
      ),
      (strings) => _TutorialAction(
        round: 2,
        label: strings.scienceCheck,
        hint: strings.tutorialScienceHint,
      ),
      (strings) => _TutorialAction(
        round: 3,
        label: strings.fightGhoul,
        hint: strings.tutorialCombatHint,
      ),
      (strings) => _TutorialAction(
        round: 3,
        label: strings.useMedkit,
        hint: strings.tutorialMedkitHint,
      ),
    ];

/// A compact in-game rulebook for the mechanics introduced by the shell.
class RulesReferenceScreen extends StatelessWidget {
  const RulesReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.rulesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RuleSection(
            title: strings.rulesMovementTitle,
            body: strings.rulesMovementBody,
            icon: Icons.directions_walk,
          ),
          _RuleSection(
            title: strings.rulesChecksTitle,
            body: strings.rulesChecksBody,
            icon: Icons.science,
          ),
          _RuleSection(
            title: strings.rulesCombatTitle,
            body: strings.rulesCombatBody,
            icon: Icons.shield,
          ),
          _RuleSection(
            title: strings.rulesHealthTitle,
            body: strings.rulesHealthBody,
            icon: Icons.medical_services,
          ),
        ],
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}
