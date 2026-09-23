// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

part of 'commands_reducer.dart';

/// Converts every newly lethal hero into a Restless monster.
///
/// This function is public so non-combat damage effects can use the identical
/// death transition instead of reimplementing the loss of inventory and spawn.
GameState resolveHeroDeaths(GameState state) {
  final newlyDead = state.players
      .where((player) => player.alive && player.damage >= player.health)
      .toList();
  if (newlyDead.isEmpty) return state;

  final players = List<PlayerState>.of(state.players);
  final monsters = List<MonsterInstance>.of(state.monsters);
  final decks = Map<DeckId, DeckState>.of(state.decks);
  final events = List<GameEvent>.of(state.gameEvents);
  AwaitingHeroReplacement? replacementDecision;
  var noReserve = false;

  for (final deceased in newlyDead) {
    final carriedGear = _restlessGear(deceased, state.cardDefinitions);
    final bonuses = _restlessBonuses(deceased, state.cardDefinitions);
    final instanceId = _nextRestlessInstanceId(state, deceased.id, monsters);
    monsters.add(
      RestlessMonster(
        instanceId: instanceId,
        coord: deceased.coord,
        attack: RestlessMonster.baseAttack + bonuses.strength,
        defense: RestlessMonster.baseDefense + bonuses.defense,
        carriedGear: carriedGear,
      ),
    );
    final deadIndex = players.indexWhere((player) => player.id == deceased.id);
    players[deadIndex] = _copyPlayer(
      deceased,
      credits: 0,
      backpack: const [],
      equipped: const EquippedGear(),
      carriedMods: const [],
      implanted: const [],
      conditions: const [],
      alive: false,
      weaponModifier: 0,
    );
    final conditionDeck = decks['conditions'];
    if (conditionDeck != null && deceased.conditions.isNotEmpty) {
      decks['conditions'] = DeckState(
        drawPile: conditionDeck.drawPile,
        discardPile: [...conditionDeck.discardPile, ...deceased.conditions],
      );
    }
    events.add(
      HeroDied(
        playerId: deceased.id,
        restlessInstanceId: instanceId,
        coord: deceased.coord,
      ),
    );
    if (state.reserveHeroes.isEmpty) {
      noReserve = true;
    } else {
      replacementDecision ??= AwaitingHeroReplacement(
        playerId: deceased.id,
        characterIds: state.reserveHeroes.map((hero) => hero.characterId),
      );
    }
  }

  return _copyState(
    state,
    players: players,
    monsters: monsters,
    decks: decks,
    pendingDamage: state.pendingDamage.where(
      (damage) => players.any(
        (player) => player.id == damage.targetPlayerId && player.alive,
      ),
    ),
    gameEvents: events,
    isComplete: noReserve || state.isComplete,
    pendingDecision: noReserve ? null : replacementDecision,
    clearPendingDecision: noReserve,
    logEntry: 'hero-died:${newlyDead.map((hero) => hero.id).join(',')}',
  );
}

List<CardId> _restlessGear(
  PlayerState deceased,
  Map<CardId, CardDefinition> definitions,
) => [
  for (final cardId in [
    ...deceased.backpack,
    ...deceased.equipped.weapons,
    deceased.equipped.armor,
    deceased.equipped.clothing,
    deceased.equipped.robot,
    ...deceased.carriedMods,
    ...deceased.implanted,
  ])
    if (cardId != null && definitions[cardId]?.type != ItemType.supply) cardId,
];

({int strength, int defense}) _restlessBonuses(
  PlayerState deceased,
  Map<CardId, CardDefinition> definitions,
) {
  var strength = 0;
  var defense = 0;
  for (final cardId in InventoryRules.activeCardIds(deceased)) {
    final effects = definitions[cardId]?.staticEffects;
    if (effects == null) continue;
    strength += effects[CardStat.strength].clamp(0, 999);
    defense += effects[CardStat.defense].clamp(0, 999);
  }
  return (strength: strength, defense: defense);
}

String _nextRestlessInstanceId(
  GameState state,
  PlayerId playerId,
  Iterable<MonsterInstance> monsters,
) {
  final prefix = 'restless-${state.round}-$playerId';
  var suffix = 1;
  var id = '$prefix-$suffix';
  while (monsters.any((monster) => monster.instanceId == id)) {
    id = '$prefix-${++suffix}';
  }
  return id;
}

