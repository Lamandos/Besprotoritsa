import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_data/besprotoritsa_data.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('BUG068 saves exhausted carried robots on monsters', () {
    final restless = RestlessMonster(
      instanceId: 'restless-ada',
      coord: const HexCoord(0, 0),
      attack: 1,
      defense: 0,
      carriedGear: const ['r69-nic3'],
      exhaustedCarriedRobots: const ['r69-nic3'],
    );
    final state = GameState(
      seed: 7,
      round: 1,
      phase: GamePhase.eventsPhase,
      activePlayerId: null,
      actionsLeft: 0,
      board: const [],
      players: const [],
      monsters: [restless],
      decks: const {},
      quests: QuestState(),
    );
    final codec = GameStateJsonCodec();

    final restored = codec.decode(codec.encode(state));

    expect(restored.monsters.single.exhaustedCarriedRobots, ['r69-nic3']);
  });

  test('BUG070 saves and restores chest robot readiness', () {
    final codec = GameStateJsonCodec();
    final state = _chestReadinessState(
      exhaustedChestRobots: const ['r69-nic3'],
    );

    final restored = codec.decode(codec.encode(state));

    expect(restored.chestCards, ['r69-nic3']);
    expect(restored.exhaustedChestRobots, ['r69-nic3']);
  });

  test(
    'BUG070 migrates legacy chest robot readiness from its former owner',
    () {
      final codec = GameStateJsonCodec();
      final legacy = codec.toJson(
        _chestReadinessState(ownerExhaustedRobots: const ['r69-nic3']),
      )..remove('exhausted_chest_robots');

      final restored = codec.fromJson(legacy);

      expect(restored.exhaustedChestRobots, ['r69-nic3']);
    },
  );

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
        currentSaveSchemaVersion,
      );
      expect(restored, isNotNull);
      expect(codec.encode(restored!), savedJson);
      expect(restored.cardDefinitions['pistol']!.sourceDeck, 'items');
      expect(restored.players.first.monsterDamageImmuneThroughRound, 3);
      expect(restored.players.first.monsterDefenseBonusRound, 5);
      expect(restored.players.first.monsterDefenseBonus, 3);
      expect(restored.players.first.enemyFeaturesIgnoredThroughRound, 4);
      expect(restored.players.first.retainedEventCards, ['scientist-report']);
      expect(restored.chestCards, ['shared-tool']);
      expect(restored.pendingDecision, isA<AwaitingRerollChoice>());
      final context =
          (restored.pendingDecision! as AwaitingRerollChoice).context!
              as SkillCheckContext;
      expect(context.eventBehaviorId, 'event_cabin_noise');
      expect(context.eventOptionIndex, 1);
    },
  );

  test('migrates an unversioned legacy document to current schema', () {
    final codec = GameStateJsonCodec();
    final legacy = Map<String, Object?>.of(codec.toJson(_interruptedState()))
      ..remove('schema_version')
      ..['schemaVersion'] = 0;

    final restored = codec.fromJson(legacy);

    expect(
      codec.toJson(restored)['schema_version'],
      currentSaveSchemaVersion,
    );
  });

  test('defaults legacy round-scoped defense markers to a one-point bonus', () {
    final codec = GameStateJsonCodec();
    final legacy = codec.toJson(_interruptedState());
    final players = legacy['players']! as List<Object?>;
    (players.first! as Map<String, Object?>).remove('monster_defense_bonus');

    final restored = codec.fromJson(legacy);

    expect(restored.players.first.monsterDefenseBonusRound, 5);
    expect(restored.players.first.monsterDefenseBonus, 1);
  });

  test('migrates checked in unversioned and release-1 save fixtures', () {
    final prefix = File('test/fixtures/save_schema_v0.json').existsSync()
        ? 'test/fixtures'
        : 'packages/besprotoritsa_data/test/fixtures';
    final codec = GameStateJsonCodec();

    for (final fixtureName in ['save_schema_v0.json', 'save_schema_v1.json']) {
      final restored = codec.decode(
        File('$prefix/$fixtureName').readAsStringSync(),
      );
      expect(
        codec.toJson(restored)['schema_version'],
        currentSaveSchemaVersion,
      );
      expect(restored.contentSetId, 'mvp');
      expect(restored.contentSetVersion, '1');
      expect(restored.prngState, restored.seed);
      expect(restored.turnOrder, ['ada', 'boris']);
    }
  });

  test('continues the same PRNG stream after a saved checkpoint', () {
    final codec = GameStateJsonCodec();
    final roller = SeededDiceRoller(_interruptedState().seed)..rollDice(5);
    final checkpointed = _interruptedState().withPrngState(roller.checkpoint);
    final restored = codec.decode(codec.encode(checkpointed));
    final resumed = SeededDiceRoller(
      restored.seed,
      checkpoint: restored.prngState,
    );

    expect(resumed.rollDice(12), roller.rollDice(12));
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

  test('BUG058 restores a legacy pending robot reroll source', () {
    final codec = GameStateJsonCodec();
    final legacy = codec.toJson(_interruptedState());
    final decision = Map<String, Object?>.from(
      legacy['pending_decision']! as Map<Object?, Object?>,
    )..remove('reroll_sources');
    legacy['pending_decision'] = decision;

    final players = (legacy['players']! as List<Object?>)
        .map(
          (player) => Map<String, Object?>.from(
            player! as Map<Object?, Object?>,
          ),
        )
        .toList();
    final firstPlayer = players.first;
    firstPlayer['equipped'] = Map<String, Object?>.from(
      firstPlayer['equipped']! as Map<Object?, Object?>,
    )..['robot'] = 'sc13-nc3';
    legacy['players'] = players;
    final cardDefinitions =
        Map<String, Object?>.from(
            legacy['card_definitions']! as Map<Object?, Object?>,
          )
          ..['sc13-nc3'] = <String, Object?>{
            'id': 'sc13-nc3',
            'category': 'robot',
            'slots': ['robot'],
            'cost': 0,
            'stats': <String, int>{},
            'behaviorIds': ['robot.exhaust', 'dice.reroll.allForSkill'],
            'sourceDeck': 'items',
          };
    legacy['card_definitions'] = cardDefinitions;

    final restored = codec.fromJson(legacy);
    final pending = restored.pendingDecision! as AwaitingRerollChoice;
    final rerolled = step(
      restored,
      ResolvePendingDecisionCommand(RerollChoice()),
      SeededDiceRoller(140),
    );

    expect(pending.rerollSources, ['sc13-nc3']);
    expect(rerolled.rejection, isNull);
    expect(rerolled.state.players.first.exhaustedRobots, contains('sc13-nc3'));
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
      rerollSources: const ['defibrillator'],
      window: const DecisionWindow(remainingTicks: 1),
      context: const AttackRollContext(
        playerId: 'ada',
        targetInstanceId: 'event-ghoul',
        resumeAutomaticPhase: true,
        bonusHits: 1,
      ),
    );
    final restoredAttack =
        codec
                .decode(codec.encode(_withPending(base, pendingAttack)))
                .pendingDecision!
            as AwaitingRerollChoice;
    expect(restoredAttack.rerollSources, ['defibrillator']);
    final pendingReplacement = AwaitingHeroReplacement(
      playerId: 'hero-2',
      characterIds: const ['scientist'],
      remainingPlayerIds: const ['hero-3'],
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
    expect(restoredReplacement.remainingPlayerIds, ['hero-3']);
    expect(
      (restoredAttack.context! as AttackRollContext).resumeAutomaticPhase,
      isTrue,
    );
    expect((restoredAttack.context! as AttackRollContext).bonusHits, 1);
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

  test('preserves a deferred event fight across a forced-movement dodge', () {
    final base = _interruptedState();
    final codec = GameStateJsonCodec();
    final restored = codec.decode(
      codec.encode(
        _withPending(
          base,
          const AwaitingDodge(
            monsterDamage: 1,
            requiredAgilitySuccesses: 1,
            targetPlayerId: 'ada',
            source: DamageSource.boil,
          ),
          pendingEventMonsterSpawn: const PendingEventMonsterSpawn(
            eventId: 'monster-pack',
            playerId: 'ada',
            optionIndex: 2,
            coord: HexCoord(0, 1),
          ),
        ),
      ),
    );

    expect(restored.pendingEventMonsterSpawn, isNotNull);
    expect(restored.pendingEventMonsterSpawn!.eventId, 'monster-pack');
    expect(restored.pendingEventMonsterSpawn!.optionIndex, 2);
    expect(restored.pendingEventMonsterSpawn!.coord, const HexCoord(0, 1));
  });
}

GameState _withPending(
  GameState source,
  PendingDecision pendingDecision, {
  PendingEventMonsterSpawn? pendingEventMonsterSpawn,
}) => GameState(
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
  pendingEventMonsterSpawn: pendingEventMonsterSpawn,
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
      monsterDamageImmuneThroughRound: 3,
      monsterDefenseBonusRound: 5,
      monsterDefenseBonus: 3,
      enemyFeaturesIgnoredThroughRound: 4,
      retainedEventCards: const ['scientist-report'],
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
  chestCards: const ['shared-tool'],
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

GameState _chestReadinessState({
  Iterable<String> exhaustedChestRobots = const [],
  Iterable<String> ownerExhaustedRobots = const [],
}) => GameState(
  seed: 7,
  round: 1,
  phase: GamePhase.eventsPhase,
  activePlayerId: 'ada',
  actionsLeft: 0,
  board: const [],
  players: [
    _player(
      id: 'ada',
      characterId: 'engineer',
      coord: const HexCoord(0, 0),
      exhaustedRobots: ownerExhaustedRobots,
    ),
  ],
  monsters: const [],
  decks: const {},
  quests: QuestState(),
  chestCards: const ['r69-nic3'],
  exhaustedChestRobots: exhaustedChestRobots,
);

PlayerState _player({
  required String id,
  required String characterId,
  required HexCoord coord,
  Iterable<String> conditions = const [],
  bool alive = true,
  int? monsterDamageImmuneThroughRound,
  int? monsterDefenseBonusRound,
  int monsterDefenseBonus = 1,
  int? enemyFeaturesIgnoredThroughRound,
  Iterable<String> retainedEventCards = const [],
  Iterable<String> exhaustedRobots = const [],
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
  retainedEventCards: retainedEventCards,
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
  monsterDamageImmuneThroughRound: monsterDamageImmuneThroughRound,
  monsterDefenseBonusRound: monsterDefenseBonusRound,
  monsterDefenseBonus: monsterDefenseBonus,
  enemyFeaturesIgnoredThroughRound: enemyFeaturesIgnoredThroughRound,
  exhaustedRobots: exhaustedRobots,
);
