import 'package:besprotoritsa_app/src/game/event_queue.dart';
import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Key of the boundary that keeps board repaints isolated from the game chrome.
const mvpBoardRepaintBoundaryKey = ValueKey<String>('mvp-hex-board');

/// The playable MVP board, command palette, animation status, and game log.
class MvpGameScreen extends ConsumerWidget {
  /// Creates the MVP game screen.
  const MvpGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final queue = ref.read(eventQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) => _MvpGameLayout(state: state, queue: queue),
    );
  }
}

class _MvpGameLayout extends ConsumerWidget {
  const _MvpGameLayout({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = queue.isPlaying || state.pendingDecision != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Беспроторица — MVP')),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _GameStatus(state: state, queue: queue),
                Expanded(child: HexBoardWidget(state: state)),
                AbsorbPointer(
                  absorbing: blocked,
                  child: _CommandPanel(state: state),
                ),
                _GameLog(state: state, queue: queue),
              ],
            ),
            if (state.pendingDecision != null && !queue.isPlaying)
              _PendingDecisionModal(decision: state.pendingDecision!),
          ],
        ),
      ),
    );
  }
}

class _GameStatus extends StatelessWidget {
  const _GameStatus({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Text('Раунд ${state.round} · действий: ${state.actionsLeft}'),
        const Spacer(),
        if (queue.current != null)
          Chip(
            key: const ValueKey<String>('animation-status'),
            avatar: const Icon(Icons.animation),
            label: Text('Анимация: ${_eventLabel(queue.current!)}'),
          ),
      ],
    ),
  );
}

/// A painted axial board with hero and monster tokens positioned by `(q, r)`.
class HexBoardWidget extends StatelessWidget {
  /// Creates the hex board for [state].
  const HexBoardWidget({required this.state, super.key});

  /// State rendered by this board.
  final GameState state;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: mvpBoardRepaintBoundaryKey,
    child: LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: 280,
        width: constraints.maxWidth,
        child: Stack(
          children: [
            for (final tile in state.board) _HexTileView(tile: tile),
            for (final player in state.players) _HeroToken(player: player),
            for (final monster in state.monsters)
              _MonsterToken(monster: monster),
          ],
        ),
      ),
    ),
  );
}

class _HexTileView extends StatelessWidget {
  const _HexTileView({required this.tile});

  final HexTile tile;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(tile.coord);
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Semantics(
        label: 'Гекс (${tile.coord.q}, ${tile.coord.r})',
        child: ClipPath(
          clipper: const _HexClipper(),
          child: Container(
            key: ValueKey<String>('hex-${tile.coord.q}-${tile.coord.r}'),
            width: 82,
            height: 72,
            color: tile.opened
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text('(${tile.coord.q}, ${tile.coord.r})'),
          ),
        ),
      ),
    );
  }
}

class _HeroToken extends StatelessWidget {
  const _HeroToken({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(player.coord);
    return Positioned(
      left: position.dx + 23,
      top: position.dy + 18,
      child: Semantics(
        label: 'Герой ${player.id} на (${player.coord.q}, ${player.coord.r})',
        child: CircleAvatar(
          key: ValueKey<String>(
            'hero-${player.id}-at-${player.coord.q}-${player.coord.r}',
          ),
          radius: 17,
          backgroundColor: player.id == 'ada' ? Colors.indigo : Colors.teal,
          child: Text(player.id.substring(0, 1).toUpperCase()),
        ),
      ),
    );
  }
}

class _MonsterToken extends StatelessWidget {
  const _MonsterToken({required this.monster});

  final MonsterInstance monster;

  @override
  Widget build(BuildContext context) {
    final position = _positionFor(monster.coord);
    return Positioned(
      left: position.dx + 50,
      top: position.dy + 32,
      child: Semantics(
        label:
            'Монстр ${monster.monsterId} '
            'на (${monster.coord.q}, ${monster.coord.r})',
        child: const Icon(Icons.bug_report, color: Colors.deepOrange, size: 28),
      ),
    );
  }
}

class _CommandPanel extends ConsumerWidget {
  const _CommandPanel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = _availableCommands(state);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Доступные команды'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final command in commands)
                FilledButton(
                  onPressed: () => ref
                      .read(gameControllerProvider.notifier)
                      .dispatch(command.command),
                  child: Text(command.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameLog extends StatelessWidget {
  const _GameLog({required this.state, required this.queue});

  final GameState state;
  final EventQueue queue;

  @override
  Widget build(BuildContext context) {
    final entries = <String>[
      ...state.log,
      ...queue.history.map(_eventLabel),
    ];
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 110),
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Лог последних событий'),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) => Text(entries[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingDecisionModal extends ConsumerWidget {
  const _PendingDecisionModal({required this.decision});

  final PendingDecision decision;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('Нужно решение'),
          content: Text(_decisionPrompt(decision)),
          actions: _decisionActions(ref, decision),
        ),
      ),
    ),
  );
}

