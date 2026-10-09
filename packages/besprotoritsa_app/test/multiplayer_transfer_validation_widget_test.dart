import 'package:besprotoritsa_app/src/game/event_queue.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_app/src/game/game_controller.dart';
import 'package:besprotoritsa_app/src/mvp/mvp_game_screen.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'authoritative multiplayer can submit a transfer from a partial projection',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 73,
      );
      final projection = GameState(
        seed: source.seed,
        contentSetId: source.contentSetId,
        contentSetVersion: source.contentSetVersion,
        difficulty: source.difficulty,
        round: source.round,
        phase: source.phase,
        activePlayerId: source.activePlayerId,
        actionsLeft: source.actionsLeft,
        board: source.board,
        players: source.players,
        monsters: source.monsters,
        decks: source.decks,
        quests: source.quests,
        eventDefinitions: source.eventDefinitions,
        questDefinitions: source.questDefinitions,
        taskDefinitions: source.taskDefinitions,
        monsterDefinitions: source.monsterDefinitions,
        contentTranslations: source.contentTranslations,
      );
      final controller = _AuthoritativeProjectionController(projection);
      final queue = EventQueue(eventDuration: Duration.zero);
      final container = ProviderContainer(
        overrides: [
          eventQueueProvider.overrideWithValue(queue),
          gameControllerProvider.overrideWith(() => controller),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey<String>('shared-chest-button')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final starterCard = find.text('Счастливые носки');
      expect(starterCard, findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: starterCard,
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tester.pump();

      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('confirm-chest-transfer')),
      );
      expect(confirm.onPressed, isNotNull);
    },
  );

  testWidgets(
    'authoritative multiplayer can submit an exchange '
    'from a partial projection',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 73,
      );
      final projection = _partialProjection(source);
      final controller = _AuthoritativeProjectionController(projection);
      final queue = EventQueue(eventDuration: Duration.zero);
      final container = ProviderContainer(
        overrides: [
          eventQueueProvider.overrideWithValue(queue),
          gameControllerProvider.overrideWith(() => controller),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey<String>('mvp-inventory-button')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.text('ОБМЕН'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      final exchangePartner = find.byKey(
        const ValueKey<String>('exchange-partner-hero-2'),
      );
      await tester.ensureVisible(exchangePartner);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(exchangePartner);
      await tester.pump(const Duration(milliseconds: 300));

      final exchangeDialog = find.byType(Dialog);
      final starterCard = find.descendant(
        of: exchangeDialog,
        matching: find.text('Счастливые носки'),
      );
      expect(starterCard, findsOneWidget);
      await tester.tap(
        find.ancestor(
          of: starterCard,
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tester.pump();

      final confirm = tester.widget<FilledButton>(
        find.byKey(const ValueKey<String>('confirm-inventory-exchange')),
      );
      expect(confirm.onPressed, isNotNull);
    },
  );

  testWidgets(
    'BUG036 authoritative multiplayer can submit a card ability '
    'from a partial projection',
    (tester) async {
      final source = createFullGameState(
        characterIds: const ['scientist', 'guard'],
        seed: 74,
      );
      final projection = _partialProjection(
        source,
        players: [
          _copyPlayerWithBackpack(source.players.first, const ['medkit']),
          source.players.last,
        ],
      );
      final controller = _AuthoritativeProjectionController(projection);
      final queue = EventQueue(eventDuration: Duration.zero);
      final container = ProviderContainer(
        overrides: [
          eventQueueProvider.overrideWithValue(queue),
          gameControllerProvider.overrideWith(() => controller),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(queue.dispose);
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MvpGameScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey<String>('mvp-inventory-button')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.text('Аптечка'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      final useButton = find.widgetWithText(FilledButton, 'Использовать');
      expect(useButton, findsOneWidget);
      expect(tester.widget<FilledButton>(useButton).onPressed, isNotNull);
    },
  );
}

GameState _partialProjection(
  GameState source, {
  Iterable<PlayerState>? players,
}) => GameState(
  seed: source.seed,
  contentSetId: source.contentSetId,
  contentSetVersion: source.contentSetVersion,
  difficulty: source.difficulty,
  round: source.round,
  phase: source.phase,
  activePlayerId: source.activePlayerId,
  actionsLeft: source.actionsLeft,
  board: source.board,
  players: players ?? source.players,
  monsters: source.monsters,
  decks: source.decks,
  quests: source.quests,
  eventDefinitions: source.eventDefinitions,
  questDefinitions: source.questDefinitions,
  taskDefinitions: source.taskDefinitions,
  monsterDefinitions: source.monsterDefinitions,
  contentTranslations: source.contentTranslations,
);

PlayerState _copyPlayerWithBackpack(
  PlayerState player,
  Iterable<CardId> backpack,
) => PlayerState(
  id: player.id,
  characterId: player.characterId,
  coord: player.coord,
  damage: player.damage,
  health: player.health,
  credits: player.credits,
  backpack: backpack,
  equipped: player.equipped,
  carriedMods: player.carriedMods,
  implanted: player.implanted,
  conditions: player.conditions,
  retainedEventCards: player.retainedEventCards,
  alive: player.alive,
  stats: player.stats,
  weaponModifier: player.weaponModifier,
  actionPoints: player.actionPoints,
  nextTurnActionDelta: player.nextTurnActionDelta,
  monsterDamageImmuneThroughRound: player.monsterDamageImmuneThroughRound,
  monsterDefenseBonusRound: player.monsterDefenseBonusRound,
  damageImmuneThroughRound: player.damageImmuneThroughRound,
  enemyFeaturesIgnoredThroughRound: player.enemyFeaturesIgnoredThroughRound,
  nextAttackBonusHits: player.nextAttackBonusHits,
  exhaustedRobots: player.exhaustedRobots,
);

class _AuthoritativeProjectionController extends GameSessionController {
  _AuthoritativeProjectionController(this.projection);

  final GameState projection;

  // Kept compatible with the parent revision, where the base getter was not
  // present yet, so this test can verify the same UI against pre-fix source.
  // ignore: annotate_overrides
  bool get validatesCommandsLocally => false;

  @override
  GameState build() => projection;

  @override
  bool dispatch(GameCommand command) => true;
}
