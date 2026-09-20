// Nested conversion helpers are documented by the codec that owns them.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// JSON primitives for the nested rule models used in a save document.
abstract final class SaveJsonModels {
  static GamePhase gamePhaseFromJson(String value) =>
      _enum(GamePhase.values, value, 'phase');
  static Map<String, Object?> tileToJson(HexTile tile) => {
    'id': tile.id,
    'coord': _coordToJson(tile.coord),
    'type': tile.type.name,
    'opened': tile.opened,
    'exits': tile.exits.map((edge) => edge.index).toList(),
    'location_id': tile.locationId,
    'has_terminal': tile.hasTerminal,
    'vent_color': tile.ventColor.name,
    'is_blocked': tile.isBlocked,
  };
  static HexTile tileFromJson(Map<String, Object?> json) => HexTile(
    id: _string(json, 'id'),
    coord: _coordFromJson(_object(json, 'coord')),
    type: _enum(HexTileType.values, _string(json, 'type'), 'type'),
    opened: _bool(json, 'opened'),
    exits: _ints(json, 'exits').map(HexEdge.fromIndex),
    locationId: _nullableString(json['location_id'], 'location_id'),
    hasTerminal: _bool(json, 'has_terminal'),
    ventColor: _enum(
      VentColor.values,
      _string(json, 'vent_color'),
      'vent_color',
    ),
    isBlocked: _boolOrDefault(json['is_blocked'], 'is_blocked'),
  );
  static Map<String, Object?> playerToJson(PlayerState player) => {
    'id': player.id,
    'character_id': player.characterId,
    'coord': _coordToJson(player.coord),
    'damage': player.damage,
    'health': player.health,
    'credits': player.credits,
    'backpack': player.backpack,
    'equipped': {
      'weapon': player.equipped.weapon,
      'second_weapon': player.equipped.secondWeapon,
      'armor': player.equipped.armor,
      'clothing': player.equipped.clothing,
      'robot': player.equipped.robot,
    },
    'carried_mods': player.carriedMods,
    'implanted': player.implanted,
    'conditions': player.conditions,
    'alive': player.alive,
    'stats': _statsToJson(player.stats),
    'weapon_modifier': player.weaponModifier,
  };
  static PlayerState playerFromJson(Map<String, Object?> json) {
    final equipped = _object(json, 'equipped');
    return PlayerState(
      id: _string(json, 'id'),
      characterId: _string(json, 'character_id'),
      coord: _coordFromJson(_object(json, 'coord')),
      damage: _int(json, 'damage'),
      health: _int(json, 'health'),
      credits: _int(json, 'credits'),
      backpack: _strings(json, 'backpack'),
      equipped: EquippedGear(
        weapon: _nullableString(equipped['weapon'], 'equipped.weapon'),
        secondWeapon: _nullableString(
          equipped['second_weapon'],
          'equipped.second_weapon',
        ),
        armor: _nullableString(equipped['armor'], 'equipped.armor'),
        clothing: _nullableString(equipped['clothing'], 'equipped.clothing'),
        robot: _nullableString(equipped['robot'], 'equipped.robot'),
      ),
      carriedMods: _strings(json, 'carried_mods'),
      implanted: _strings(json, 'implanted'),
      conditions: _strings(json, 'conditions'),
      alive: _bool(json, 'alive'),
      stats: _statsFromJson(_object(json, 'stats')),
      weaponModifier: _int(json, 'weapon_modifier'),
    );
  }

  static Map<String, Object?> reserveHeroToJson(ReserveHero hero) => {
    'character_id': hero.characterId,
    'health': hero.health,
    'credits': hero.credits,
    'backpack': hero.backpack,
    'equipped': {
      'weapon': hero.equipped.weapon,
      'second_weapon': hero.equipped.secondWeapon,
      'armor': hero.equipped.armor,
      'clothing': hero.equipped.clothing,
      'robot': hero.equipped.robot,
    },
    'carried_mods': hero.carriedMods,
    'implanted': hero.implanted,
    'stats': _statsToJson(hero.stats),
  };

  static ReserveHero reserveHeroFromJson(Map<String, Object?> json) {
    final equipped = _object(json, 'equipped');
    return ReserveHero(
      characterId: _string(json, 'character_id'),
      health: _int(json, 'health'),
      credits: _int(json, 'credits'),
      backpack: _strings(json, 'backpack'),
      equipped: EquippedGear(
        weapon: _nullableString(equipped['weapon'], 'equipped.weapon'),
        secondWeapon: _nullableString(
          equipped['second_weapon'],
          'equipped.second_weapon',
        ),
        armor: _nullableString(equipped['armor'], 'equipped.armor'),
        clothing: _nullableString(equipped['clothing'], 'equipped.clothing'),
        robot: _nullableString(equipped['robot'], 'equipped.robot'),
      ),
      carriedMods: _strings(json, 'carried_mods'),
      implanted: _strings(json, 'implanted'),
      stats: _statsFromJson(_object(json, 'stats')),
    );
  }

