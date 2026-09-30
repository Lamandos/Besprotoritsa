import 'dart:convert';
import 'dart:io';

import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:besprotoritsa_app/src/game/full_game_state.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the shipped quest graph reaches its terminal transition', () async {
    final questDocument =
        jsonDecode(
              await File('../../content/quests.json').readAsString(),
            )
            as Map<String, dynamic>;
    final graph = QuestGraph.fromJson(Map<String, Object?>.from(questDocument));
    final engine = QuestEngine(graph);
    var progress = engine.initialProgress();
    QuestTransition? terminalTransition;

    for (final event in _victoryRoute) {
      final transition = engine.apply(progress, event);
      progress = transition.progress;
      terminalTransition = transition;
    }

    expect(terminalTransition, isNotNull);
    final victoryTransition = terminalTransition!;
    expect(victoryTransition.gameWon, isTrue);
    expect(
      progress.completedQuestIds,
      containsAll(<String>[
        for (var number = 1; number <= 12; number++)
          'quest-${number.toString().padLeft(2, '0')}',
      ]),
    );
  });

  test(
    'a fixed-seed full setup reaches the long campaign ending at Quest 29',
    () {
      final setup = createFullGameState(
        characterIds: const ['scientist', 'engineer'],
        seed: 29129,
      );
      final graph = QuestGraph(
        quests: setup.questDefinitions.values.map(QuestDefinition.fromJson),
        initialQuestIds: setup.quests.storyQuestIds,
      );
      final engine = QuestEngine(graph);
      var progress = engine.initialProgress();
      var won = false;
      for (final event in _alternateVictoryRoute) {
        final transition = engine.apply(progress, event);
        progress = transition.progress;
        won = won || transition.gameWon;
      }

      expect(setup.seed, 29129);
      expect(graph.quests, hasLength(29));
      expect(won, isTrue);
      expect(progress.isCompleted('quest-28'), isTrue);
      expect(progress.isCompleted('quest-29'), isTrue);
      expect(progress.isCompleted('quest-12'), isFalse);
    },
  );

  test('fixed-seed campaign reaches Quest 29 through gameplay commands', () {
    var state = createFullGameState(
      characterIds: const ['guard', 'astronaut'],
      seed: 226,
    );
    final dice = FixedDiceRoller(List<int>.filled(100000, 6));
    var commands = 0;
    String? combatTargetInstanceId;

    void resolvePending() {
      while (state.pendingDecision != null && !state.isComplete) {
        if (++commands > 12000) throw StateError('Campaign command limit.');
        final pending = state.pendingDecision!;
        final choice = switch (pending) {
          AwaitingRerollChoice() => const KeepRollChoice(),
          AwaitingDodge() => const DodgeChoice(),
          AwaitingEventOption() => EventOptionChoice(
            _chooseCampaignEventOption(state, pending),
          ),
          AwaitingTerminalPick() => const DeclineTerminalPickChoice(),
          AwaitingHeroReplacement(:final characterIds) =>
            SelectReplacementHeroChoice(
              characterIds.reduce(
                (left, right) =>
                    _replacementPriority(left) <= _replacementPriority(right)
                    ? left
                    : right,
              ),
            ),
          AwaitingOtherPlayerDecision() => throw StateError(
            'Unexpected projected multiplayer decision.',
          ),
        };
        final result = step(
          state,
          ResolvePendingDecisionCommand(choice),
          dice,
        );
        if (result.rejection != null) {
          throw StateError(
            'Decision rejected: ${result.rejection}; pending=$pending; '
            'choice=${choice is EventOptionChoice ? choice.option : choice}; '
            'round=${state.round}; recent=${state.log.reversed.take(8)}',
          );
        }
        state = result.state;
      }
    }

    void command(GameCommand value) {
      if (++commands > 12000) throw StateError('Campaign command limit.');
      if (state.isComplete) {
        throw StateError(
          'Campaign ended before $value in round ${state.round}; '
          'statuses=${state.quests.statuses}; '
          'living=${state.players.where((hero) => hero.alive).map((hero) => hero.id)}; '
          'recent=${state.log.reversed.take(20)}',
        );
      }
      final result = step(state, value, dice);
      if (result.rejection != null) {
        throw StateError('$value rejected: ${result.rejection}');
      }
      state = result.state;
      resolvePending();
    }

    void takeHeroTurn() {
      var safety = 0;
      while (state.activePlayerId != 'hero-1' && !state.isComplete) {
        if (++safety > 12 || state.phase != GamePhase.playersTurn) {
          throw StateError('Could not reach hero-1 turn.');
        }
        final active = state.players
            .where((hero) => hero.id == state.activePlayerId)
            .firstOrNull;
        final gearToEquip = active == null
            ? null
            : _campaignGearToEquip(state, active);
        if (gearToEquip != null) {
          command(EquipCommand(gearToEquip));
          continue;
        }
        if (active?.id == 'hero-2' && state.actionsLeft > 0) {
          if (active!.damage >= 3) {
            command(HealCommand(4));
            continue;
          }
          final nearbyMonster =
              state.monsters
                  .where(
                    (monster) =>
                        monster.instanceId == combatTargetInstanceId &&
                        monster.coord == active.coord,
                  )
                  .firstOrNull ??
              state.monsters
                  .where((monster) => monster.coord == active.coord)
                  .firstOrNull;
          if (nearbyMonster != null &&
              (active.equipped.weapons.isNotEmpty ||
                  active.weaponModifier > 0)) {
            command(AttackCommand(nearbyMonster.instanceId));
            continue;
          }
          final lead = state.players.singleWhere(
            (hero) => hero.id == 'hero-1',
          );
          final combatTarget = combatTargetInstanceId == null
              ? null
              : state.monsters
                    .where(
                      (monster) => monster.instanceId == combatTargetInstanceId,
                    )
                    .firstOrNull;
          final followerGoal = combatTarget?.coord ?? lead.coord;
          if (active.coord != followerGoal) {
            final path = _campaignPath(
              state,
              active.coord,
              followerGoal,
              allowAirlocks: _hasSpaceSuit(active),
            );
            if (path.length > 1) {
              final next = state.tileAt(path[1])!;
              final cost = active.coord.edgeTowardOrNull(next.coord) == null
                  ? 1
                  : next.isBlocked
                  ? 1
                  : next.opened
                  ? 1
                  : 2;
              if (state.actionsLeft >= cost) {
                if (next.isBlocked) {
                  command(OpenCorridorCommand(next.coord));
                } else if (active.coord.edgeTowardOrNull(next.coord) == null) {
                  command(
                    AirlockMoveCommand(
                      next.coord,
                      const AirlockEquipment(hasSpaceSuit: true),
                    ),
                  );
                } else {
                  command(MoveCommand(next.coord));
                }
                continue;
              }
            }
          }
        }
        command(const EndTurnCommand());
      }
      final active = state.players
          .where((hero) => hero.id == state.activePlayerId)
          .firstOrNull;
      final gearToEquip = active == null
          ? null
          : _campaignGearToEquip(state, active);
      if (gearToEquip != null) command(EquipCommand(gearToEquip));
    }

    void travelTo(String locationId) {
      var safety = 0;
      while (!state.isComplete) {
        final hero = state.players.singleWhere((entry) => entry.id == 'hero-1');
        final target = state.board
            .where((tile) => tile.locationId == locationId)
            .firstOrNull;
        if (target == null) throw StateError('Missing location $locationId.');
        if (hero.coord == target.coord) return;
        if (++safety > 300) throw StateError('Could not reach $locationId.');
        final path = _campaignPath(
          state,
          hero.coord,
          target.coord,
          allowAirlocks: _hasSpaceSuit(hero),
        );
        if (path.length < 2) {
          final blocked = state.board
              .where(
                (tile) => tile.type == HexTileType.corridor && tile.isBlocked,
              )
              .length;
          throw StateError(
            'No route to $locationId at round ${state.round} from ${hero.coord}; '
            '$blocked corridors blocked. Current tile: ${state.tileAt(hero.coord)}. '
            'Recent log: ${state.log.reversed.take(16)}',
          );
        }
        takeHeroTurn();
        final currentHero = state.players.singleWhere(
          (entry) => entry.id == 'hero-1',
        );
        if (currentHero.damage >= 3 && state.actionsLeft > 0) {
          command(HealCommand(4));
          continue;
        }
        final refreshedPath = _campaignPath(
          state,
          currentHero.coord,
          target.coord,
          allowAirlocks: _hasSpaceSuit(currentHero),
        );
        if (refreshedPath.length < 2) continue;
        final next = state.tileAt(refreshedPath[1])!;
        final cost = currentHero.coord.edgeTowardOrNull(next.coord) == null
            ? 1
            : next.isBlocked
            ? 1
            : next.opened
            ? 1
            : 2;
        if (state.actionsLeft < cost) {
          command(const EndTurnCommand());
          continue;
        }
        if (next.isBlocked) {
          command(OpenCorridorCommand(next.coord));
          continue;
        }
        if (currentHero.coord.edgeTowardOrNull(next.coord) == null) {
          command(
            AirlockMoveCommand(
              next.coord,
              const AirlockEquipment(hasSpaceSuit: true),
            ),
          );
          continue;
        }
        command(MoveCommand(next.coord));
      }
    }

    void defeatMonster(MonsterInstance target) {
      combatTargetInstanceId = target.instanceId;
      var safety = 0;
      while (!state.isComplete) {
        final monster = state.monsters
            .where((entry) => entry.instanceId == target.instanceId)
            .firstOrNull;
        if (monster == null) {
          combatTargetInstanceId = null;
          return;
        }
        if (++safety > 40)
          throw StateError(
            'Could not defeat ${monster.monsterId}; round=${state.round}, '
            'hero=${state.players.singleWhere((entry) => entry.id == 'hero-1')}, '
            'monster=$monster, recent=${state.log.reversed.take(12)}',
          );
        final hero = state.players.singleWhere((entry) => entry.id == 'hero-1');
        if (hero.coord != monster.coord) {
          final path = _campaignPath(
            state,
            hero.coord,
            monster.coord,
            allowAirlocks: _hasSpaceSuit(hero),
          );
          if (path.length < 2) throw StateError('No route to monster.');
          takeHeroTurn();
          final currentHero = state.players.singleWhere(
            (entry) => entry.id == 'hero-1',
          );
          final currentMonster = state.monsters
              .where((entry) => entry.instanceId == target.instanceId)
              .firstOrNull;
          if (currentMonster == null) return;
          final refreshedPath = _campaignPath(
            state,
            currentHero.coord,
            currentMonster.coord,
            allowAirlocks: _hasSpaceSuit(currentHero),
          );
          if (refreshedPath.length < 2) continue;
          final next = state.tileAt(refreshedPath[1])!;
          final cost = currentHero.coord.edgeTowardOrNull(next.coord) == null
              ? 1
              : next.isBlocked
              ? 1
              : next.opened
              ? 1
              : 2;
          if (state.actionsLeft < cost) {
            command(const EndTurnCommand());
          } else if (next.isBlocked) {
            command(OpenCorridorCommand(next.coord));
          } else if (currentHero.coord.edgeTowardOrNull(next.coord) == null) {
            command(
              AirlockMoveCommand(
                next.coord,
                const AirlockEquipment(hasSpaceSuit: true),
              ),
            );
          } else {
            command(MoveCommand(next.coord));
          }
          continue;
        }
        takeHeroTurn();
        if (state.actionsLeft == 0) {
          command(const EndTurnCommand());
          continue;
        }
        final currentMonster = state.monsters
            .where((entry) => entry.instanceId == monster.instanceId)
            .firstOrNull;
        final currentHero = state.players.singleWhere(
          (entry) => entry.id == 'hero-1',
        );
        if (currentMonster == null) {
          combatTargetInstanceId = null;
          return;
        }
        if (currentHero.coord != currentMonster.coord) continue;
        command(AttackCommand(currentMonster.instanceId));
      }
      combatTargetInstanceId = null;
    }

    if (state.players
        .singleWhere((hero) => hero.id == 'hero-1')
        .backpack
        .contains('pistol')) {
      command(const EquipCommand('pistol'));
    }

    final maxTurns = 600;
    while (!state.isComplete && state.round < maxTurns) {
      final activeQuests =
          state.quests.storyQuestIds.where((id) {
            if (state.quests.statusOf(id) != QuestStatus.active) return false;
            final number = int.parse(id.substring('quest-'.length));
            return !(number >= 13 && number <= 23);
          }).toList()..sort((left, right) {
            if (left == 'quest-24') return -1;
            if (right == 'quest-24') return 1;
            if (left == 'quest-27') return -1;
            if (right == 'quest-27') return 1;
            if (left == 'quest-08') return 1;
            if (right == 'quest-08') return -1;
            final leftNumber = int.parse(left.substring('quest-'.length));
            final rightNumber = int.parse(right.substring('quest-'.length));
            return leftNumber.compareTo(rightNumber);
          });
      Map<String, Object?>? selectedQuest;
      Map<String, Object?>? selectedCondition;
      for (final questId in activeQuests) {
        final rawQuest = state.questDefinitions[questId];
        final rawConditions = rawQuest?['conditions'];
        if (rawQuest == null || rawConditions is! List<Object?>) continue;
        for (final rawCondition in rawConditions) {
          if (rawCondition is! Map<String, Object?>) continue;
          final conditionId = rawCondition['id'];
          var progress = 0;
          if (conditionId is String) {
            progress =
                state.quests.conditionProgress[questId]?[conditionId] ?? 0;
          }
          final target = rawCondition['targetValue'] as int? ?? 1;
          if (progress < target) {
            selectedQuest = rawQuest;
            selectedCondition = rawCondition;
            break;
          }
        }
        if (selectedCondition != null) break;
      }

      if (selectedCondition == null) {
        takeHeroTurn();
        command(const EndTurnCommand());
        continue;
      }
      final condition = selectedCondition;
      final quest = selectedQuest!;
      final conditionId = condition['id']! as String;
      final previousProgress =
          state.quests.conditionProgress[quest['id']]?[conditionId] ?? 0;
      switch (condition['type']) {
        case 'arrive':
          final locationId = condition['locationId']! as String;
          travelTo(locationId);
          final arrivalProgress =
              state.quests.conditionProgress[quest['id']]?[conditionId] ?? 0;
          if (arrivalProgress == previousProgress) {
            final hero = state.players.singleWhere(
              (entry) => entry.id == 'hero-1',
            );
            final room = state.tileAt(hero.coord)!;
            final exit = room.exits
                .map((edge) => hero.coord.neighbor(edge))
                .map(state.tileAt)
                .whereType<HexTile>()
                .where((tile) => !tile.isBlocked)
                .firstOrNull;
            if (exit == null) {
              throw StateError('Cannot leave $locationId to register arrival.');
            }
            takeHeroTurn();
            final exitCost = exit.opened ? 1 : 2;
            if (state.actionsLeft < exitCost) {
              command(const EndTurnCommand());
              takeHeroTurn();
            }
            command(MoveCommand(exit.coord));
            travelTo(locationId);
          }
        case 'skill_check':
          final location = condition['locationId']! as String;
          travelTo(location);
          takeHeroTurn();
          if (state.actionsLeft < 1) {
            command(const EndTurnCommand());
            takeHeroTurn();
          }
          command(
            SkillCheckCommand(
              StatType.values.byName(condition['skill']! as String),
            ),
          );
        case 'kill_monster':
          final monsterId = condition['monsterId']! as String;
          var monster = state.monsters
              .where((entry) => entry.monsterId == monsterId)
              .firstOrNull;
          if (monster == null) {
            final location =
                quest['spawnLocationId'] ?? quest['targetLocation'];
            if (location is! String) {
              throw StateError('No spawn location for $monsterId.');
            }
            travelTo(location);
            monster = state.monsters
                .where((entry) => entry.monsterId == monsterId)
                .firstOrNull;
            if (monster == null) {
              takeHeroTurn();
              command(const EndTurnCommand());
            } else {
              defeatMonster(monster);
            }
          } else {
            defeatMonster(monster);
          }
        default:
          throw StateError(
            'Unexpected route requirement ${condition['type']} '
            'in ${quest['id']}.',
          );
      }
    }

    if (!state.isComplete) {
      final hero = state.players.singleWhere((entry) => entry.id == 'hero-1');
      throw StateError(
        'Campaign stalled at round ${state.round}: '
        'statuses=${state.quests.statuses}, '
        'quest27=${state.quests.conditionProgress['quest-27']}, '
        'hero=$hero, tile=${state.tileAt(hero.coord)}, '
        'anabiosis=${state.board.where((tile) => tile.locationId == 'anabiosis')}, '
        'monsters=${state.monsters.where((monster) => monster.monsterId == 'mother')}',
      );
    }
    expect(
      state.quests.statusOf('quest-29'),
      QuestStatus.completed,
      reason:
          'Premature terminal at round ${state.round}: '
          'statuses=${state.quests.statuses}; '
          'living=${state.players.where((hero) => hero.alive).map((hero) => '${hero.id}:${hero.damage}/${hero.health}')}',
    );
    expect(state.round, lessThan(maxTurns));
    expect(state.isComplete, isTrue);
    expect(state.quests.statusOf('quest-29'), QuestStatus.completed);
    expect(
      state.log.any(
        (entry) => entry.split(',').contains('quest-completed:quest-29'),
      ),
      isTrue,
    );
    expect(state.quests.statusOf('quest-12'), isNot(QuestStatus.completed));
    expect(state.players.any((hero) => hero.alive), isTrue);
  });

  testWidgets('the production game command opens the victory screen', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        gameControllerProvider.overrideWith(
          () => GameController(
            initialState: _victoryReadyState(),
            dice: FixedDiceRoller([6, 1]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(gameControllerProvider.notifier);
    expect(
      controller.dispatch(const SkillCheckCommand(StatType.science)),
      isTrue,
    );
    expect(
      container.read(gameControllerProvider).pendingDecision,
      isA<AwaitingRerollChoice>(),
    );
    expect(
      controller.dispatch(
        const ResolvePendingDecisionCommand(KeepRollChoice()),
      ),
      isTrue,
    );
    final completed = container.read(gameControllerProvider);
    expect(
      completed.quests.statusOf('chapter-1-awakening'),
      QuestStatus.completed,
    );
    expect(completed.isComplete, isTrue);
    expect(completed.gameEvents.single, isA<MvpDemonstrationCompleted>());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MvpGameScreen()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('victory-screen')),
      findsOneWidget,
    );
    expect(find.text('Победа выживших'), findsOneWidget);
  });
}

