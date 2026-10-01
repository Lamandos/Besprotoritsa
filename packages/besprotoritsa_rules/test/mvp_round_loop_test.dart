import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  test(
    'arrival objective counts heroes already at its location on activation',
    () {
      final questDefinitions = {
        'quest-01': {
          'id': 'quest-01',
          'number': 1,
          'chapter': 1,
          'conditions': [
            {
              'id': 'arrive-crew-mess',
              'type': 'arrive',
              'locationId': 'crew-mess',
            },
            {
              'id': 'science-crew-mess',
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
          'conditions': [
            {
              'id': 'return-crew-mess',
              'type': 'arrive',
              'locationId': 'crew-mess',
            },
          ],
          'reward': {'credits': 0, 'items': <Object?>[]},
          'nextQuestIds': <Object?>[],
          'endsGame': true,
          'nameKey': 'quest-02.name',
          'descKey': 'quest-02.description',
        },
      };
      var state = _mvpState(
        playerCoord: const HexCoord(0, 2),
        storyQuestIds: const ['quest-01'],
        conditionProgress: const {
          'quest-01': {'arrive-crew-mess': 1},
        },
        questDefinitions: questDefinitions,
      );

      state = step(
        state,
        const SkillCheckCommand(StatType.science),
        FixedDiceRoller([6]),
      ).state;
      if (state.pendingDecision != null) {
        state = step(
          state,
          const ResolvePendingDecisionCommand(KeepRollChoice()),
          FixedDiceRoller([]),
        ).state;
      }

      expect(state.quests.statusOf('quest-01'), QuestStatus.completed);
      expect(state.quests.statusOf('quest-02'), QuestStatus.completed);
      expect(
        state.quests.conditionProgress['quest-02']?['return-crew-mess'],
        1,
      );
      expect(state.isComplete, isTrue);
    },
  );

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
        additionalDecks: {
          'supplies': DeckState(drawPile: const ['ration']),
        },
        cardDefinitions: {
          'ration': CardDefinition(
            id: 'ration',
            type: ItemType.supply,
            slots: const [],
            cost: 0,
            staticEffects: CardStaticEffects(const {}),
          ),
        },
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
                'successEffects': [
                  {'type': 'draw', 'deckId': 'supplies', 'amount': 1},
                ],
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

      expect(state.players.single.backpack, contains('ration'));
    },
  );

  test('event outcome plans apply failed skill consequences', () {
    var state = _mvpState(
      eventId: 'verified-event',
      eventDefinitions: {
        'verified-event': {
          'options': [
            {
              'skillCheck': {'skill': 'agility', 'difficulty': 1},
              'successEffects': [
                {'type': 'credits', 'amount': 5},
              ],
              'failureEffects': [
                {'type': 'damage', 'amount': 2},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([1]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.damage, 2);
    expect(state.players.single.credits, 0);
  });

  test('combat-strength event bonus adds a die to later attacks', () {
    var state = _mvpState(
      eventId: 'combat-strength-event',
      playerStats: const PlayerStats(strength: 2, combatStrength: 2),
      monsters: [
        MonsterInstance(
          instanceId: 'test-enemy',
          monsterId: 'ghoul',
          coord: const HexCoord(0, 0),
          damage: 0,
          health: 4,
        ),
      ],
      eventDefinitions: {
        'combat-strength-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {
                  'type': 'stat_bonus',
                  'stat': 'combatStrength',
                  'amount': 1,
                },
              ],
              'failureEffects': [
                {
                  'type': 'stat_bonus',
                  'stat': 'combatStrength',
                  'amount': 1,
                },
              ],
            },
          ],
        },
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
      const AttackCommand('test-enemy'),
      FixedDiceRoller([6, 6, 6]),
    ).state;

    expect(state.monsters.single.damage, 3);
  });

  test('kept event cards return to the event discard when their hero dies', () {
    var state = _mvpState(
      eventId: 'scientist-report',
      eventDefinitions: {
        'scientist-report': {
          'id': 'scientist-report',
          'behaviorIds': ['event.choice', 'event.successFailure'],
          'options': [
            {
              'skillCheck': null,
              'autoOutcome': 'success',
              'behaviorId': 'event.successFailure',
              'successEffects': [
                {
                  'type': 'stat_bonus',
                  'stat': 'science',
                  'amount': 1,
                  'retainEventCard': true,
                },
              ],
              'failureEffects': [
                {'type': 'no_effect'},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.retainedEventCards, ['scientist-report']);
    expect(state.decks['events']!.discardPile, isEmpty);

    final hero = state.players.single;
    final dyingHero = PlayerState(
      id: hero.id,
      characterId: hero.characterId,
      coord: hero.coord,
      damage: hero.health,
      health: hero.health,
      credits: hero.credits,
      backpack: hero.backpack,
      equipped: hero.equipped,
      carriedMods: hero.carriedMods,
      implanted: hero.implanted,
      conditions: hero.conditions,
      retainedEventCards: hero.retainedEventCards,
      alive: true,
      stats: hero.stats,
    );
    final deathState = GameState(
      seed: state.seed,
      round: state.round,
      phase: GamePhase.playersTurn,
      activePlayerId: hero.id,
      actionsLeft: 0,
      board: state.board,
      players: [dyingHero],
      monsters: const [],
      decks: state.decks,
      quests: state.quests,
    );
    final resolvedDeath = resolveHeroDeaths(deathState);

    expect(resolvedDeath.players.single.retainedEventCards, isEmpty);
    expect(
      resolvedDeath.decks['events']!.discardPile,
      ['scientist-report'],
    );
  });

  test('meteor damage queues a replacement for every fallen hero', () {
    final reserveHeroes = [
      ReserveHero(
        characterId: 'scientist',
        health: 3,
        stats: const PlayerStats(),
      ),
      ReserveHero(characterId: 'pilot', health: 3, stats: const PlayerStats()),
    ];
    var state = _mvpState(
      eventId: 'mass-casualty',
      heroCount: 2,
      playerHealth: 1,
      reserveHeroes: reserveHeroes,
      eventDefinitions: {
        'mass-casualty': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'damage_all_players', 'amount': 1},
              ],
              'failureEffects': [
                {'type': 'damage_all_players', 'amount': 1},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    var replacement = state.pendingDecision! as AwaitingHeroReplacement;
    expect(replacement.playerId, 'ada');
    expect(replacement.remainingPlayerIds, ['hero-2']);
    state = step(
      state,
      const ResolvePendingDecisionCommand(
        SelectReplacementHeroChoice('scientist'),
      ),
      FixedDiceRoller([]),
    ).state;

    replacement = state.pendingDecision! as AwaitingHeroReplacement;
    expect(replacement.playerId, 'hero-2');
    expect(replacement.characterIds, ['pilot']);
    state = step(
      state,
      const ResolvePendingDecisionCommand(SelectReplacementHeroChoice('pilot')),
      FixedDiceRoller([]),
    ).state;

    expect(
      state.players.map((hero) => hero.characterId),
      containsAll(['scientist', 'pilot']),
    );
    expect(state.players.every((hero) => hero.alive), isTrue);
    expect(state.isComplete, isFalse);
  });

  test(
    'queued replacement activates when simultaneous deaths exhaust reserves',
    () {
      var state = _mvpState(
        eventId: 'mass-casualty',
        heroCount: 2,
        playerHealth: 1,
        reserveHeroes: [
          ReserveHero(
            characterId: 'scientist',
            health: 3,
            stats: const PlayerStats(),
          ),
        ],
        eventDefinitions: {
          'mass-casualty': {
            'options': [
              {
                'skillCheck': null,
                'successEffects': [
                  {'type': 'damage_all_players', 'amount': 1},
                ],
                'failureEffects': [
                  {'type': 'damage_all_players', 'amount': 1},
                ],
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;

      expect(state.pendingDecision, isA<AwaitingHeroReplacement>());
      state = step(
        state,
        const ResolvePendingDecisionCommand(
          SelectReplacementHeroChoice('scientist'),
        ),
        FixedDiceRoller([]),
      ).state;

      expect(
        state.players.map((hero) => hero.characterId),
        contains('scientist'),
      );
      expect(
        state.players
            .singleWhere((hero) => hero.characterId == 'scientist')
            .alive,
        isTrue,
      );
      expect(state.isComplete, isFalse);
    },
  );

  test('event spawn grants its configured deck reward after victory', () {
    var state = _mvpState(
      eventId: 'reward-event',
      eventDefinitions: {
        'reward-event': {
          'options': [
            {
              'skillCheck': null,
              'autoOutcome': 'success',
              'successEffects': [
                {'type': 'spawn_monster', 'defeatRewardDeckId': 'items'},
              ],
              'failureEffects': [
                {'type': 'no_effect'},
              ],
            },
          ],
        },
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 1,
          'defense': 0,
          'attack': 0,
          'movement': 0,
        },
      },
      cardDefinitions: {
        'ration': CardDefinition(
          id: 'ration',
          type: ItemType.supply,
          slots: const [],
          cost: 0,
          staticEffects: CardStaticEffects(const {}),
        ),
      },
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
        'items': DeckState(drawPile: const ['ration']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([6]),
    ).state;

    expect(state.monsters, isEmpty);
    expect(state.players.single.backpack, contains('ration'));
    expect(state.decks['items']!.drawPile, isEmpty);
  });

  test(
    'events without a printed check use their declared automatic outcome',
    () {
      var state = _mvpState(
        eventId: 'automatic-event',
        eventDefinitions: {
          'automatic-event': {
            'id': 'automatic-event',
            'options': [
              {
                'skillCheck': null,
                'autoOutcome': 'success',
                'successEffects': [
                  {'type': 'credits', 'amount': 2},
                ],
                'failureEffects': [
                  {'type': 'damage', 'amount': 1},
                ],
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      expect(state.players.single.credits, 2);
      expect(state.players.single.damage, 0);
    },
  );

  test('event options requiring a card are hidden when it is not owned', () {
    var state = _mvpState(
      eventId: 'required-card-event',
      eventDefinitions: {
        'required-card-event': {
          'id': 'required-card-event',
          'options': [
            {'skillCheck': null, 'requiresCard': 'gas-cylinder'},
            {'skillCheck': null},
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    final event = state.pendingDecision! as AwaitingEventOption;
    expect(event.options, ['option-2']);
  });

  test('horde carry lets the hero discard the whole backpack', () {
    final definitions = {
      'ration': CardDefinition(
        id: 'ration',
        type: ItemType.supply,
        slots: const [],
        cost: 1,
        staticEffects: CardStaticEffects(const {}),
      ),
      'flare': CardDefinition(
        id: 'flare',
        type: ItemType.supply,
        slots: const [],
        cost: 1,
        staticEffects: CardStaticEffects(const {}),
      ),
    };
    var state = _mvpState(
      eventId: 'horde-carry',
      playerBackpack: const ['ration', 'flare'],
      cardDefinitions: definitions,
      eventDefinitions: {
        'horde-carry': {
          'id': 'horde-carry',
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'horde_backpack_choice'},
              ],
              'failureEffects': [
                {'type': 'horde_backpack_choice'},
              ],
            },
          ],
        },
      },
      additionalDecks: {
        'supplies': DeckState(drawPile: const []),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    final decision = state.pendingDecision! as AwaitingEventOption;
    expect(decision.options, ['horde|discard', 'horde|keep']);
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('horde|discard')),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, isEmpty);
    expect(state.players.single.damage, 0);
    expect(state.decks['supplies']!.discardPile.toSet(), {'ration', 'flare'});
  });

  test('horde carry damage scales with the cards kept', () {
    var state = _mvpState(
      eventId: 'horde-carry',
      playerBackpack: const ['ration', 'flare'],
      playerHealth: 10,
      eventDefinitions: {
        'horde-carry': {
          'id': 'horde-carry',
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'horde_backpack_choice'},
              ],
              'failureEffects': [
                {'type': 'horde_backpack_choice'},
              ],
            },
          ],
        },
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
      const ResolvePendingDecisionCommand(EventOptionChoice('horde|keep')),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.damage, 4);
    expect(state.players.single.backpack, ['ration', 'flare']);
  });

  test('choosing one duplicate card returns the other physical copy', () {
    final definitions = {
      for (final id in ['flare', 'water'])
        id: CardDefinition(
          id: id,
          type: ItemType.supply,
          slots: const [],
          cost: 1,
          staticEffects: CardStaticEffects(const {}),
        ),
    };
    var state = _mvpState(
      eventId: 'duplicate-selection',
      cardDefinitions: definitions,
      additionalDecks: {
        'supplies': DeckState(drawPile: const ['flare', 'flare', 'water']),
      },
      eventDefinitions: {
        'duplicate-selection': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'choose_from_top', 'deckId': 'supplies', 'amount': 3},
              ],
              'failureEffects': [
                {'type': 'choose_from_top', 'deckId': 'supplies', 'amount': 3},
              ],
            },
          ],
        },
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
      const ResolvePendingDecisionCommand(
        EventOptionChoice('pick:supplies:flare'),
      ),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, ['flare']);
    expect(state.decks['supplies']!.drawPile, hasLength(2));
    expect(state.decks['supplies']!.drawPile.toSet(), {'flare', 'water'});
  });

  test('failed Whisper places a monster in each adjacent open sector', () {
    var state = _mvpState(
      eventId: 'female-whisper',
      corridorOpened: true,
      eventDefinitions: {
        'female-whisper': {
          'id': 'female-whisper',
          'options': [
            {
              'skillCheck': null,
              'autoOutcome': 'failure',
              'failureEffects': [
                {'type': 'spawn_monsters_adjacent'},
              ],
            },
          ],
        },
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 2,
          'defense': 0,
          'attack': 1,
          'movement': 1,
          'features': <String>[],
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

    expect(state.monsters.single.coord, const HexCoord(0, 1));
    expect(state.pendingDecision, isNull);
    expect(state.players.single.damage, 0);
  });

  test(
    'monster immunity blocks immediate monster damage through next round',
    () {
      var state = _mvpState(
        eventId: 'immunity-event',
        eventDefinitions: {
          'immunity-event': {
            'id': 'immunity-event',
            'options': [
              {
                'skillCheck': null,
                'autoOutcome': 'success',
                'successEffects': [
                  {'type': 'monster_damage_immunity'},
                  {'type': 'spawn_monster'},
                ],
              },
            ],
          },
        },
        monsterDefinitions: {
          'ghoul': {
            'health': 10,
            'defense': 10,
            'attack': 2,
            'movement': 1,
            'features': <String>[],
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
        FixedDiceRoller([1, 1, 1, 1, 1, 1]),
      ).state;

      expect(state.players.single.damage, 0);
      expect(state.players.single.monsterDamageImmuneThroughRound, 2);
      expect(state.pendingDecision, isNull);
    },
  );

  test('event markets allow discounted buys and return untouched offers', () {
    final definitions = <String, CardDefinition>{
      for (final entry in const [
        ('ration', 3),
        ('flare', 2),
        ('medkit', 4),
      ])
        entry.$1: CardDefinition(
          id: entry.$1,
          type: ItemType.supply,
          slots: const [],
          cost: entry.$2,
          staticEffects: CardStaticEffects(const {}),
        ),
    };
    var state = _mvpState(
      eventId: 'market-event',
      initialCredits: 5,
      cardDefinitions: definitions,
      eventDefinitions: {
        'market-event': {
          'id': 'market-event',
          'options': [
            {
              'skillCheck': null,
              'autoOutcome': 'success',
              'successEffects': [
                {
                  'type': 'market',
                  'offers': 3,
                  'maxPurchases': 2,
                  'discount': 2,
                  'allowSell': true,
                },
              ],
              'failureEffects': [
                {'type': 'no_effect'},
              ],
            },
          ],
        },
      },
      additionalDecks: {
        'supplies': DeckState(drawPile: const ['ration', 'flare', 'medkit']),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    final market = state.pendingDecision! as AwaitingEventOption;
    expect(
      market.options,
      contains('market|market-event|1|2|2|ration,flare,medkit|1|buy|0:ration'),
    );
    expect(
      market.options,
      contains('market|market-event|1|2|2|ration,flare,medkit|1|buy|1:flare'),
    );
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(
          market.options.firstWhere((value) => value.endsWith('|buy|0:ration')),
        ),
      ),
      FixedDiceRoller([]),
    ).state;
    final afterBuy = state.pendingDecision! as AwaitingEventOption;
    expect(state.players.single.credits, 4);
    expect(state.players.single.backpack, ['ration']);
    expect(
      afterBuy.options.any((value) => value.endsWith('|sell|ration')),
      isTrue,
    );
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(
          afterBuy.options.firstWhere(
            (value) => value.endsWith('|sell|ration'),
          ),
        ),
      ),
      FixedDiceRoller([]),
    ).state;
    expect(state.players.single.credits, 7);
    expect(state.players.single.backpack, isEmpty);
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(
          (state.pendingDecision! as AwaitingEventOption).options.last,
        ),
      ),
      FixedDiceRoller([]),
    ).state;
    expect(state.pendingDecision, isNull);
    expect(
      state.decks['supplies']!.drawPile,
      containsAll(['flare', 'medkit']),
    );
    expect(state.decks['supplies']!.discardPile, contains('ration'));
  });

  test('event market returns sold cards to their source deck', () {
    final definitions = {
      'supply-helmet': CardDefinition.fromJson({
        'id': 'supply-helmet',
        'category': 'armor',
        'slots': ['armor'],
        'cost': 2,
        'stats': <String, int>{},
        'sourceDeck': 'supplies',
      }),
      'special-armor': CardDefinition.fromJson({
        'id': 'special-armor',
        'category': 'armor',
        'slots': ['armor'],
        'cost': 3,
        'stats': <String, int>{},
        'sourceDeck': 'specialItems',
      }),
    };
    var state = _mvpState(
      eventId: 'source-deck-market',
      playerBackpack: const ['supply-helmet', 'special-armor'],
      cardDefinitions: definitions,
      eventDefinitions: {
        'source-deck-market': {
          'id': 'source-deck-market',
          'options': [
            {
              'skillCheck': null,
              'autoOutcome': 'success',
              'successEffects': [
                {
                  'type': 'market',
                  'offers': 0,
                  'maxPurchases': 0,
                  'discount': 0,
                  'allowSell': true,
                },
              ],
              'failureEffects': [
                {'type': 'no_effect'},
              ],
            },
          ],
        },
      },
      additionalDecks: {
        'items': DeckState(drawPile: const []),
        'supplies': DeckState(drawPile: const []),
        'specialItems': DeckState(drawPile: const []),
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    var market = state.pendingDecision! as AwaitingEventOption;
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(
          market.options.firstWhere(
            (option) => option.endsWith('|sell|supply-helmet'),
          ),
        ),
      ),
      FixedDiceRoller([]),
    ).state;
    market = state.pendingDecision! as AwaitingEventOption;
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(
          market.options.firstWhere(
            (option) => option.endsWith('|sell|special-armor'),
          ),
        ),
      ),
      FixedDiceRoller([]),
    ).state;

    expect(state.decks['supplies']!.discardPile, ['supply-helmet']);
    expect(state.decks['specialItems']!.discardPile, ['special-armor']);
    expect(state.decks['items']!.discardPile, isEmpty);
  });

  test('asteroid event damages and displaces corridor occupants', () {
    var state = _mvpState(
      eventId: 'asteroid-alert',
      playerCoord: const HexCoord(0, 1),
      corridorOpened: true,
      boils: [
        const BoilToken(
          instanceId: 'boil-at-start',
          coord: HexCoord(0, 0),
        ),
      ],
      eventDefinitions: {
        'asteroid-alert': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'asteroid_alert'},
              ],
              'failureEffects': [
                {'type': 'asteroid_alert'},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([1]),
    ).state;

    expect(state.pendingDecision, isA<AwaitingDodge>());
    expect(state.boils, isEmpty);
    state = step(
      state,
      const ResolvePendingDecisionCommand(DodgeChoice()),
      FixedDiceRoller([6]),
    ).state;

    expect(
      state.board
          .singleWhere((tile) => tile.type == HexTileType.corridor)
          .isBlocked,
      isTrue,
    );
    expect(state.players.map((hero) => hero.damage), [1]);
    expect(
      state.players.every((hero) => hero.coord != const HexCoord(0, 1)),
      isTrue,
    );
  });

  test(
    'welded event door blocks monster access but leaves hero passage open',
    () {
      var state = _mvpState(
        eventId: 'door-event',
        eventDefinitions: {
          'door-event': {
            'options': [
              {
                'skillCheck': null,
                'successEffects': [
                  {'type': 'seal_monster_access'},
                ],
                'failureEffects': [
                  {'type': 'seal_monster_access'},
                ],
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      expect(state.board.first.monsterAccessBlocked, isTrue);
      expect(state.board.first.isBlocked, isFalse);
    },
  );

  test('event movement exposes legal neighboring sectors as a decision', () {
    var state = _mvpState(
      eventId: 'movement-event',
      corridorOpened: true,
      eventDefinitions: {
        'movement-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'move_to_neighbor'},
              ],
              'failureEffects': [
                {'type': 'move_to_neighbor'},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.pendingDecision, isA<AwaitingEventOption>());
    expect(
      (state.pendingDecision! as AwaitingEventOption).options,
      contains('move:0:1'),
    );
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('move:0:1')),
      FixedDiceRoller([]),
    ).state;
    expect(state.players.single.coord, const HexCoord(0, 1));
    expect(state.pendingDecision, isNull);
  });

  test('event selection returns unchosen cards to its source deck', () {
    var state = _mvpState(
      eventId: 'selection-event',
      additionalDecks: {
        'items': DeckState(drawPile: const ['item-a', 'item-b', 'item-c']),
      },
      cardDefinitions: {
        for (final id in ['item-a', 'item-b', 'item-c'])
          id: CardDefinition(
            id: id,
            type: ItemType.weapon,
            slots: const [ItemSlot.weapon],
            cost: 1,
            staticEffects: CardStaticEffects(const {}),
          ),
      },
      eventDefinitions: {
        'selection-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'choose_from_top', 'deckId': 'items', 'amount': 3},
              ],
              'failureEffects': [
                {'type': 'choose_from_top', 'deckId': 'items', 'amount': 3},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;
    expect(state.pendingDecision, isA<AwaitingEventOption>());
    state = step(
      state,
      const ResolvePendingDecisionCommand(
        EventOptionChoice('pick:items:item-b'),
      ),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, contains('item-b'));
    expect(state.decks['items']!.drawPile, hasLength(2));
    expect(
      state.decks['items']!.drawPile.toSet(),
      containsAll({'item-a', 'item-c'}),
    );
  });

  test('event draws return overflow at the effective backpack capacity', () {
    var state = _mvpState(
      eventId: 'capacity-event',
      playerBackpack: const ['item-a', 'item-b', 'item-c'],
      additionalDecks: {
        'items': DeckState(drawPile: const ['item-d']),
      },
      eventDefinitions: {
        'capacity-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'draw', 'deckId': 'items', 'amount': 1},
              ],
              'failureEffects': [
                {'type': 'draw', 'deckId': 'items', 'amount': 1},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, ['item-a', 'item-b', 'item-c']);
    expect(state.decks['items']!.drawPile, contains('item-d'));
  });

  test(
    'event reveal opens a selected map fragment without moving the hero',
    () {
      var state = _mvpState(
        eventId: 'reveal-event',
        eventDefinitions: {
          'reveal-event': {
            'options': [
              {
                'skillCheck': null,
                'successEffects': [
                  {'type': 'reveal_fragment', 'scope': 'any'},
                ],
                'failureEffects': [
                  {'type': 'reveal_fragment', 'scope': 'any'},
                ],
              },
            ],
          },
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
        const ResolvePendingDecisionCommand(EventOptionChoice('reveal:0:1')),
        FixedDiceRoller([]),
      ).state;

      expect(state.tileAt(const HexCoord(0, 1))!.opened, isTrue);
      expect(state.players.single.coord, const HexCoord(0, 0));
      expect(state.pendingDecision, isNull);
    },
  );

  test('event next-turn action bonus applies at the next round boundary', () {
    var state = _mvpState(
      eventId: 'action-bonus-event',
      eventDefinitions: {
        'action-bonus-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'next_turn_action_delta', 'delta': 1},
              ],
              'failureEffects': [
                {'type': 'next_turn_action_delta', 'delta': 1},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.round, 2);
    expect(state.players.single.actionPoints, 3);
    expect(state.players.single.nextTurnActionDelta, 0);
  });

  test('filtered implant draws go to carried modifications', () {
    final definition = CardDefinition(
      id: 'implant',
      type: ItemType.modification,
      slots: const [],
      cost: 1,
      staticEffects: CardStaticEffects(const {}),
    );
    var state = _mvpState(
      eventId: 'implant-event',
      playerBackpack: const ['supply-a', 'supply-b', 'supply-c'],
      cardDefinitions: {'implant': definition},
      additionalDecks: {
        'items': DeckState(drawPile: const ['implant']),
      },
      eventDefinitions: {
        'implant-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {
                  'type': 'draw_filtered',
                  'deckId': 'items',
                  'filterType': 'modification',
                },
              ],
              'failureEffects': [
                {
                  'type': 'draw_filtered',
                  'deckId': 'items',
                  'filterType': 'modification',
                },
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;

    expect(state.players.single.backpack, ['supply-a', 'supply-b', 'supply-c']);
    expect(state.players.single.carriedMods, ['implant']);
    state = step(
      state,
      const ImplantModificationCommand('implant'),
      FixedDiceRoller([]),
    ).state;
    expect(state.players.single.implanted, ['implant']);
  });

  test('move and fight event failure spawns a monster in the destination', () {
    var state = _mvpState(
      eventId: 'pack-event',
      corridorOpened: true,
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 2,
          'defense': 0,
          'attack': 1,
          'movement': 0,
          'features': <String>[],
        },
      },
      eventDefinitions: {
        'pack-event': {
          'id': 'pack-event',
          'options': [
            {
              'skillCheck': {'skill': 'endurance', 'difficulty': 1},
              'successEffects': [
                {'type': 'move_to_neighbor'},
              ],
              'failureEffects': [
                {'type': 'move_to_neighbor_and_spawn_monster'},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([1]),
    ).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(KeepRollChoice()),
      FixedDiceRoller([]),
    ).state;
    final options = (state.pendingDecision! as AwaitingEventOption).options;
    expect(options, contains('move_spawn:1:0:1'));
    final moveResult = step(
      state,
      const ResolvePendingDecisionCommand(
        EventOptionChoice('move_spawn:1:0:1'),
      ),
      FixedDiceRoller([]),
    );
    state = moveResult.state;

    expect(state.players.single.coord, const HexCoord(0, 1));
    expect(state.monsters.single.coord, const HexCoord(0, 1));
    expect(state.monsters.single.monsterId, 'ghoul');
    expect(state.pendingDecision, isA<AwaitingDodge>());
  });

  test(
    'move and fight resolves destination hazards before spawning the monster',
    () {
      var state = _mvpState(
        eventId: 'pack-event',
        corridorOpened: true,
        boils: [
          const BoilToken(
            instanceId: 'destination-boil',
            coord: HexCoord(0, 1),
          ),
        ],
        additionalDecks: {
          'monsters': DeckState(drawPile: const ['ghoul']),
        },
        monsterDefinitions: {
          'ghoul': {
            'health': 2,
            'defense': 0,
            'attack': 1,
            'movement': 0,
            'features': <String>[],
          },
        },
        eventDefinitions: {
          'pack-event': {
            'id': 'pack-event',
            'options': [
              {
                'skillCheck': {'skill': 'endurance', 'difficulty': 1},
                'successEffects': [
                  {'type': 'move_to_neighbor'},
                ],
                'failureEffects': [
                  {'type': 'move_to_neighbor_and_spawn_monster'},
                ],
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([1]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(KeepRollChoice()),
        FixedDiceRoller([]),
      ).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(
          EventOptionChoice('move_spawn:1:0:1'),
        ),
        FixedDiceRoller([]),
      ).state;

      expect(state.pendingDecision, isA<AwaitingDodge>());
      expect(state.pendingEventMonsterSpawn, isNotNull);
      expect(state.monsters, isEmpty);
      expect(state.boils, isEmpty);

      state = step(
        state,
        const ResolvePendingDecisionCommand(DodgeChoice()),
        FixedDiceRoller([1]),
      ).state;

      expect(state.players.single.damage, 1);
      expect(state.monsters.single.monsterId, 'ghoul');
      expect(state.pendingDecision, isA<AwaitingDodge>());
      expect(state.pendingEventMonsterSpawn, isNull);
    },
  );

  test(
    'starter gear leaves runtime decks when discarded and cannot be sold',
    () {
      final starterPistol = CardDefinition(
        id: 'pistol',
        type: ItemType.weapon,
        slots: {ItemSlot.weapon},
        cost: 0,
        staticEffects: CardStaticEffects(const {}),
        sourceDeck: 'starterItems',
      );
      var state = _mvpState(
        eventId: 'discard-starter',
        playerEquipment: const EquippedGear(weapon: 'pistol'),
        cardDefinitions: {'pistol': starterPistol},
        additionalDecks: {
          'items': DeckState(drawPile: const ['regular-item']),
        },
        eventDefinitions: {
          'discard-starter': {
            'id': 'discard-starter',
            'options': [
              {
                'skillCheck': null,
                'autoOutcome': 'success',
                'behaviorId': 'event.successFailure',
                'successEffects': [
                  {'type': 'discard_equipped', 'slot': 'weapon'},
                ],
                'failureEffects': [
                  {'type': 'discard_equipped', 'slot': 'weapon'},
                ],
              },
            ],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      expect(state.players.single.equipped.weapon, isNull);
      expect(state.decks['items']!.drawPile, ['regular-item']);
      expect(state.decks['items']!.discardPile, isEmpty);

      state = _mvpState(
        eventId: 'starter-market',
        playerEquipment: const EquippedGear(weapon: 'pistol'),
        cardDefinitions: {'pistol': starterPistol},
        eventDefinitions: {
          'starter-market': {
            'id': 'starter-market',
            'options': [
              {
                'skillCheck': null,
                'autoOutcome': 'success',
                'behaviorId': 'event.successFailure',
                'successEffects': [
                  {
                    'type': 'market',
                    'offers': 0,
                    'maxPurchases': 0,
                    'allowSell': true,
                  },
                ],
                'failureEffects': [
                  {
                    'type': 'market',
                    'offers': 0,
                    'maxPurchases': 0,
                    'allowSell': true,
                  },
                ],
              },
            ],
          },
        },
        additionalDecks: {
          'supplies': DeckState(drawPile: const ['supply']),
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      final options = (state.pendingDecision! as AwaitingEventOption).options;
      expect(options.any((option) => option.contains('|sell|pistol')), isFalse);
    },
  );

  test(
    'next round defense bonus is scheduled and applied to monster damage',
    () {
      final armor = CardDefinition(
        id: 'armor',
        type: ItemType.armor,
        slots: const [],
        cost: 1,
        staticEffects: CardStaticEffects(const {CardStat.defense: 1}),
      );
      var state = _mvpState(
        eventId: 'defense-event',
        cardDefinitions: {'armor': armor},
        playerEquipment: const EquippedGear(armor: 'armor'),
        additionalDecks: {
          'monsters': DeckState(drawPile: const ['ghoul']),
        },
        eventDefinitions: {
          'defense-event': {
            'id': 'defense-event',
            'options': [
              {
                'skillCheck': null,
                'autoOutcome': 'success',
                'successEffects': [
                  {'type': 'heal', 'amount': 3},
                  {'type': 'monster_defense_bonus_next_round'},
                ],
                'failureEffects': [
                  {'type': 'monster_defense_bonus_next_round'},
                ],
              },
            ],
          },
        },
        monsterDefinitions: {
          'ghoul': {
            'health': 2,
            'defense': 0,
            'attack': 2,
            'movement': 0,
            'features': <String>[],
          },
        },
      );
      state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
      state = step(
        state,
        const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
        FixedDiceRoller([]),
      ).state;
      expect(state.players.single.monsterDefenseBonusRound, state.round);
    },
  );

  test('event monster placement resolves after choosing a neighbor sector', () {
    var state = _mvpState(
      eventId: 'placement-event',
      corridorOpened: true,
      additionalDecks: {
        'monsters': DeckState(drawPile: const ['ghoul']),
      },
      monsterDefinitions: {
        'ghoul': {
          'health': 2,
          'defense': 0,
          'attack': 0,
          'movement': 0,
        },
      },
      eventDefinitions: {
        'placement-event': {
          'options': [
            {
              'skillCheck': null,
              'successEffects': [
                {'type': 'spawn_monster_adjacent'},
              ],
              'failureEffects': [
                {'type': 'spawn_monster_adjacent'},
              ],
            },
          ],
        },
      },
    );
    state = step(state, const EndTurnCommand(), FixedDiceRoller([])).state;
    state = step(
      state,
      const ResolvePendingDecisionCommand(EventOptionChoice('option-1')),
      FixedDiceRoller([]),
    ).state;
    final placement = state.pendingDecision! as AwaitingEventOption;
    state = step(
      state,
      ResolvePendingDecisionCommand(
        EventOptionChoice(placement.options.single),
      ),
      FixedDiceRoller([]),
    ).state;

    expect(state.monsters.single.coord, const HexCoord(0, 1));
    expect(state.players.single.coord, const HexCoord(0, 0));
    expect(state.pendingDecision, isNull);
  });

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

  test('quest supply rewards are drawn for every living hero', () {
    final supplies = {
      for (final id in ['ration-a', 'ration-b'])
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
      storyQuestIds: const ['supply-quest'],
      heroCount: 2,
      questDefinitions: {
        'supply-quest': {
          'id': 'supply-quest',
          'number': 1,
          'chapter': 1,
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
            'drawSuppliesPerPlayer': 1,
          },
          'nextQuestIds': <Object?>[],
          'nameKey': 'supply-quest.name',
          'descKey': 'supply-quest.description',
        },
      },
      cardDefinitions: supplies,
      additionalDecks: {
        'supplies': DeckState(drawPile: const ['ration-a', 'ration-b']),
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

    expect(state.players.map((player) => player.backpack.length), [1, 1]);
    expect(state.decks['supplies']!.drawPile, isEmpty);
  });

  test('quest 6 damages every hero only while quest 5 remains active', () {
    final sharedQuests = <String, Map<String, Object?>>{
      'quest-05': {
        'id': 'quest-05',
        'number': 5,
        'chapter': 4,
        'conditions': [
          {
            'id': 'medicine',
            'type': 'collect_item',
            'itemId': 'medicine',
          },
        ],
        'reward': {'credits': 0, 'items': <Object?>[]},
        'nextQuestIds': <Object?>[],
        'nameKey': 'quest-05.name',
        'descKey': 'quest-05.description',
      },
      'quest-06': {
        'id': 'quest-06',
        'number': 6,
        'chapter': 5,
        'conditions': [
          {
            'id': 'engine-check',
            'type': 'skill_check',
            'skill': 'science',
            'locationId': 'crew-mess',
          },
        ],
        'completionEffects': [
          {
            'type': 'damage_all_players_if_quest_active',
            'questId': 'quest-05',
            'amount': 2,
          },
        ],
        'reward': {'credits': 0, 'items': <Object?>[]},
        'nextQuestIds': <Object?>[],
        'nameKey': 'quest-06.name',
        'descKey': 'quest-06.description',
      },
    };
    var state = _mvpState(
      playerCoord: const HexCoord(0, 2),
      storyQuestIds: const ['quest-05', 'quest-06'],
      heroCount: 2,
      questDefinitions: sharedQuests,
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

    expect(state.quests.statusOf('quest-05'), QuestStatus.active);
    expect(state.quests.statusOf('quest-06'), QuestStatus.completed);
    expect(state.players.map((player) => player.damage), [2, 2]);
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
      additionalDecks: {
        'supplies': DeckState(drawPile: const ['ration']),
      },
      cardDefinitions: {
        'ration': CardDefinition(
          id: 'ration',
          type: ItemType.supply,
          slots: const [],
          cost: 0,
          staticEffects: CardStaticEffects(const {}),
        ),
      },
      eventDefinitions: {
        'cabin-noise': {
          'options': [
            {
              'skillCheck': {'skill': 'agility', 'difficulty': 1},
              'behaviorId': 'event_cabin_noise',
              'successEffects': [
                {'type': 'draw', 'deckId': 'supplies', 'amount': 1},
              ],
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
    expect(state.players.single.backpack, contains('ration'));

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
  Iterable<CardId> playerBackpack = const [],
  EquippedGear playerEquipment = const EquippedGear(),
  List<String> storyQuestIds = const ['chapter-1-awakening'],
  Map<PlayerId, Iterable<String>> personalTasksByPlayer = const {},
  Map<String, Map<String, int>> conditionProgress = const {},
  Map<String, Map<String, Object?>> questDefinitions = const {},
  Map<String, Map<String, Object?>> taskDefinitions = const {},
  Map<CardId, CardDefinition> cardDefinitions = const {},
  Map<DeckId, DeckState> additionalDecks = const {},
  Iterable<MonsterInstance> monsters = const [],
  Iterable<BoilToken> boils = const [],
  Map<String, Map<String, Object?>> monsterDefinitions = const {},
  int heroCount = 1,
  int secondHeroDamage = 0,
  Iterable<ReserveHero> reserveHeroes = const [],
  int initialCredits = 0,
  int playerHealth = 3,
  PlayerStats playerStats = const PlayerStats(science: 1, agility: 1),
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
        health: playerHealth,
        backpack: playerBackpack,
        equipped: playerEquipment,
        carriedMods: const [],
        implanted: const [],
        conditions: const [],
        alive: true,
        stats: playerStats,
      ),
  ],
  monsters: monsters,
  boils: boils,
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
