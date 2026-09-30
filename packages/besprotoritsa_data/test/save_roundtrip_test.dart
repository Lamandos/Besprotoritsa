import 'dart:convert';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test(
    'round-trips every field while a reroll decision is pending',
    () async {
      final state = _interruptedState();
      final storage = InMemoryGameStorage();
      final codec = GameStateJsonCodec();

      await storage.saveGame('interrupted-round', state);
      final savedJson = storage.encodedSlot('interrupted-round')!;
      final restored = await storage.loadGame('interrupted-round');

      expect(
        (jsonDecode(savedJson) as Map<String, dynamic>)['schema_version'],
        1,
      );
      expect(restored, isNotNull);
      expect(codec.encode(restored!), savedJson);
      expect(restored.cardDefinitions['pistol']!.sourceDeck, 'items');
      expect(restored.pendingDecision, isA<AwaitingRerollChoice>());
      final context =
          (restored.pendingDecision! as AwaitingRerollChoice).context!
              as SkillCheckContext;
      expect(context.eventBehaviorId, 'event_cabin_noise');
      expect(context.eventOptionIndex, 1);
    },
  );

  test('migrates an unversioned legacy document to schema version 1', () {
    final codec = GameStateJsonCodec();
    final legacy = Map<String, Object?>.of(codec.toJson(_interruptedState()))
      ..remove('schema_version')
      ..['schemaVersion'] = 0;

    final restored = codec.fromJson(legacy);

    expect(codec.toJson(restored)['schema_version'], 1);
  });

  test('restores legacy cabin-noise behavior for a pending skill roll', () {
    final codec = GameStateJsonCodec();
    final legacy = codec.toJson(_interruptedState());
    final decision = Map<String, Object?>.from(
      legacy['pending_decision']! as Map<Object?, Object?>,
    );
    final context = Map<String, Object?>.from(
      decision['context']! as Map<Object?, Object?>,
    )..remove('event_behavior_id');
    legacy['pending_decision'] = {...decision, 'context': context};

    final restored = codec.fromJson(legacy);
    final roll = restored.pendingDecision! as AwaitingRerollChoice;

    expect(
      (roll.context! as SkillCheckContext).eventBehaviorId,
      'event_cabin_noise',
    );
  });

  test('preserves immediate combat continuations in pending decisions', () {
    final base = _interruptedState();
    final codec = GameStateJsonCodec();
    const pendingDodge = AwaitingDodge(
      monsterDamage: 1,
      requiredAgilitySuccesses: 2,
      targetPlayerId: 'ada',
      counterAttackMonsterInstanceId: 'event-ghoul',
      counterAttackPlayerId: 'ada',
    );
    final restoredDodge =
        codec
                .decode(codec.encode(_withPending(base, pendingDodge)))
                .pendingDecision!
            as AwaitingDodge;
    final pendingAttack = AwaitingRerollChoice(
      dice: const [1, 2],
      availableRerolls: 1,
      window: const DecisionWindow(remainingTicks: 1),
      context: const AttackRollContext(
        playerId: 'ada',
        targetInstanceId: 'event-ghoul',
        resumeAutomaticPhase: true,
      ),
    );
    final restoredAttack =
        codec
                .decode(codec.encode(_withPending(base, pendingAttack)))
                .pendingDecision!
            as AwaitingRerollChoice;
    final pendingReplacement = AwaitingHeroReplacement(
      playerId: 'hero-2',
      characterIds: const ['scientist'],
      counterAttackMonsterInstanceId: 'event-ghoul',
      counterAttackPlayerId: 'ada',
    );
    final restoredReplacement =
        codec
                .decode(codec.encode(_withPending(base, pendingReplacement)))
                .pendingDecision!
            as AwaitingHeroReplacement;

    expect(restoredDodge.counterAttackMonsterInstanceId, 'event-ghoul');
    expect(restoredDodge.counterAttackPlayerId, 'ada');
    expect(
      restoredReplacement.counterAttackMonsterInstanceId,
      'event-ghoul',
    );
    expect(restoredReplacement.counterAttackPlayerId, 'ada');
    expect(
      (restoredAttack.context! as AttackRollContext).resumeAutomaticPhase,
      isTrue,
    );
  });

  test('reports invalid card definitions as format errors', () {
    final codec = GameStateJsonCodec();
    final invalid = Map<String, Object?>.of(codec.toJson(_interruptedState()))
      ..['card_definitions'] = <String, Object?>{
        'invalid-card': <String, Object?>{
          'id': 'invalid-card',
          'category': 'unknown',
          'slots': <String>[],
          'cost': 0,
          'stats': <String, int>{},
          'behaviorIds': <String>[],
        },
      };

    expect(() => codec.fromJson(invalid), throwsFormatException);
  });
}