GameState _victoryReadyState() {
  final source = createMvpGameState();
  final crewMess = source.board.singleWhere(
    (tile) => tile.locationId == 'crew-mess',
  );
  return GameState(
    seed: source.seed,
    difficulty: source.difficulty,
    round: source.round,
    phase: source.phase,
    activePlayerId: source.activePlayerId,
    actionsLeft: source.actionsLeft,
    board: [
      for (final tile in source.board)
        if (tile.id == crewMess.id)
          HexTile(
            id: tile.id,
            coord: tile.coord,
            type: tile.type,
            opened: true,
            exits: tile.exits,
            locationId: tile.locationId,
            hasTerminal: tile.hasTerminal,
            ventColor: tile.ventColor,
          )
        else
          tile,
    ],
    players: [
      for (var index = 0; index < source.players.length; index++)
        _copyPlayer(
          source.players[index],
          coord: index == 0 ? crewMess.coord : source.players[index].coord,
        ),
    ],
    monsters: const [],
    decks: source.decks,
    conditionCards: source.conditionCards,
    cardDefinitions: source.cardDefinitions,
    quests: source.quests,
  );
}

PlayerState _copyPlayer(PlayerState player, {required HexCoord coord}) =>
    PlayerState(
      id: player.id,
      characterId: player.characterId,
      coord: coord,
      damage: player.damage,
      health: player.health,
      credits: player.credits,
      backpack: player.backpack,
      equipped: player.equipped,
      carriedMods: player.carriedMods,
      implanted: player.implanted,
      conditions: player.conditions,
      alive: player.alive,
      stats: player.stats,
      actionPoints: player.actionPoints,
      weaponModifier: player.weaponModifier,
    );

