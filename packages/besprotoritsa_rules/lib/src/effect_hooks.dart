// Typed, closed effect families. Content refers to an instance by behaviorId;
// no JSON document is allowed to name or construct a Dart implementation.
// ignore_for_file: public_member_api_docs

sealed class EffectHook {
  const EffectHook(this.behaviorId);

  final String behaviorId;
}

/// A named rule implemented by a card.  Some cards need a dedicated resolver,
/// while others are consumed by the turn, inventory, or map subsystem.  Keeping
/// their identifiers as hooks makes content validation exhaustive without
/// turning JSON into executable code.
final class CardBehaviorHook extends EffectHook {
  const CardBehaviorHook(super.behaviorId);
}

enum MonsterBehavior {
  standard,
  reduceCombatStrength,
  restoreFullHealthIfAlive,
  spawnBoilsOnDeath,
  spawnBoilInsteadOfAttack,
  stationaryBlockExits,
  moveThroughVents,
  targetLowestHealthThroughVents,
  motherIgnoresArmorAndScalesPerHero,
  scalesPerHero,
  scalesPerAliveMonster,
  fleesAndSpawnsTwoBoils,
  explodesOnColocation,
}

final class MonsterBehaviorHook extends EffectHook {
  const MonsterBehaviorHook(super.behaviorId, {required this.behavior});

  final MonsterBehavior behavior;
}

final class ModifyRollHook extends EffectHook {
  const ModifyRollHook(
    super.behaviorId, {
    this.additionalSuccessFaces = const {},
    this.rerollsPerAttack = 0,
    this.addHitPerEqualPair = false,
  });

  final Set<int> additionalSuccessFaces;
  final int rerollsPerAttack;
  final bool addHitPerEqualPair;
}

enum EffectDamageTarget { owner, target }

final class OnDamageHook extends EffectHook {
  const OnDamageHook(
    super.behaviorId, {
    required this.target,
    this.damagePerMatchingFace = 0,
    this.matchingFace,
  });

  final EffectDamageTarget target;
  final int damagePerMatchingFace;
  final int? matchingFace;
}

final class OnKillHook extends EffectHook {
  const OnKillHook(super.behaviorId, {this.damageToEnemiesInSameSector = 0});

  final int damageToEnemiesInSameSector;
}

final class OnColocationHook extends EffectHook {
  const OnColocationHook(
    super.behaviorId, {
    this.explodes = false,
    this.attacksPassingPlayers = false,
  });

  final bool explodes;
  final bool attacksPassingPlayers;
}