GameState _withPending(GameState source, PendingDecision pendingDecision) =>
    GameState(
      seed: source.seed,
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
      pendingDecision: pendingDecision,
    );

GameState _interruptedState() => GameState(
  seed: 0xDEADBEEF,
  round: 4,
  phase: GamePhase.eventsPhase,
  activePlayerId: 'ada',
  actionsLeft: 1,
  board: [
    HexTile(
      id: 'start',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const {HexEdge.south, HexEdge.northEast},
      hasTerminal: true,
      ventColor: VentColor.green,
    ),
    HexTile(
      id: 'corridor',
      coord: const HexCoord(0, 1),
      type: HexTileType.corridor,
      opened: false,
      exits: const {HexEdge.north},
      locationId: 'reactor',
      hasTerminal: false,
      ventColor: VentColor.red,
      isBlocked: true,
    ),
  ],
  players: [
    _player(
      id: 'ada',
      characterId: 'engineer',
      coord: const HexCoord(0, 0),
      conditions: const ['malaise'],
    ),
    _player(
      id: 'boris',
      characterId: 'guard',
      coord: const HexCoord(0, 1),
      alive: false,
    ),
  ],
  monsters: [
    MonsterInstance(
      instanceId: 'ghoul-1',
      monsterId: 'ghoul',
      coord: const HexCoord(0, 1),
      damage: 1,
      health: 3,
      defense: 1,
      attack: 2,
      movement: 2,
      carriedGear: const ['pistol'],
      returnsToMonsterDeck: true,
    ),
  ],
  boils: const [BoilToken(instanceId: 'boil-1', coord: HexCoord(0, 0))],
  conditionCards: {
    'malaise': ConditionCard(
      id: 'malaise',
      statModifiers: const {StatType.strength: -1},
    ),
  },
  cardDefinitions: {
    'pistol': CardDefinition(
      id: 'pistol',
      type: ItemType.weapon,
      slots: const {ItemSlot.weapon},
      cost: 2,
      staticEffects: CardStaticEffects(const {CardStat.strength: 1}, range: 2),
      sourceDeck: 'items',
      behaviorIds: const ['pistol_attack_reroll'],
    ),
  },
  pendingDamage: const [
    IncomingDamage(
      targetPlayerId: 'boris',
      amount: 2,
      agilityDice: 3,
      source: DamageSource.monster,
    ),
  ],
  decks: {
    'events': DeckState(
      drawPile: const ['cabin-noise', 'darkness'],
      discardPile: const ['airlock'],
    ),
    'conditions': DeckState(
      drawPile: const ['concussion'],
      discardPile: const ['malaise'],
    ),
  },
  quests: QuestState(
    storyQuestIds: const ['chapter-1', 'chapter-2'],
    personalTasksByPlayer: const {
      'ada': ['repair-core'],
      'boris': ['guard-door'],
    },
    statuses: const {'chapter-1': QuestStatus.completed},
  ),
  log: const ['move:ada:HexCoord(0, 0)', 'event:reactor'],
  gameEvents: const [
    HexEntered(
      playerId: 'ada',
      from: HexCoord(1, -1),
      to: HexCoord(0, 0),
    ),
    ColocationTriggered(playerId: 'ada', coord: HexCoord(0, 0)),
    DamageDealt(playerId: 'ada', amount: 1),
    ConditionDrawn(playerId: 'ada', conditionId: 'malaise'),
    MvpDemonstrationCompleted(questId: 'chapter-1', playerId: 'ada'),
  ],
  monsterTurnIndex: 1,
  monsterStepsRemaining: 2,
  eventTurnIndex: 3,
  pendingDecision: AwaitingRerollChoice(
    dice: const [1, 5, 6],
    availableRerolls: 1,
    window: const DecisionWindow(remainingTicks: 2),
    context: const SkillCheckContext(
      playerId: 'ada',
      stat: StatType.science,
      difficulty: 2,
      eventId: 'cabin-noise',
      eventBehaviorId: 'event_cabin_noise',
      eventOptionIndex: 1,
      questId: 'chapter-1',
    ),
  ),
);

PlayerState _player({
  required String id,
  required String characterId,
  required HexCoord coord,
  Iterable<String> conditions = const [],
  bool alive = true,
}) => PlayerState(
  id: id,
  characterId: characterId,
  coord: coord,
  damage: 1,
  health: 5,
  credits: 7,
  backpack: const ['supply'],
  equipped: const EquippedGear(
    weapon: 'pistol',
    armor: 'vest',
    clothing: 'suit',
    robot: 'gu4-rd',
  ),
  carriedMods: const ['mod-1'],
  implanted: const ['implant-1'],
  conditions: conditions,
  alive: alive,
  stats: const PlayerStats(
    strength: 3,
    combatStrength: 2,
    science: 4,
    repair: 5,
    endurance: 2,
    agility: 1,
  ),
  weaponModifier: 2,
);
