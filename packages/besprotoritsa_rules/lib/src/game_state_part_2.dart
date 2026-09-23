// API documentation is retained in the original library source.
// ignore_for_file: public_member_api_docs

// Preserve model constructor parameter order while splitting this library.
// ignore_for_file: always_put_required_named_parameters_first

part of 'game_state.dart';

@immutable
class MonsterInstance {
  MonsterInstance({
    required this.instanceId,
    required this.monsterId,
    required this.coord,
    required this.damage,
    this.health = 1,
    this.defense = 0,
    this.attack = 0,
    this.movement = 1,
    Iterable<CardId> carriedGear = const [],
  }) : carriedGear = List.unmodifiable(carriedGear) {
    _requireId(instanceId, 'instanceId');
    _requireId(monsterId, 'monsterId');
    _requireNonNegative(damage, 'damage');
    _requireNonNegative(health, 'health');
    _requireNonNegative(defense, 'defense');
    _requireNonNegative(attack, 'attack');
    _requireNonNegative(movement, 'movement');
  }

  final String instanceId;
  final String monsterId;
  final HexCoord coord;
  final int damage;
  final int health;
  final int defense;
  final int attack;

  /// Number of connected, opened sectors this monster traverses per round.
  final int movement;
  final List<CardId> carriedGear;
}

/// The infected form created in the sector where a hero dies.
///
/// The base values match the printed Restless card.  Its attack and defense
/// can be increased by the deceased hero's active equipment.
@immutable
final class RestlessMonster extends MonsterInstance {
  RestlessMonster({
    required super.instanceId,
    required super.coord,
    required super.attack,
    required super.defense,
    required super.carriedGear,
  }) : super(
         monsterId: restlessMonsterId,
         damage: 0,
         health: baseHealth,
         movement: baseMovement,
       );

  static const String restlessMonsterId = 'restless';
  static const int baseHealth = 1;
  static const int baseAttack = 1;
  static const int baseDefense = 0;
  static const int baseMovement = 1;
}

/// A character which can replace a fallen hero.
///
/// Reserve characters deliberately contain only their own starting state;
/// they never inherit the dead hero's credits, conditions, or inventory.
@immutable
final class ReserveHero {
  ReserveHero({
    required this.characterId,
    required this.health,
    required this.stats,
    this.credits = 0,
    Iterable<CardId> backpack = const [],
    this.equipped = const EquippedGear(),
    Iterable<CardId> carriedMods = const [],
    Iterable<CardId> implanted = const [],
  }) : backpack = List.unmodifiable(backpack),
       carriedMods = List.unmodifiable(carriedMods),
       implanted = List.unmodifiable(implanted) {
    _requireId(characterId, 'characterId');
    if (health < 1) {
      throw ArgumentError.value(health, 'health', 'Health must be positive.');
    }
    _requireNonNegative(credits, 'credits');
  }

  final CharacterId characterId;
  final int health;
  final PlayerStats stats;
  final int credits;
  final List<CardId> backpack;
  final EquippedGear equipped;
  final List<CardId> carriedMods;
  final List<CardId> implanted;
}

/// Full deck state. Its card order is deliberately available only in GameState.
@immutable
final class DeckState {
  DeckState({
    required Iterable<CardId> drawPile,
    Iterable<CardId> discardPile = const [],
  }) : drawPile = List.unmodifiable(drawPile),
       discardPile = List.unmodifiable(discardPile);

  final List<CardId> drawPile;
  final List<CardId> discardPile;

  int get cardsRemaining => drawPile.length;
}

/// The immutable result of drawing one or more cards from a [DeckState].
@immutable
final class DeckDraw {
  DeckDraw({required Iterable<CardId> cards, required this.deck})
    : cards = List.unmodifiable(cards);

  final List<CardId> cards;
  final DeckState deck;
}

/// Deterministic deck operations shared by effects, rewards, and terminals.
///
/// A discard pile is recycled only once the draw pile is empty.  This means a
/// partially used draw pile always remains on top, while still making a deck
/// usable after it has been exhausted. The `seed` is supplied by the caller so
/// replays do not depend on process-local randomness.
abstract final class DeckRules {
  /// Draws up to [count] cards, recycling and shuffling the discard pile when
  /// necessary. Story decks can opt out of recycling with [recycleDiscard].
  static DeckDraw draw(
    DeckState deck, {
    int count = 1,
    int seed = 0,
    bool recycleDiscard = true,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Must not be negative.');
    }
    var drawPile = List<CardId>.of(deck.drawPile);
    var discardPile = List<CardId>.of(deck.discardPile);
    final cards = <CardId>[];
    var shuffleSeed = seed;
    while (cards.length < count) {
      if (drawPile.isEmpty) {
        if (!recycleDiscard || discardPile.isEmpty) break;
        drawPile = _shuffled(discardPile, shuffleSeed);
        discardPile = <CardId>[];
        shuffleSeed++;
      }
      cards.add(drawPile.removeAt(0));
    }
    return DeckDraw(
      cards: cards,
      deck: DeckState(drawPile: drawPile, discardPile: discardPile),
    );
  }

  /// Draws [cardId] wherever it appears in the active deck and shuffles the
  /// remaining draw pile, as required by effects that search for a card.
  static DeckDraw drawSpecific(
    DeckState deck,
    CardId cardId, {
    int seed = 0,
    bool recycleDiscard = true,
  }) {
    var prepared = deck;
    if (prepared.drawPile.isEmpty && recycleDiscard) {
      if (prepared.discardPile.isNotEmpty) {
        prepared = DeckState(
          drawPile: _shuffled(prepared.discardPile, seed),
        );
      }
    }
    final cards = List<CardId>.of(prepared.drawPile);
    if (!cards.remove(cardId)) {
      return DeckDraw(cards: const [], deck: prepared);
    }
    return DeckDraw(
      cards: [cardId],
      deck: DeckState(
        drawPile: _shuffled(cards, seed),
        discardPile: prepared.discardPile,
      ),
    );
  }

  /// Returns cards to the draw pile and shuffles the combined pile.
  static DeckState returnAndShuffle(
    DeckState deck,
    Iterable<CardId> cards, {
    int seed = 0,
  }) => DeckState(
    drawPile: _shuffled([...deck.drawPile, ...cards], seed),
    discardPile: deck.discardPile,
  );

  static List<CardId> _shuffled(Iterable<CardId> cards, int seed) {
    final shuffled = List<CardId>.of(cards);
    var state = seed & 0x7fffffff;
    for (var index = shuffled.length - 1; index > 0; index--) {
      // A small local PRNG avoids a mutable global Random and is stable in
      // server, client, and replay runtimes.
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      final other = state % (index + 1);
      final card = shuffled[index];
      shuffled[index] = shuffled[other];
      shuffled[other] = card;
    }
    return shuffled;
  }
}

/// Story quests and private personal tasks.
