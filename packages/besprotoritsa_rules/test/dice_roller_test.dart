import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:test/test.dart';

void main() {
  group('SeededDiceRoller', () {
    test('reproduces 10,000 rolls from the same seed', () {
      final first = SeededDiceRoller(0x13579BDF).rollDice(10000);
      final second = SeededDiceRoller(0x13579BDF).rollDice(10000);

      expect(first, second);
      expect(first, everyElement(inInclusiveRange(1, 6)));
    });

    test('matches the platform-independent xorshift32 golden sequence', () {
      final rolls = SeededDiceRoller(0x13579BDF).rollDice(10000);

      expect(
        rolls.take(16),
        [6, 2, 6, 3, 5, 4, 6, 2, 3, 2, 3, 3, 3, 3, 6, 5],
      );
      expect(_rollFingerprint(rolls), 0x8285CD46);
    });

    test('shuffles a copy deterministically', () {
      final original = [1, 2, 3, 4, 5];

      expect(SeededDiceRoller(42).shuffle(original), [2, 5, 4, 1, 3]);
      expect(original, [1, 2, 3, 4, 5]);
    });
  });

  group('FixedDiceRoller', () {
    test('consumes configured dice values and fails when exhausted', () {
      final roller = FixedDiceRoller([6, 1, 4]);

      expect(roller.rollDice(2), [6, 1]);
      expect(roller.rollDice(1), [4]);
      expect(() => roller.rollDice(1), throwsStateError);
    });

    test('uses configured values for a shuffle', () {
      final roller = FixedDiceRoller([1, 2, 3]);

      expect(roller.shuffle(['a', 'b', 'c', 'd']), ['c', 'd', 'b', 'a']);
    });
  });

  test('countHits applies the base 4–6 success rule', () {
    expect(countHits([1, 2, 3, 4, 5, 6]), 3);
  });
}

int _rollFingerprint(Iterable<int> rolls) {
  const uint32Mask = 0xFFFFFFFF;
  var fingerprint = 0;
  for (final roll in rolls) {
    fingerprint = (fingerprint * 31 + roll) & uint32Mask;
  }
  return fingerprint;
}