const _victoryRoute = <QuestEvent>[
  QuestArrived('crew-quarters'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'crew-quarters',
    success: true,
  ),
  QuestArrived('engineering-control-post'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'engineering-control-post',
    success: true,
  ),
  QuestArrived('reactor'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'reactor',
    success: true,
  ),
  QuestArrived('medical-bay'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'medical-bay',
    success: true,
  ),
  QuestArrived('laboratory'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'laboratory',
    success: true,
  ),
  QuestArrived('main-computer'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'main-computer',
    success: true,
  ),
  QuestArrived('escape-pods'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'escape-pods',
    success: true,
  ),
  QuestArrived('storage'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'storage',
    success: true,
  ),
  QuestArrived('flight-control'),
  QuestMonsterKilled(monsterId: 'viy'),
  QuestArrived('escape-pods'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'escape-pods',
    success: true,
  ),
  QuestArrived('escape-pods'),
  QuestMonsterKilled(monsterId: 'mother'),
];

const _alternateVictoryRoute = <QuestEvent>[
  QuestArrived('crew-quarters'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'crew-quarters',
    success: true,
  ),
  QuestArrived('engineering-control-post'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'engineering-control-post',
    success: true,
  ),
  QuestArrived('reactor'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'reactor',
    success: true,
  ),
  QuestArrived('medical-bay'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'medical-bay',
    success: true,
  ),
  QuestArrived('laboratory'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'laboratory',
    success: true,
  ),
  QuestArrived('main-computer'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'main-computer',
    success: true,
  ),
  QuestArrived('escape-pods'),
  QuestSkillChecked(
    skill: StatType.science,
    locationId: 'escape-pods',
    success: true,
  ),
  QuestArrived('flight-control'),
  QuestSkillChecked(
    skill: StatType.agility,
    locationId: 'flight-control',
    success: true,
  ),
  QuestArrived('armory'),
  QuestMonsterKilled(monsterId: 'viy'),
  QuestArrived('main-computer'),
  QuestSkillChecked(
    skill: StatType.repair,
    locationId: 'main-computer',
    success: true,
  ),
  QuestArrived('anabiosis'),
  QuestMonsterKilled(monsterId: 'mother'),
  QuestArrived('anabiosis'),
];

