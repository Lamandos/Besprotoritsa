import 'dart:collection';

/// A source of dice rolls and deterministic list permutations.
abstract interface class DiceRoller {
  /// Rolls [count] six-sided dice and returns their values in the range 1..6.
  List<int> rollDice(int count);

  /// Returns a shuffled copy of [items], leaving [items] unchanged.
  List<T> shuffle<T>(List<T> items);
}

/// A deterministic [DiceRoller] backed by the xorshift32 pseudo-random
/// number generator.
///
/// Every state transition is constrained to an unsigned 32-bit integer. This
/// makes the sequence stable on Dart VM and JavaScript, where JavaScript
/// numbers otherwise have different integer representation limits.
final class SeededDiceRoller implements DiceRoller {
  /// Creates a roller whose sequence is determined by [seed].
  ///
  /// xorshift32 has an all-zero absorbing state, so a zero seed is replaced
  /// with a fixed non-zero state.
  SeededDiceRoller(int seed)
    : _state = (seed & _uint32Mask) == 0 ? _zeroSeedState : seed & _uint32Mask;

  static const int _uint32Mask = 0xFFFFFFFF;
  static const int _zeroSeedState = 0x6D2B79F5;

  int _state;

  @override
  List<int> rollDice(int count) {
    _requireNonNegativeCount(count);
    return List<int>.generate(count, (_) => _nextUint32() % 6 + 1);
  }

  @override
  List<T> shuffle<T>(List<T> items) {
    final shuffled = List<T>.of(items);
    for (var index = shuffled.length - 1; index > 0; index--) {
      final swapIndex = _nextUint32() % (index + 1);
      final item = shuffled[index];
      shuffled[index] = shuffled[swapIndex];
      shuffled[swapIndex] = item;
    }
    return shuffled;
  }

  int _nextUint32() {
    var value = _state & _uint32Mask;
    value = (value ^ ((value << 13) & _uint32Mask)) & _uint32Mask;
    value = (value ^ (value >>> 17)) & _uint32Mask;
    value = (value ^ ((value << 5) & _uint32Mask)) & _uint32Mask;
    _state = value;
    return value;
  }
}

/// A [DiceRoller] which consumes a specified sequence of dice values.
///
/// It is intended for unit tests. Each configured result must be in 1..6 and
/// an attempt to consume more values than configured throws [StateError].
final class FixedDiceRoller implements DiceRoller {
  /// Creates a roller that returns [results] in order.
  FixedDiceRoller(Iterable<int> results) : _results = Queue<int>.of(results) {
    for (final result in _results) {
      if (result < 1 || result > 6) {
        throw ArgumentError.value(
          result,
          'results',
          'Dice values must be 1..6.',
        );
      }
    }
  }

  final Queue<int> _results;

  @override
  List<int> rollDice(int count) {
    _requireNonNegativeCount(count);
    if (_results.length < count) {
      throw StateError('Fixed dice results are exhausted.');
    }
    return List<int>.generate(count, (_) => _results.removeFirst());
  }

  @override
  List<T> shuffle<T>(List<T> items) {
    final shuffled = List<T>.of(items);
    for (var index = shuffled.length - 1; index > 0; index--) {
      final swapIndex = (rollDice(1).single - 1) % (index + 1);
      final item = shuffled[index];
      shuffled[index] = shuffled[swapIndex];
      shuffled[swapIndex] = item;
    }
    return shuffled;
  }
}

/// Counts successful six-sided dice rolls.
///
/// Under the base rule, faces 4, 5 and 6 are hits.
int countHits(Iterable<int> rolls) => rolls.where(_isHit).length;

bool _isHit(int roll) => roll >= 4 && roll <= 6;

void _requireNonNegativeCount(int count) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Must not be negative.');
  }
}
