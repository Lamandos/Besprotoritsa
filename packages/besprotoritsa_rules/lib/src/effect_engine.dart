// The exported hook result classes are self-explanatory value objects.
// ignore_for_file: public_member_api_docs

import 'package:besprotoritsa_rules/src/effect_hooks.dart';

final class RollEffectsResult {
  const RollEffectsResult({
    required this.hits,
    required this.ownerDamage,
    required this.rerollsAvailable,
  });

  final int hits;
  final int ownerDamage;
  final int rerollsAvailable;
}

final class KillEffectsResult {
  const KillEffectsResult(this.damageByEnemyId);

  final Map<String, int> damageByEnemyId;
}

final class EffectEngine {
  const EffectEngine();

  RollEffectsResult resolveRoll(
    Iterable<int> dice,
    Iterable<EffectHook> hooks,
  ) {
    final rolls = List<int>.of(dice);
    final modifiers = hooks.whereType<ModifyRollHook>().toList();
    final damageHooks = hooks.whereType<OnDamageHook>();
    final successFaces = {4, 5, 6};
    for (final hook in modifiers) {
      successFaces.addAll(hook.additionalSuccessFaces);
    }
    final pairHits = modifiers
        .where((hook) => hook.addHitPerEqualPair)
        .fold(0, (hits, _) => hits + _equalPairs(rolls));
    final ownerDamage = damageHooks
        .where((hook) => hook.target == EffectDamageTarget.owner)
        .fold(0, (damage, hook) => damage + _damageFromFaces(rolls, hook));
    return RollEffectsResult(
      hits: rolls.where(successFaces.contains).length + pairHits,
      ownerDamage: ownerDamage,
      rerollsAvailable: modifiers.fold(
        0,
        (sum, hook) => sum + hook.rerollsPerAttack,
      ),
    );
  }

  KillEffectsResult resolveKill({
    required String killedEnemyId,
    required String sectorId,
    required Map<String, String> enemySectors,
    required Iterable<EffectHook> hooks,
  }) {
    final damage = <String, int>{};
    final amount = hooks.whereType<OnKillHook>().fold(
      0,
      (sum, hook) => sum + hook.damageToEnemiesInSameSector,
    );
    if (amount == 0) return KillEffectsResult(damage);
    for (final entry in enemySectors.entries) {
      if (entry.key != killedEnemyId && entry.value == sectorId) {
        damage[entry.key] = amount;
      }
    }
    return KillEffectsResult(damage);
  }
}

int _equalPairs(Iterable<int> dice) {
  final counts = <int, int>{};
  for (final die in dice) {
    counts.update(die, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts.values.fold(0, (pairs, count) => pairs + count ~/ 2);
}

int _damageFromFaces(Iterable<int> dice, OnDamageHook hook) {
  final face = hook.matchingFace;
  if (face == null || hook.damagePerMatchingFace == 0) return 0;
  return dice.where((die) => die == face).length * hook.damagePerMatchingFace;
}