int _replacementPriority(String characterId) => switch (characterId) {
  'guard' => 0,
  'worker' => 1,
  'engineer' => 2,
  'mechanic' => 3,
  'astronaut' => 4,
  'hauler' => 5,
  'healer' => 6,
  'scientist' => 7,
  _ => 8,
};

String? _campaignGearToEquip(GameState state, PlayerState player) {
  for (final cardId in player.backpack) {
    final item = state.cardDefinitions[cardId];
    if (item == null) continue;
    if (item.slots.contains(ItemSlot.weapon) &&
        player.equipped.weapons.isEmpty) {
      return cardId;
    }
    if (item.slots.contains(ItemSlot.armor) && player.equipped.armor == null) {
      return cardId;
    }
    if (item.slots.contains(ItemSlot.robot) && player.equipped.robot == null) {
      return cardId;
    }
  }
  return null;
}

String _chooseCampaignEventOption(
  GameState state,
  AwaitingEventOption pending,
) {
  final marketDone = pending.options.where(
    (option) =>
        option.startsWith('market|') &&
        option.split('|').elementAtOrNull(7) == 'done',
  );
  if (marketDone.isNotEmpty) return marketDone.first;
  final definition = state.eventDefinitions[pending.eventId];
  final rawOptions = definition?['options'];
  final player = pending.playerId == null
      ? null
      : state.players.where((hero) => hero.id == pending.playerId).firstOrNull;
  if (rawOptions is! List<Object?> || player == null) {
    return pending.options.first;
  }
  final candidates = <({String option, int score})>[];
  for (final optionId in pending.options) {
    if (!optionId.startsWith('option-')) continue;
    final index = int.tryParse(optionId.substring('option-'.length));
    if (index == null || index < 1 || index > rawOptions.length) continue;
    final option = rawOptions[index - 1];
    if (option is! Map<String, Object?>) continue;
    final successValue = _campaignEffectValue(option['successEffects']);
    final failureValue = _campaignEffectValue(option['failureEffects']);
    final check = option['skillCheck'];
    var score = successValue;
    if (check is Map<String, Object?> && check['skill'] is String) {
      final skill = StatType.values.byName(check['skill']! as String);
      final difficulty = check['difficulty'] as int? ?? 1;
      score += player.stats.valueFor(skill) * 2 - difficulty;
      score -= (failureValue < 0 ? -failureValue : 0) * 3;
    } else if (option['autoOutcome'] == 'success') {
      score += 4;
    } else if (!_sameCampaignEffectPlans(
      option['successEffects'],
      option['failureEffects'],
    )) {
      // An unscored no-skill branch has no automatic effect in the digital
      // adaptation, so it is safer than triggering an unearned failure.
      score = 0;
    }
    candidates.add((option: optionId, score: score));
  }
  if (candidates.isEmpty) return pending.options.first;
  candidates.sort((left, right) => right.score.compareTo(left.score));
  return candidates.first.option;
}

