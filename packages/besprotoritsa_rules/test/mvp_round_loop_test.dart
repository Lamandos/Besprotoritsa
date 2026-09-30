import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test('runtime event definitions drive options and skill checks', () {
    var state = _mvpState(
      eventId: 'runtime-event',
      eventDefinitions: {
        'runtime-event': {
          'options': [
            {
              'skillCheck': {'skill': 'science', 'difficulty': 2},
            },
            {'skillCheck': null},
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    final event = state.pendingDecision! as AwaitingEventOption;
    expect(event.eventId, 'runtime-event');
    expect(event.options, ['option-1', 'option-2']);

    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([6]),
    ).state;
    final roll = state.pendingDecision! as AwaitingRerollChoice;
    final context = roll.context! as SkillCheckContext;
    expect(context.stat, StatType.science);
    expect(context.difficulty, 2);
  });

  test('invasion lets the player choose any open sector', () {
    var state = _mvpState(
      eventId: 'invasion-open',
      corridorOpened: true,
      eventDefinitions: {
        'invasion-open': {
          'immediateCombat': true,
          'spawn': {'behaviorId': 'monster.spawn', 'target': 'openSector'},
          'options': [
            {
              'skillCheck': null,
              'behaviorId': 'monster.spawn',
              'resolution': 'immediate',
            },
          ],
        },
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 2,
          'defense': 0,
          'attack': 0,
          'movement': 0,
          'features': <String>[],
        },
      },
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    final placement = state.pendingDecision! as AwaitingEventOption;
    expect(placement.options, ['sector:0:0', 'sector:0:1']);
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.monsters.single.coord, const HexCoord(0, 1));
  });

  test('invasion lets the player choose any closed fallback sector', () {
    var state = _mvpState(
      eventId: 'location-invasion',
      eventDefinitions: {
        'location-invasion': {
          'locationId': 'crew-mess',
          'immediateCombat': true,
          'spawn': {
            'behaviorId': 'monster.spawn',
            'target': 'location',
            'fallback': 'closedSector',
          },
          'options': [
            {
              'skillCheck': null,
              'behaviorId': 'monster.spawn',
              'resolution': 'immediate',
            },
          ],
        },
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 2,
          'defense': 0,
          'attack': 0,
          'movement': 0,
          'features': <String>[],
        },
      },
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    final placement = state.pendingDecision! as AwaitingEventOption;
    expect(placement.options, ['sector:0:1', 'sector:0:2']);
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.monsters.single.coord, const HexCoord(0, 1));
  });

  test('event skill checks do not advance the full story quest', () {
    var state = _mvpState(
      eventId: 'runtime-event',
      playerCoord: const HexCoord(0, 2),
      eventDefinitions: {
        'runtime-event': {
          'options': [
            {
              'skillCheck': {'skill': 'science', 'difficulty': 1},
            },
          ],
        },
      },
      storyQuestIds: const ['quest-01'],
      conditionProgress: const {
        'quest-01': {'arrive-crew-quarters': 1},
      },
      questDefinitions: {
        'quest-01': {
          'id': 'quest-01',
          'number': 1,
          'chapter': 1,
          'conditions': [
            {
              'id': 'arrive-crew-quarters',
              'type': 'arrive',
              'locationId': 'crew-mess',
            },
            {
              'id': 'science-crew-quarters',
              'type': 'skill_check',
              'skill': 'science',
              'locationId': 'crew-mess',
            },
          ],
          'reward': {'credits': 0, 'items': <Object?>[]},
          'nextQuestIds': [],
          'nameKey': 'quest-01.name',
          'descKey': 'quest-01.description',
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(state.quests.statusOf('quest-01'), QuestStatus.active);
    expect(
      state.quests.conditionProgress['quest-01']?['science-crew-quarters'],
      isNull,
    );
    expect(state.isComplete, isFalse);
  });

  test(
    'event mechanics follow option behavior data, independent of card id',
    () {
      var state = _mvpState(
        eventId: 'unfamiliar-card-id',
        storyQuestIds: const ['quest-01'],
        questDefinitions: {
          'quest-01': {
            'id': 'quest-01',
            'number': 1,
            'chapter': 1,
            'conditions': <Object?>[],
            'reward': {'credits': 0, 'items': <Object?>[]},
            'nextQuestIds': [],
            'nameKey': 'quest-01.name',
            'descKey': 'quest-01.description',
          },
        },
        eventDefinitions: {
          'unfamiliar-card-id': {
            'options': [
              {
                'skillCheck': {'skill': 'agility', 'difficulty': 1},
                'behaviorId': 'event_cabin_noise',
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([6]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(KeepRollChoice()),
        FixedDiceRoller([]),
      ).state;

      expect(state.players.single.backpack, contains('event-supply'));
    },
  );

  test(
    'immediate event spawn starts an out-of-turn dodge and counterattack',
    () {
      var state = _mvpState(
        eventId: 'invasion-card',
        playerCoord: const HexCoord(0, 2),
        eventDefinitions: {
          'invasion-card': {
            'id': 'invasion-card',
            'locationId': 'crew-mess',
            'immediateCombat': true,
            'spawn': {
              'behaviorId': 'monster.spawn',
              'target': 'location',
              'fallback': 'closedSector',
            },
            'options': [
              {
                'skillCheck': null,
                'behaviorId': 'monster.spawn',
                'resolution': 'immediate',
              },
            ],
          },
        },
        monsterDefinitions: {
          'ghoul': {
            'health': 2,
            'defense': 0,
            'attack': 2,
            'movement': 1,
          },
        },
        additionalDecks: {
          'monsters': DeckState(drawPile: const ['ghoul']),
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([1, 6]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:2')),
        FixedDiceRoller([]),
      ).state;

      expect(state.pendingDecision, isA<AwaitingDodge>());
      expect(state.monsters.single.monsterId, 'ghoul');
      expect(state.decks['monsters']!.drawPile, isEmpty);

      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1, 6]),
      ).state;

      expect(state.pendingDecision, isNull);
      expect(state.monsters.single.damage, 1);
      expect(state.players.single.damage, 2);
      expect(state.actionsLeft, 2);
      expect(state.phase, GamePhase.playersTurn);

      state = step(
        state,
        const AttackCommand('event-1-1-invasion-card-ghoul'),
        FixedDiceRoller([6]),
      ).state;
      expect(state.monsters, isEmpty);
      expect(state.decks['monsters']!.discardPile, ['ghoul']);
    },
  );

  test(
    'immediate Nest spawn resolves Boil before counterattack',
    () {
      var state = _mvpState(
        eventId: 'invasion-card',
        playerCoord: const HexCoord(0, 2),
        heroCount: 2,
        eventDefinitions: {
          'invasion-card': {
            'id': 'invasion-card',
            'locationId': 'crew-mess',
            'immediateCombat': true,
            'spawn': {
              'behaviorId': 'monster.spawn',
              'target': 'location',
              'fallback': 'closedSector',
            },
            'options': [
              {
                'skillCheck': null,
                'behaviorId': 'monster.spawn',
                'resolution': 'immediate',
              },
            ],
          },
        },
        monsterDefinitions: {
          'nest': {
            'health': 2,
            'defense': 0,
            'attack': 0,
            'movement': 0,
            'features': ['stationary', 'spawns-boil-instead-of-attack'],
          },
        },
        additionalDecks: {
          'monsters': DeckState(drawPile: const ['nest']),
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:2')),
        FixedDiceRoller([]),
      ).state;

      var dodge = state.pendingDecision! as AwaitingDodge;
      expect(dodge.source, DamageSource.boil);
      expect(dodge.targetPlayerId, 'ada');
      expect(dodge.counterAttackMonsterInstanceId, contains('-nest'));
      expect(dodge.counterAttackPlayerId, 'ada');
      expect(state.boils, isEmpty);
      expect(state.monsters.single.damage, 0);

      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([6]),
      ).state;

      dodge = state.pendingDecision! as AwaitingDodge;
      expect(dodge.source, DamageSource.boil);
      expect(dodge.targetPlayerId, 'hero-2');
      expect(dodge.counterAttackMonsterInstanceId, contains('-nest'));
      expect(dodge.counterAttackPlayerId, 'ada');
      expect(state.monsters.single.damage, 0);

      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1, 6]),
      ).state;

      expect(state.players.first.damage, 0);
      expect(state.players.last.damage, 1);
      expect(state.monsters.single.damage, 1);
      expect(state.phase, GamePhase.eventsPhase);
    },
  );

  test('Nest counterattack resumes after another hero is replaced', () {
    var state = _mvpState(
      eventId: 'invasion-card',
      playerCoord: const HexCoord(0, 2),
      heroCount: 2,
      secondHeroDamage: 2,
      reserveHeroes: [
        ReserveHero(
          characterId: 'scientist',
          health: 3,
          stats: const PlayerStats(science: 1, agility: 1),
        ),
      ],
      eventDefinitions: {
        'invasion-card': {
          'id': 'invasion-card',
          'locationId': 'crew-mess',
          'immediateCombat': true,
          'spawn': {
            'behaviorId': 'monster.spawn',
            'target': 'location',
            'fallback': 'closedSector',
          },
          'options': [
            {
              'skillCheck': null,
              'behaviorId': 'monster.spawn',
              'resolution': 'immediate',
            },
          ],
        },
      },
      monsterDefinitions: {
        'nest': {
          'health': 2,
          'defense': 0,
          'attack': 0,
          'movement': 0,
          'features': ['stationary', 'spawns-boil-instead-of-attack'],
        },
      },
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['nest']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:2')),
      FixedDiceRoller([]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([1]),
    ).state;

    final replacement = state.pendingDecision! as AwaitingHeroReplacement;
    expect(replacement.counterAttackMonsterInstanceId, contains('-nest'));
    expect(replacement.counterAttackPlayerId, 'ada');
    state = step(
      state,
      const ResolvePendingDecisionCommand(
        SelectReplacementHeroChoice('scientist'),
      ),
      FixedDiceRoller([6]),
    ).state;

    expect(state.players.last.characterId, 'scientist');
    expect(state.players.last.alive, isTrue);
    expect(
      state.monsters
          .where((monster) => monster.monsterId == 'nest')
          .single
          .damage,
      1,
    );
  });

  test('full inventory changes complete collect-item quests', () {
    final item = CardDefinition.fromJson({
      'id': 'quest-item',
      'category': 'supply',
      'slots': <Object?>[],
      'cost': 0,
      'stats': <String, int>{},
    });
    final state = step(
      _mvpState(
        storyQuestIds: const ['quest-01'],
        questDefinitions: {
          'quest-01': {
            'id': 'quest-01',
            'number': 1,
            'chapter': 1,
            'conditions': [
              {
                'id': 'collect-item',
                'type': 'collect_item',
                'itemId': 'quest-item',
              },
            ],
            'reward': {'credits': 0, 'items': <Object?>[]},
            'nextQuestIds': <Object?>[],
            'nameKey': 'quest-01.name',
            'descKey': 'quest-01.description',
          },
        },
        cardDefinitions: {'quest-item': item},
      ),
      const ReceiveCardCommand('quest-item'),
      FixedDiceRoller([]),
    ).state;

    expect(state.quests.statusOf('quest-01'), QuestStatus.completed);
    expect(state.players.single.backpack, ['quest-item']);
  });

  test('assigned personal tasks record progress and grant their reward', () {
    final state = step(
      _mvpState(
        initialCredits: 15,
        personalTasksByPlayer: const {
          'ada': ['wealthy-test'],
        },
        taskDefinitions: {
          'wealthy-test': {
            'id': 'wealthy-test',
            'targetType': 'metric',
            'metric': 'credits',
            'targetValue': 15,
            'window': 'game',
            'aggregation': 'maximum',
            'rewardCredits': 5,
            'nameKey': 'task.wealthy.name',
            'descKey': 'task.wealthy.description',
          },
        },
      ),
      const HealCommand(1),
      FixedDiceRoller([]),
    ).state;

    expect(state.quests.statusOf('wealthy-test'), QuestStatus.completed);
    expect(
      state.quests.conditionProgress['wealthy-test']?['personal-task-value'],
      15,
    );
    expect(state.players.single.credits, 20);
    expect(state.log.join(' '), isNot(contains('wealthy-test')));
  });

  test('enemy kills advance only the attacking player personal task', () {
    var state = _mvpState(
      heroCount: 2,
      personalTasksByPlayer: const {
        'ada': ['hunter-ada'],
        'hero-2': ['hunter-hero-2'],
      },
      taskDefinitions: {
        for (final id in ['hunter-ada', 'hunter-hero-2'])
          id: {
            'id': id,
            'targetType': 'metric',
            'metric': 'enemies_killed',
            'targetValue': 1,
            'window': 'perTurn',
            'aggregation': 'sum',
            'rewardCredits': 5,
            'nameKey': 'task.hunter.name',
            'descKey': 'task.hunter.description',
          },
      },
      monsters: [
        MonsterInstance(
          instanceId: 'hunter-target',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
        ),
      ],
    );

    state = step(
      state,
      const AttackCommand('hunter-target'),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(state.quests.statusOf('hunter-ada'), QuestStatus.completed);
    expect(state.quests.statusOf('hunter-hero-2'), QuestStatus.active);
    expect(
      state.quests.conditionProgress['hunter-hero-2']?['personal-task-value'],
      isNull,
    );
    expect(state.players.firstWhere((player) => player.id == 'ada').credits, 5);
    expect(
      state.players.firstWhere((player) => player.id == 'hero-2').credits,
      0,
    );
  });

  test('immediate event counterattack advances personal kill tasks', () {
    var state = _mvpState(
      eventId: 'invasion-card',
      playerCoord: const HexCoord(0, 2),
      personalTasksByPlayer: const {
        'ada': ['event-hunter', 'event-exterminator'],
      },
      taskDefinitions: {
        'event-hunter': {
          'id': 'event-hunter',
          'targetType': 'metric',
          'metric': 'enemies_killed',
          'targetValue': 1,
          'window': 'perTurn',
          'aggregation': 'sum',
          'rewardCredits': 5,
          'nameKey': 'task.hunter.name',
          'descKey': 'task.hunter.description',
        },
        'event-exterminator': {
          'id': 'event-exterminator',
          'targetType': 'metric',
          'metric': 'strong_enemy_solo',
          'targetValue': 1,
          'window': 'perTurn',
          'aggregation': 'sum',
          'rewardCredits': 5,
          'nameKey': 'task.exterminator.name',
          'descKey': 'task.exterminator.description',
        },
      },
      eventDefinitions: {
        'invasion-card': {
          'id': 'invasion-card',
          'locationId': 'crew-mess',
          'immediateCombat': true,
          'spawn': {
            'behaviorId': 'monster.spawn',
            'target': 'location',
            'fallback': 'closedSector',
          },
          'options': [
            {
              'skillCheck': null,
              'behaviorId': 'monster.spawn',
              'resolution': 'immediate',
            },
          ],
        },
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 1,
          'defense': 0,
          'attack': 2,
          'movement': 1,
          'features': ['strong'],
        },
      },
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('sector:0:2')),
      FixedDiceRoller([]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingDodge>());

    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([1, 6]),
    ).state;

    expect(state.monsters, isEmpty);
    expect(state.quests.statusOf('event-hunter'), QuestStatus.completed);
    expect(state.quests.statusOf('event-exterminator'), QuestStatus.completed);
    expect(state.players.single.credits, 10);
  });

  test('full quest rewards draw items for players at the target location', () {
    final items = {
      for (final id in ['item-a', 'item-b', 'item-c'])
        id: CardDefinition.fromJson({
          'id': id,
          'category': 'supply',
          'slots': <Object?>[],
          'cost': 0,
          'stats': <String, int>{},
        }),
    };
    var state = _mvpState(
      playerCoord: const HexCoord(0, 2),
      storyQuestIds: const ['quest-01'],
      questDefinitions: {
        'quest-01': {
          'id': 'quest-01',
          'number': 1,
          'chapter': 1,
          'targetLocation': 'crew-mess',
          'conditions': [
            {
              'id': 'science-check',
              'type': 'skill_check',
              'skill': 'science',
              'locationId': 'crew-mess',
            },
          ],
          'reward': {
            'credits': 0,
            'items': <Object?>[],
            'drawItemsPerPlayerAtTargetLocation': 2,
          },
          'nextQuestIds': <Object?>[],
          'nameKey': 'quest-01.name',
          'descKey': 'quest-01.description',
        },
      },
      cardDefinitions: items,
      additionalDecks: {
        'items': DeckState(drawPile: const ['item-a', 'item-b', 'item-c']),
      },
    );
    state = step(
      state,
      const SkillCheckCommand(StatType.science),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, ['item-a', 'item-b']);
    expect(state.decks['items']!.drawPile, ['item-c']);
  });

  test('killing a monster advances damage-token quest counters', () {
    var state = _mvpState(
      storyQuestIds: const ['quest-01'],
      questDefinitions: {
        'quest-01': {
          'id': 'quest-01',
          'number': 1,
          'chapter': 1,
          'conditions': [
            {
              'id': 'damage-token',
              'type': 'counter',
              'metric': 'damage_tokens_collected',
              'targetValue': 1,
            },
          ],
          'reward': {'credits': 0, 'items': <Object?>[]},
          'nextQuestIds': <Object?>[],
          'nameKey': 'quest-01.name',
          'descKey': 'quest-01.description',
        },
      },
      monsters: [
        MonsterInstance(
          instanceId: 'ghoul-1',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
        ),
      ],
    );
    state = step(
      state,
      const AttackCommand('ghoul-1'),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(state.quests.statusOf('quest-01'), QuestStatus.completed);
  });

  test(
    'quest victory stays complete when a chained event advances another quest',
    () {
      final state = step(
        _mvpState(
          storyQuestIds: const ['quest-11'],
          questDefinitions: {
            'quest-11': {
              'id': 'quest-11',
              'number': 11,
              'chapter': 3,
              'conditions': [
                {
                  'id': 'kill-mother',
                  'type': 'kill_monster',
                  'monsterId': 'mother',
                },
              ],
              'reward': {'credits': 0, 'items': <Object?>[]},
              'nextQuestIds': ['quest-12', 'quest-13'],
              'nameKey': 'quest-11.name',
              'descKey': 'quest-11.description',
            },
            'quest-12': {
              'id': 'quest-12',
              'number': 12,
              'chapter': 3,
              'prerequisiteQuestIds': ['quest-11'],
              'conditions': <Object?>[],
              'reward': {'credits': 0, 'items': <Object?>[]},
              'nextQuestIds': <Object?>[],
              'endsGame': true,
              'nameKey': 'quest-12.name',
              'descKey': 'quest-12.description',
            },
            'quest-13': {
              'id': 'quest-13',
              'number': 13,
              'chapter': 3,
              'prerequisiteQuestIds': ['quest-11'],
              'conditions': [
                {
                  'id': 'later-counter',
                  'type': 'counter',
                  'metric': 'damage_tokens_collected',
                  'targetValue': 3,
                },
              ],
              'reward': {'credits': 0, 'items': <Object?>[]},
              'nextQuestIds': <Object?>[],
              'nameKey': 'quest-13.name',
              'descKey': 'quest-13.description',
            },
          },
          monsters: [
            MonsterInstance(
              instanceId: 'mother-1',
              monsterId: 'mother',
              coord: const HexCoord(0, 0),
              damage: 0,
            ),
          ],
        ),
        const AttackCommand('mother-1'),
        FixedDiceRoller([6]),
      ).state;

      expect(state.quests.statusOf('quest-12'), QuestStatus.completed);
      expect(state.quests.statusOf('quest-13'), QuestStatus.active);
      expect(state.isComplete, isTrue);
    },
  );

  test('spawned bosses apply runtime hero and living-monster scaling', () {
    for (final scenario in [
      (
        id: 'viy',
        heroCount: 3,
        existingMonsters: <MonsterInstance>[],
        scaling: {
          'healthPerHero': 1,
          'attackPerHero': 1,
          'healthPerAliveMonster': 0,
          'attackPerAliveMonster': 0,
        },
        baseHealth: 4,
        baseAttack: 3,
        expectedHealth: 7,
        expectedAttack: 6,
      ),
      (
        id: 'swarm',
        heroCount: 1,
        existingMonsters: [
          MonsterInstance(
            instanceId: 'ghoul-1',
            monsterId: 'ghoul',
            coord: const HexCoord(0, 0),
            damage: 0,
            health: 2,
          ),
        ],
        scaling: {
          'healthPerHero': 0,
          'attackPerHero': 0,
          'healthPerAliveMonster': 1,
          'attackPerAliveMonster': 1,
        },
        baseHealth: 3,
        baseAttack: 3,
        expectedHealth: 4,
        expectedAttack: 4,
      ),
    ]) {
      var state = _mvpState(
        playerCoord: const HexCoord(0, 2),
        heroCount: scenario.heroCount,
        storyQuestIds: const ['quest-01'],
        questDefinitions: {
          'quest-01': {
            'id': 'quest-01',
            'number': 1,
            'chapter': 1,
            'conditions': [
              {
                'id': 'complete-check',
                'type': 'skill_check',
                'skill': 'science',
                'locationId': 'crew-mess',
              },
            ],
            'reward': {'credits': 0, 'items': <Object?>[]},
            'nextQuestIds': ['quest-02'],
            'nameKey': 'quest-01.name',
            'descKey': 'quest-01.description',
          },
          'quest-02': {
            'id': 'quest-02',
            'number': 2,
            'chapter': 1,
            'prerequisiteQuestIds': ['quest-01'],
            'conditions': [
              {
                'id': 'wait',
                'type': 'counter',
                'metric': 'damage_tokens_collected',
                'targetValue': 99,
              },
            ],
            'reward': {'credits': 0, 'items': <Object?>[]},
            'nextQuestIds': <Object?>[],
            'spawnMonsterId': scenario.id,
            'spawnLocationId': 'crew-mess',
            'nameKey': 'quest-02.name',
            'descKey': 'quest-02.description',
          },
        },
        monsters: scenario.existingMonsters,
        monsterDefinitions: {
          scenario.id: {
            'id': scenario.id,
            'health': scenario.baseHealth,
            'attack': scenario.baseAttack,
            'defense': 2,
            'movement': 2,
            'scaling': scenario.scaling,
          },
        },
      );
      state = step(
        state,
        const SkillCheckCommand(StatType.science),
        FixedDiceRoller([6]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(KeepRollChoice()),
        FixedDiceRoller([]),
      ).state;

      final spawned = state.monsters.singleWhere(
        (monster) => monster.monsterId == scenario.id,
      );
      expect(spawned.health, scenario.expectedHealth, reason: scenario.id);
      expect(spawned.attack, scenario.expectedAttack, reason: scenario.id);
    }
  });

  test(
    'successful agility checks in ventilation advance full quest counters',
    () {
      var state = _mvpState(
        playerCoord: const HexCoord(0, 1),
        storyQuestIds: const ['quest-01'],
        questDefinitions: {
          'quest-01': {
            'id': 'quest-01',
            'number': 1,
            'chapter': 1,
            'conditions': [
              {
                'id': 'ventilation-check',
                'type': 'counter',
                'metric': 'agility_check_in_ventilation',
              },
            ],
            'reward': {'credits': 0, 'items': <Object?>[]},
            'nextQuestIds': <Object?>[],
            'nameKey': 'quest-01.name',
            'descKey': 'quest-01.description',
          },
        },
        corridorVentColor: VentColor.green,
      );
      state = step(
        state,
        const SkillCheckCommand(StatType.agility),
        FixedDiceRoller([6]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(KeepRollChoice()),
        FixedDiceRoller([]),
      ).state;

      expect(state.quests.statusOf('quest-01'), QuestStatus.completed);
    },
  );

  test('runs the MVP from the first step through Quest 1 completion', () {
    var state = _mvpState(
      eventDefinitions: {
        'cabin-noise': {
          'options': [
            {
              'skillCheck': {'skill': 'agility', 'difficulty': 1},
              'behaviorId': 'event_cabin_noise',
            },
          ],
        },
      },
    );

    state = step(
      state,
      const MoveCommand(HexCoord(0, 1)),
      FixedDiceRoller([]),
    ).state;
    expect(state.actionsLeft, 0);
    expect(state.players.single.coord, const HexCoord(0, 1));

    // Ending the player phase automatically runs monsters, then draws the
    // eligible hero's event. There are no monsters in this first MVP round.
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    expect(state.phase, GamePhase.eventsPhase);
    expect(state.pendingDecision, isA<AwaitingEventOption>());

    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([6]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingRerollChoice>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;
    expect(state.phase, GamePhase.playersTurn);
    expect(state.round, 2);
    expect(state.players.single.backpack, contains('event-supply'));

    state = step(
      state,
      const MoveCommand(HexCoord(0, 2)),
      FixedDiceRoller([]),
    ).state;
    expect(state.players.single.coord, const HexCoord(0, 2));
    expect(state.tileAt(const HexCoord(0, 2))!.opened, isTrue);

    // The exhausted event deck recycles its discard, so the same event is
    // drawn again before the next player turn begins.
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    expect(state.pendingDecision, isA<AwaitingEventOption>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([6]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;
    expect(state.phase, GamePhase.playersTurn);
    expect(state.round, 3);
    expect(state.actionsLeft, 2);

    state = step(
      state,
      const SkillCheckCommand(StatType.science),
      FixedDiceRoller([5]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingRerollChoice>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(
      state.quests.statusOf('chapter-1-awakening'),
      QuestStatus.completed,
    );
    expect(state.isComplete, isTrue);
    expect(state.gameEvents.single, isA<MvpDemonstrationCompleted>());
  });
}

GameState _mvpState({
  String eventId = 'cabin-noise',
  Map<String, Map<String, Object?>> eventDefinitions = const {},
  HexCoord playerCoord = const HexCoord(0, 0),
  List<String> storyQuestIds = const ['chapter-1-awakening'],
  Map<PlayerId, Iterable<String>> personalTasksByPlayer = const {},
  Map<String, Map<String, int>> conditionProgress = const {},
  Map<String, Map<String, Object?>> questDefinitions = const {},
  Map<String, Map<String, Object?>> taskDefinitions = const {},
  Map<CardId, CardDefinition> cardDefinitions = const {},
  Map<DeckId, DeckState> additionalDecks = const {},
  Iterable<MonsterInstance> monsters = const [],
  Map<String, Map<String, Object?>> monsterDefinitions = const {},
  int heroCount = 1,
  int secondHeroDamage = 0,
  Iterable<ReserveHero> reserveHeroes = const [],
  int initialCredits = 0,
  VentColor corridorVentColor = VentColor.none,
  bool corridorOpened = false,
}) => GameState(
  seed: 17,
  round: 1,
  phase: GamePhase.playersTurn,
  activePlayerId: 'ada',
  actionsLeft: 2,
  board: [
    _tile(
      id: 'anabiosis',
      coord: const HexCoord(0, 0),
      type: HexTileType.start,
      opened: true,
      exits: const {HexEdge.south},
    ),
    _tile(
      id: 'corridor',
      coord: const HexCoord(0, 1),
      type: HexTileType.corridor,
      opened: corridorOpened,
      exits: const {HexEdge.north, HexEdge.south},
      ventColor: corridorVentColor,
    ),
    _tile(
      id: 'crew-mess',
      coord: const HexCoord(0, 2),
      type: HexTileType.compartment,
      opened: false,
      exits: const {HexEdge.north},
      locationId: 'crew-mess',
    ),
  ],
  players: [
    for (var index = 0; index < heroCount; index++)
      PlayerState(
        id: index == 0 ? 'ada' : 'hero-${index + 1}',
        characterId: index == 0 ? 'engineer' : 'guard',
        coord: playerCoord,
        damage: index == 1 ? secondHeroDamage : 0,
        credits: initialCredits,
        backpack: const [],
        equipped: const EquippedGear(),
        carriedMods: const [],
        implanted: const [],
        conditions: const [],
        alive: true,
        stats: const PlayerStats(science: 1, agility: 1),
      ),
  ],
  monsters: monsters,
  reserveHeroes: reserveHeroes,
  decks: {
    'events': DeckState(drawPile: [eventId]),
    ...additionalDecks,
  },
  cardDefinitions: cardDefinitions,
  eventDefinitions: eventDefinitions,
  questDefinitions: questDefinitions,
  taskDefinitions: taskDefinitions,
  monsterDefinitions: monsterDefinitions,
  quests: QuestState(
    storyQuestIds: storyQuestIds,
    personalTasksByPlayer: personalTasksByPlayer,
    conditionProgress: conditionProgress,
  ),
);

HexTile _tile({
  required String id,
  required HexCoord coord,
  required HexTileType type,
  required bool opened,
  required Set<HexEdge> exits,
  String? locationId,
  VentColor ventColor = VentColor.none,
}) => HexTile(
  id: id,
  coord: coord,
  type: type,
  opened: opened,
  exits: exits,
  locationId: locationId,
  hasTerminal: false,
  ventColor: ventColor,
);