  static Map<String, Object?> monsterToJson(MonsterInstance monster) => {
    'instance_id': monster.instanceId,
    'monster_id': monster.monsterId,
    'coord': _coordToJson(monster.coord),
    'damage': monster.damage,
    'health': monster.health,
    'defense': monster.defense,
    'attack': monster.attack,
    'movement': monster.movement,
    'carried_gear': monster.carriedGear,
  };
  static MonsterInstance monsterFromJson(Map<String, Object?> json) =>
      MonsterInstance(
        instanceId: _string(json, 'instance_id'),
        monsterId: _string(json, 'monster_id'),
        coord: _coordFromJson(_object(json, 'coord')),
        damage: _int(json, 'damage'),
        health: _int(json, 'health'),
        defense: _int(json, 'defense'),
        attack: _int(json, 'attack'),
        movement: _int(json, 'movement'),
        carriedGear: _strings(json, 'carried_gear'),
      );
  static Map<String, Object?> boilToJson(BoilToken boil) => {
    'instance_id': boil.instanceId,
    'coord': _coordToJson(boil.coord),
  };
  static BoilToken boilFromJson(Map<String, Object?> json) => BoilToken(
    instanceId: _string(json, 'instance_id'),
    coord: _coordFromJson(_object(json, 'coord')),
  );
  static Map<String, Object?> conditionToJson(ConditionCard condition) => {
    'id': condition.id,
    'stat_modifiers': {
      for (final entry in condition.statModifiers.entries)
        entry.key.name: entry.value,
    },
  };
  static ConditionCard conditionFromJson(Map<String, Object?> json) =>
      ConditionCard(
        id: _string(json, 'id'),
        statModifiers: {
          for (final entry in _object(json, 'stat_modifiers').entries)
            _enum(StatType.values, entry.key, 'stat_modifiers'): _asInt(
              entry.value,
              'stat_modifiers.${entry.key}',
            ),
        },
      );

  static Map<String, Object?> cardDefinitionToJson(CardDefinition card) => {
    'id': card.id,
    'category': card.type.name,
    'slots': card.slots.map((slot) => slot.name).toList(),
    'cost': card.cost,
    'stats': {
      for (final entry in card.staticEffects.modifiers.entries)
        entry.key.name: entry.value,
    },
    'range': card.staticEffects.range,
    'behaviorIds': card.behaviorIds,
  };

  static CardDefinition cardDefinitionFromJson(Map<String, Object?> json) {
    // CardDefinition validates semantic constraints such as enum members and
    // non-negative cost with ArgumentError. Saved and posted JSON must surface
    // those as client format errors instead of server failures.
    try {
      return CardDefinition.fromJson(json);
      // ArgumentError carries the semantic validation detail for the response.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      throw FormatException('Invalid card definition: ${error.message}');
    }
  }

  static Map<String, Object?> incomingDamageToJson(IncomingDamage damage) => {
    'target_player_id': damage.targetPlayerId,
    'amount': damage.amount,
    'agility_dice': damage.agilityDice,
    'source': damage.source.name,
  };

  static IncomingDamage incomingDamageFromJson(Map<String, Object?> json) =>
      IncomingDamage(
        targetPlayerId: _string(json, 'target_player_id'),
        amount: _int(json, 'amount'),
        agilityDice: _int(json, 'agility_dice'),
        source: _enum(DamageSource.values, _string(json, 'source'), 'source'),
      );

  static Map<String, Object?> deckToJson(DeckState deck) => {
    'draw_pile': deck.drawPile,
    'discard_pile': deck.discardPile,
  };

  static DeckState deckFromJson(Map<String, Object?> json) => DeckState(
    drawPile: _strings(json, 'draw_pile'),
    discardPile: _strings(json, 'discard_pile'),
  );

  static Map<String, Object?> questsToJson(QuestState quests) => {
    'story_quest_ids': quests.storyQuestIds,
    'personal_tasks_by_player': quests.personalTasksByPlayer,
    'statuses': {
      for (final entry in quests.statuses.entries) entry.key: entry.value.name,
    },
  };

