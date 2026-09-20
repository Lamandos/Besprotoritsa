// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';

/// Rehydrates the intentionally limited state projection sent to one player.
///
/// The authoritative server never sends hidden cards, deck order, or unseen
/// map details. Placeholder values here exist only so the shared game widgets
/// can render their normal [GameState]-based view; commands are never reduced
/// on the client in a multiplayer session.
final class ProjectedGameStateCodec {
  const ProjectedGameStateCodec();

  GameState decode(Map<String, Object?> json) => GameState(
    schemaVersion: _int(json, 'schemaVersion', fallback: 1),
    seed: _int(json, 'seed'),
    round: _int(json, 'round'),
    phase: _enum(GamePhase.values, _string(json, 'phase')),
    activePlayerId: json['activePlayerId'] as String?,
    actionsLeft: _int(json, 'actionsLeft'),
    board: _list(json, 'board').map(_tile),
    players: _list(json, 'players').map(_player),
    monsters: _list(json, 'monsters').map(_monster),
    decks: _object(json, 'decks').map(
      (id, count) => MapEntry(
        id,
        DeckState(drawPile: List<String>.filled(count as int, 'hidden-card')),
      ),
    ),
    quests: _quests(_object(json, 'quests')),
    log: _strings(json['log']),
    pendingDecision: _pendingDecision(json['pendingDecision']),
  );

  HexTile _tile(Map<String, Object?> json) {
    final coord = _coord(_object(json, 'coord'));
    final visible = json['tile'];
    if (visible is! Map<Object?, Object?>) {
      return HexTile(
        id: 'fog-${coord.q}-${coord.r}',
        coord: coord,
        type: HexTileType.corridor,
        opened: false,
        exits: const <HexEdge>{},
        hasTerminal: false,
        ventColor: VentColor.none,
      );
    }
    final tile = _map(visible);
    return HexTile(
      id: _string(tile, 'id'),
      coord: coord,
      type: _enum(HexTileType.values, _string(tile, 'type')),
      // A projected tile is visible, which is enough for the presentation
      // layer to treat it as explored.
      opened: true,
      exits: _values(
        tile,
        'exits',
      ).map((value) => HexEdge.values[value as int]).toSet(),
      locationId: tile['locationId'] as String?,
      hasTerminal: tile['hasTerminal'] == true,
      ventColor: _enum(VentColor.values, _string(tile, 'ventColor')),
      isBlocked: tile['isBlocked'] == true,
    );
  }

  PlayerState _player(Map<String, Object?> json) {
    final equipped = _object(json, 'equipped');
    return PlayerState(
      id: _string(json, 'id'),
      characterId: _string(json, 'characterId'),
      coord: _coord(_object(json, 'coord')),
      damage: _int(json, 'damage'),
      credits: _int(json, 'credits'),
      backpack: _strings(json['backpack']),
      equipped: EquippedGear(
        weapon: equipped['weapon'] as String?,
        secondWeapon: equipped['secondWeapon'] as String?,
        armor: equipped['armor'] as String?,
        clothing: equipped['clothing'] as String?,
        robot: equipped['robot'] as String?,
      ),
      carriedMods: _strings(json['carriedMods']),
      implanted: _strings(json['implanted']),
      conditions: _strings(json['conditions']),
      alive: json['alive'] == true,
    );
  }

  MonsterInstance _monster(Map<String, Object?> json) => MonsterInstance(
    instanceId: _string(json, 'instanceId'),
    monsterId: _string(json, 'monsterId'),
    coord: _coord(_object(json, 'coord')),
    damage: _int(json, 'damage'),
    health: _int(json, 'health'),
    defense: _int(json, 'defense'),
    attack: _int(json, 'attack'),
    movement: _int(json, 'movement'),
    carriedGear: _strings(json['carriedGear']),
  );

  QuestState _quests(Map<String, Object?> json) => QuestState(
    storyQuestIds: _strings(json['storyQuestIds']),
  );

  PendingDecision? _pendingDecision(Object? raw) {
    if (raw == null) return null;
    final json = _map(raw);
    return switch (_string(json, 'type')) {
      'reroll' => AwaitingRerollChoice(
        dice: _ints(json['dice']),
        availableRerolls: _int(json, 'availableRerolls'),
        window: const DecisionWindow(remainingTicks: 1),
      ),
      'dodge' => AwaitingDodge(
        monsterDamage: _int(json, 'monsterDamage'),
        requiredAgilitySuccesses: _int(json, 'requiredAgilitySuccesses'),
      ),
      'eventOption' => AwaitingEventOption(options: _strings(json['options'])),
      // The server withholds private card choices until it is their owner's
      // turn. These placeholders preserve the modal shape without inventing
      // hidden card data.
      'terminalPick' => AwaitingTerminalPick(
        offeredCards: const ['hidden-card'],
        playerId: _string(json, 'playerId'),
      ),
      'heroReplacement' => AwaitingHeroReplacement(
        playerId: _string(json, 'playerId'),
        characterIds: _strings(json['characterIds']),
      ),
      _ => null,
    };
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, Object?> _object(Map<String, Object?> json, String key) =>
    _map(json[key]);

List<Map<String, Object?>> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be an array.');
  return value.map(_map).toList();
}

List<Object?> _values(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) throw FormatException('$key must be an array.');
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string.');
  return value;
}

int _int(Map<String, Object?> json, String key, {int? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _strings(Object? value) =>
    (value as List<Object?>? ?? const <Object?>[])
        .map((entry) => entry as String)
        .toList();

List<int> _ints(Object? value) => (value as List<Object?>? ?? const <Object?>[])
    .map((entry) => entry as int)
    .toList();

HexCoord _coord(Map<String, Object?> json) =>
    HexCoord(_int(json, 'q'), _int(json, 'r'));

T _enum<T extends Enum>(List<T> values, String name) =>
    values.firstWhere((value) => value.name == name);