GameStepResult _startPlayerSkillCheck(
  GameState state,
  StatType stat,
  DiceRoller dice,
) {
  final player = _activePlayer(state)!;
  final tile = state.tileAt(player.coord);
  final completesQuest =
      stat == StatType.science &&
      tile?.locationId == 'crew-mess' &&
      state.quests.storyQuestIds.contains('chapter-1-awakening') &&
      state.quests.statusOf('chapter-1-awakening') == QuestStatus.active;
  return _startRoll(
    state,
    dice,
    'skill-check:${player.id}:${stat.name}',
    diceCount: _statDice(player, state, stat),
    context: SkillCheckContext(
      playerId: player.id,
      stat: stat,
      difficulty: state.difficulty,
      questId: completesQuest ? 'chapter-1-awakening' : null,
    ),
  );
}

String _attackLog(
  PlayerState player,
  MonsterInstance monster,
  int damage,
  bool defeated, {
  List<CardId> unclaimedLoot = const <CardId>[],
}) =>
    'attack:${player.id}:${monster.instanceId}:$damage'
    '${defeated ? ':defeated' : ''}'
    '${unclaimedLoot.isEmpty ? '' : ':unclaimed:${unclaimedLoot.join(',')}'}';

int _heroAttackDice(PlayerState player, GameState state) =>
    _statDice(player, state, StatType.strength) + player.weaponModifier;

List<EffectHook> _activeEffectHooks(GameState state, PlayerState player) {
  final registry = EffectRegistry.standard();
  return [
    for (final cardId in _activeCardIds(player))
      for (final behaviorId
          in state.cardDefinitions[cardId]?.behaviorIds ?? const <String>[])
        if (registry[behaviorId] case final EffectHook hook) hook,
  ];
}

int _statDice(PlayerState player, GameState state, StatType stat) {
  final modifier = player.conditions.fold<int>(
    0,
    (total, conditionId) =>
        total + (state.conditionCards[conditionId]?.statModifiers[stat] ?? 0),
  );
  return (player.stats.valueFor(stat) +
          modifier +
          _cardStatModifier(
            state,
            player,
            stat,
          ))
      .clamp(1, 999);
}

int _cardStatModifier(GameState state, PlayerState player, StatType stat) {
  final cardStat = switch (stat) {
    StatType.strength || StatType.combatStrength => CardStat.strength,
    StatType.science => CardStat.science,
    StatType.repair => CardStat.repair,
    StatType.endurance => CardStat.endurance,
    StatType.agility => CardStat.agility,
  };
  return _activeCardIds(player).fold(
    0,
    (sum, id) =>
        sum + (state.cardDefinitions[id]?.staticEffects[cardStat] ?? 0),
  );
}

Iterable<String> _activeCardIds(PlayerState player) sync* {
  yield* InventoryRules.activeCardIds(player);
}

GameState _heal(GameState state, int amount) {
  final player = _activePlayer(state)!;
  final conditionDeck = state.decks['conditions'];
  final decks = Map<DeckId, DeckState>.of(state.decks);
  if (conditionDeck != null && player.conditions.isNotEmpty) {
    decks['conditions'] = DeckState(
      drawPile: conditionDeck.drawPile,
      discardPile: [...conditionDeck.discardPile, ...player.conditions],
    );
  }
  return _copyState(
    state,
    actionsLeft: state.actionsLeft - 1,
    players: _replaceActivePlayer(
      state,
      (current) => _copyPlayer(
        current,
        damage: (current.damage - amount).clamp(0, current.damage),
        conditions: const [],
      ),
    ),
    decks: decks,
    logEntry: 'heal:${player.id}:$amount',
  );
}

List<HexTile> _openTile(List<HexTile> board, HexTile destination) => [
  for (final tile in board)
    if (tile.coord == destination.coord)
      _copyTile(tile, opened: true)
    else
      tile,
];

HexTile _copyTile(HexTile tile, {bool? opened, bool? isBlocked}) => HexTile(
  id: tile.id,
  coord: tile.coord,
  type: tile.type,
  opened: opened ?? tile.opened,
  exits: tile.exits,
  locationId: tile.locationId,
  hasTerminal: tile.hasTerminal,
  ventColor: tile.ventColor,
  isBlocked: isBlocked ?? tile.isBlocked,
);