  static QuestState questsFromJson(Map<String, Object?> json) => QuestState(
    storyQuestIds: _strings(json, 'story_quest_ids'),
    personalTasksByPlayer: {
      for (final entry in _object(json, 'personal_tasks_by_player').entries)
        entry.key: _stringsFromValue(entry.value, 'personal_tasks_by_player'),
    },
    statuses: {
      for (final entry in _object(json, 'statuses').entries)
        entry.key: _enum(
          QuestStatus.values,
          _asString(entry.value, 'statuses.${entry.key}'),
          'statuses.${entry.key}',
        ),
    },
  );

  static Map<String, Object?>? decisionToJson(PendingDecision? decision) =>
      switch (decision) {
        null => null,
        AwaitingRerollChoice() => {
          'type': 'reroll',
          'dice': decision.dice,
          'available_rerolls': decision.availableRerolls,
          'max_dice_per_reroll': decision.maxDicePerReroll,
          'window': {'remaining_ticks': decision.window.remainingTicks},
          'context': _contextToJson(decision.context),
        },
        AwaitingDodge() => {
          'type': 'dodge',
          'monster_damage': decision.monsterDamage,
          'required_agility_successes': decision.requiredAgilitySuccesses,
          'target_player_id': decision.targetPlayerId,
          'source': decision.source.name,
        },
        AwaitingEventOption() => {
          'type': 'event_option',
          'options': decision.options,
          'player_id': decision.playerId,
          'event_id': decision.eventId,
        },
        AwaitingTerminalPick() => {
          'type': 'terminal_pick',
          'offered_cards': decision.offeredCards,
          'player_id': decision.playerId,
          'deck_id': decision.deckId,
        },
        AwaitingHeroReplacement() => {
          'type': 'hero_replacement',
          'player_id': decision.playerId,
          'character_ids': decision.characterIds,
        },
        AwaitingOtherPlayerDecision() => {
          'type': 'other_player',
          'awaiting_player_id': decision.awaitingPlayerId,
        },
      };

  static PendingDecision? decisionFromJson(Object? value) {
    if (value == null) return null;
    final json = _asObject(value, 'pending_decision');
    return switch (_string(json, 'type')) {
      'reroll' => AwaitingRerollChoice(
        dice: _ints(json, 'dice'),
        availableRerolls: _int(json, 'available_rerolls'),
        maxDicePerReroll: _optionalInt(json, 'max_dice_per_reroll') ?? 999,
        window: DecisionWindow(
          remainingTicks: _int(_object(json, 'window'), 'remaining_ticks'),
        ),
        context: _contextFromJson(json['context']),
      ),
      'dodge' => AwaitingDodge(
        monsterDamage: _int(json, 'monster_damage'),
        requiredAgilitySuccesses: _int(json, 'required_agility_successes'),
        targetPlayerId: _nullableString(
          json['target_player_id'],
          'target_player_id',
        ),
        source: _enum(DamageSource.values, _string(json, 'source'), 'source'),
      ),
      'event_option' => AwaitingEventOption(
        options: _strings(json, 'options'),
        playerId: _nullableString(json['player_id'], 'player_id'),
        eventId: _nullableString(json['event_id'], 'event_id'),
      ),
      'terminal_pick' => AwaitingTerminalPick(
        offeredCards: _strings(json, 'offered_cards'),
        playerId: _string(json, 'player_id'),
        deckId: _string(json, 'deck_id'),
      ),
      'hero_replacement' => AwaitingHeroReplacement(
        playerId: _string(json, 'player_id'),
        characterIds: _strings(json, 'character_ids'),
      ),
      'other_player' => AwaitingOtherPlayerDecision(
        awaitingPlayerId: _string(json, 'awaiting_player_id'),
      ),
      final type => throw FormatException(
        'Unknown pending decision type: $type.',
      ),
    };
  }

  static Map<String, Object?> eventToJson(GameEvent event) => switch (event) {
    HexEntered() => {
      'type': 'hex_entered',
      'player_id': event.playerId,
      'from': _coordToJson(event.from),
      'to': _coordToJson(event.to),
    },
    ColocationTriggered() => {
      'type': 'colocation_triggered',
      'player_id': event.playerId,
      'coord': _coordToJson(event.coord),
    },
    DamageDealt() => {
      'type': 'damage_dealt',
      'player_id': event.playerId,
      'amount': event.amount,
    },
    ConditionDrawn() => {
      'type': 'condition_drawn',
      'player_id': event.playerId,
      'condition_id': event.conditionId,
    },
    MvpDemonstrationCompleted() => {
      'type': 'mvp_demonstration_completed',
      'quest_id': event.questId,
      'player_id': event.playerId,
    },
    HeroDied() => {
      'type': 'hero_died',
      'player_id': event.playerId,
      'restless_instance_id': event.restlessInstanceId,
      'coord': _coordToJson(event.coord),
    },
  };