int _campaignEffectValue(Object? rawEffects) {
  if (rawEffects is! List<Object?>) return 0;
  var score = 0;
  for (final rawEffect in rawEffects) {
    if (rawEffect is! Map<String, Object?>) continue;
    final amount = rawEffect['amount'] as int? ?? 1;
    score += switch (rawEffect['type']) {
      'spawn_monster' => -100,
      'damage' => -30 * amount,
      'damage_roll_die' => -30,
      'damage_each_player_roll_die' => -60,
      'damage_all_players' => -40 * amount,
      'discard_card_id' || 'discard_equipped' => -15,
      'next_turn_action_delta' => -20,
      'heal' => 12 * amount,
      'draw' || 'draw_filtered' || 'draw_supplies_all_players' => 5 * amount,
      'credits' => amount,
      'seal_monster_access' || 'destroy_nest' => 8,
      'open_door' || 'no_effect' => 0,
      _ => 0,
    };
  }
  return score;
}

bool _sameCampaignEffectPlans(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);

bool _hasSpaceSuit(PlayerState player) =>
    player.characterId == 'astronaut' ||
    player.equipped.armor == 'spacesuit-mk2' ||
    player.backpack.contains('spacesuit-mk2');

List<HexCoord> _campaignPath(
  GameState state,
  HexCoord start,
  HexCoord goal, {
  bool allowAirlocks = false,
}) {
  if (start == goal) return [start];
  final distance = <HexCoord, int>{start: 0};
  final previous = <HexCoord, HexCoord>{};
  final pending = <HexCoord>{start};
  while (pending.isNotEmpty) {
    final current = pending.reduce(
      (left, right) => distance[left]! <= distance[right]! ? left : right,
    );
    pending.remove(current);
    if (current == goal) break;
    final tile = state.tileAt(current);
    if (tile == null || tile.isBlocked && tile.type != HexTileType.corridor) {
      continue;
    }
    for (final edge in tile.exits) {
      final nextCoord = current.neighbor(edge);
      final next = state.tileAt(nextCoord);
      if (next == null ||
          next.isBlocked && next.type != HexTileType.corridor ||
          !next.hasExit(edge.opposite)) {
        continue;
      }
      final nextDistance =
          distance[current]! + (next.opened ? 1 : 2) + (next.isBlocked ? 1 : 0);
      if (nextDistance >= (distance[nextCoord] ?? 1 << 30)) continue;
      distance[nextCoord] = nextDistance;
      previous[nextCoord] = current;
      pending.add(nextCoord);
    }
    if (allowAirlocks && tile.type == HexTileType.airlock) {
      for (final next in state.board.where(
        (candidate) =>
            candidate.type == HexTileType.airlock &&
            candidate.opened &&
            !candidate.isBlocked,
      )) {
        final nextCoord = next.coord;
        final nextDistance = distance[current]! + 1;
        if (nextCoord == current ||
            nextDistance >= (distance[nextCoord] ?? 1 << 30)) {
          continue;
        }
        distance[nextCoord] = nextDistance;
        previous[nextCoord] = current;
        pending.add(nextCoord);
      }
    }
  }
  if (!distance.containsKey(goal)) return const [];
  final path = <HexCoord>[goal];
  var current = goal;
  while (current != start) {
    final parent = previous[current];
    if (parent == null) return const [];
    path.add(parent);
    current = parent;
  }
  return path.reversed.toList();
}