List<Widget> _decisionActions(WidgetRef ref, PendingDecision decision) =>
    switch (decision) {
      AwaitingRerollChoice(:final availableRerolls) => [
        if (availableRerolls > 0)
          TextButton(
            onPressed: () => ref
                .read(gameControllerProvider.notifier)
                .dispatch(ResolvePendingDecisionCommand(RerollChoice())),
            child: const Text('Перебросить'),
          ),
        FilledButton(
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(
                const ResolvePendingDecisionCommand(KeepRollChoice()),
              ),
          child: const Text('Оставить результат'),
        ),
      ],
      AwaitingDodge() => [
        FilledButton(
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(const ResolvePendingDecisionCommand(DodgeChoice())),
          child: const Text('Уклониться'),
        ),
      ],
      AwaitingEventOption(:final options) => [
        for (final option in options)
          FilledButton(
            onPressed: () => ref
                .read(gameControllerProvider.notifier)
                .dispatch(
                  ResolvePendingDecisionCommand(EventOptionChoice(option)),
                ),
            child: Text(option),
          ),
      ],
      AwaitingTerminalPick(:final offeredCards) => [
        for (final cardId in offeredCards)
          FilledButton(
            onPressed: () => ref
                .read(gameControllerProvider.notifier)
                .dispatch(
                  ResolvePendingDecisionCommand(TerminalPickChoice(cardId)),
                ),
            child: Text('Купить: $cardId'),
          ),
        TextButton(
          onPressed: () => ref
              .read(gameControllerProvider.notifier)
              .dispatch(
                const ResolvePendingDecisionCommand(
                  DeclineTerminalPickChoice(),
                ),
              ),
          child: const Text('Не покупать'),
        ),
      ],
    };

List<_NamedCommand> _availableCommands(GameState state) {
  final candidates = <_NamedCommand>[
    for (final tile in state.board)
      _NamedCommand(
        'Ход: ${tile.coord.q}, ${tile.coord.r}',
        MoveCommand(tile.coord),
      ),
    for (final monster in state.monsters)
      _NamedCommand(
        'Атаковать ${monster.monsterId}',
        AttackCommand(monster.instanceId),
      ),
    const _NamedCommand('Завершить ход', EndTurnCommand()),
  ];
  return [
    for (final candidate in candidates)
      if (validate(state, candidate.command) == null) candidate,
  ];
}

class _NamedCommand {
  const _NamedCommand(this.label, this.command);

  final String label;
  final GameCommand command;
}

Offset _positionFor(HexCoord coord) => Offset(
  108 + (coord.q + coord.r * .5) * 76,
  94 + coord.r * 64,
);

String _eventLabel(GameEvent event) => switch (event) {
  HexEntered(:final playerId, :final to) =>
    '$playerId вошёл в (${to.q}, ${to.r})',
  ColocationTriggered(:final playerId) => 'столкновение: $playerId',
  DamageDealt(:final playerId, :final amount) =>
    '$playerId получил урон $amount',
  ConditionDrawn(:final conditionId) => 'получено состояние: $conditionId',
  MvpDemonstrationCompleted(:final questId) => 'завершено задание: $questId',
};

String _decisionPrompt(PendingDecision decision) => switch (decision) {
  AwaitingRerollChoice(:final dice) => 'Кубики: ${dice.join(', ')}',
  AwaitingDodge(:final requiredSuccesses) =>
    'Уклонение: нужно успехов $requiredSuccesses',
  AwaitingEventOption() => 'Выберите вариант события.',
  AwaitingTerminalPick() => 'Выберите припас в терминале.',
};

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .25, 0)
    ..lineTo(size.width * .75, 0)
    ..lineTo(size.width, size.height * .5)
    ..lineTo(size.width * .75, size.height)
    ..lineTo(size.width * .25, size.height)
    ..lineTo(0, size.height * .5)
    ..close();

  @override
  bool shouldReclip(_HexClipper oldClipper) => false;
}