  static GameEvent eventFromJson(Map<String, Object?> json) =>
      switch (_string(json, 'type')) {
        'hex_entered' => HexEntered(
          playerId: _string(json, 'player_id'),
          from: _coordFromJson(_object(json, 'from')),
          to: _coordFromJson(_object(json, 'to')),
        ),
        'colocation_triggered' => ColocationTriggered(
          playerId: _string(json, 'player_id'),
          coord: _coordFromJson(_object(json, 'coord')),
        ),
        'damage_dealt' => DamageDealt(
          playerId: _string(json, 'player_id'),
          amount: _int(json, 'amount'),
        ),
        'condition_drawn' => ConditionDrawn(
          playerId: _string(json, 'player_id'),
          conditionId: _string(json, 'condition_id'),
        ),
        'mvp_demonstration_completed' => MvpDemonstrationCompleted(
          questId: _string(json, 'quest_id'),
          playerId: _string(json, 'player_id'),
        ),
        'hero_died' => HeroDied(
          playerId: _string(json, 'player_id'),
          restlessInstanceId: _string(json, 'restless_instance_id'),
          coord: _coordFromJson(_object(json, 'coord')),
        ),
        final type => throw FormatException('Unknown game event type: $type.'),
      };
}

Map<String, Object?> _coordToJson(HexCoord coord) => {
  'q': coord.q,
  'r': coord.r,
};

HexCoord _coordFromJson(Map<String, Object?> json) =>
    HexCoord(_int(json, 'q'), _int(json, 'r'));

Map<String, Object?> _statsToJson(PlayerStats stats) => {
  'strength': stats.strength,
  'combat_strength': stats.combatStrength,
  'science': stats.science,
  'repair': stats.repair,
  'endurance': stats.endurance,
  'agility': stats.agility,
};

PlayerStats _statsFromJson(Map<String, Object?> json) => PlayerStats(
  strength: _int(json, 'strength'),
  combatStrength: _int(json, 'combat_strength'),
  science: _int(json, 'science'),
  repair: _int(json, 'repair'),
  endurance: _int(json, 'endurance'),
  agility: _int(json, 'agility'),
);

Map<String, Object?>? _contextToJson(RollContext? context) => switch (context) {
  null => null,
  SkillCheckContext() => {
    'type': 'skill',
    'player_id': context.playerId,
    'stat': context.stat.name,
    'difficulty': context.difficulty,
    'event_id': context.eventId,
    'quest_id': context.questId,
  },
  AttackRollContext() => {
    'type': 'attack',
    'player_id': context.playerId,
    'target_instance_id': context.targetInstanceId,
    'pre_attack_damage': context.preAttackDamage,
  },
};

RollContext? _contextFromJson(Object? value) {
  if (value == null) return null;
  final json = _asObject(value, 'pending_decision.context');
  return switch (json['type']) {
    'attack' => AttackRollContext(
      playerId: _string(json, 'player_id'),
      targetInstanceId: _string(json, 'target_instance_id'),
      preAttackDamage: _optionalInt(json, 'pre_attack_damage') ?? 0,
    ),
    'skill' || null => SkillCheckContext(
      playerId: _string(json, 'player_id'),
      stat: _enum(StatType.values, _string(json, 'stat'), 'stat'),
      difficulty: _int(json, 'difficulty'),
      eventId: _nullableString(json['event_id'], 'event_id'),
      questId: _nullableString(json['quest_id'], 'quest_id'),
    ),
    final type => throw FormatException('Unknown reroll context type: $type.'),
  };
}

E _enum<E extends Enum>(List<E> values, String name, String key) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown $key enum value: $name.');
}

Map<String, Object?> _object(Map<String, Object?> json, String key) =>
    _asObject(json[key], key);

Map<String, Object?> _asObject(Object? value, String key) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object.');
  }
  return Map<String, Object?>.from(value);
}

String _string(Map<String, Object?> json, String key) =>
    _asString(json[key], key);

String _asString(Object? value, String key) {
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

String? _nullableString(Object? value, String key) {
  if (value == null || value is String) return value as String?;
  throw FormatException('$key must be a string or null.');
}

int _int(Map<String, Object?> json, String key) => _asInt(json[key], key);

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _asInt(value, key);
}

int _asInt(Object? value, String key) {
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

bool _boolOrDefault(Object? value, String key, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<String> _strings(Map<String, Object?> json, String key) =>
    _stringsFromValue(json[key], key);

List<String> _stringsFromValue(Object? value, String key) {
  if (value is! List<dynamic> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be an array of strings.');
  }
  return List<String>.from(value);
}

List<int> _ints(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<dynamic> || value.any((entry) => entry is! int)) {
    throw FormatException('$key must be an array of integers.');
  }
  return List<int>.from(value);
}
