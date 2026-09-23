// Nested conversion helpers are documented by the codec that owns them.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

part 'save_json_helpers.dart';

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
}
