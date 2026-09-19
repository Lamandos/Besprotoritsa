// The exported registry and validation types are concise data contracts.
// ignore_for_file: public_member_api_docs

import 'dart:collection';

import 'package:besprotoritsa_rules/src/card_definition.dart';
import 'package:besprotoritsa_rules/src/effect_hooks.dart';

final class UnknownBehaviorId {
  const UnknownBehaviorId({required this.cardId, required this.behaviorId});

  final String cardId;
  final String behaviorId;

  @override
  String toString() =>
      'Card $cardId references unknown behaviorId $behaviorId.';
}

final class EffectDataValidationException implements Exception {
  const EffectDataValidationException(this.errors);

  final List<UnknownBehaviorId> errors;

  @override
  String toString() => errors.join(' ');
}

final class EffectRegistry {
  EffectRegistry(List<EffectHook> hooks)
    : _hookList = List.unmodifiable(hooks),
      _hooks = UnmodifiableMapView({
        for (final hook in hooks) hook.behaviorId: hook,
      }) {
    if (_hooks.length != _hookList.length) {
      throw ArgumentError.value(
        hooks,
        'hooks',
        'behaviorId values must be unique.',
      );
    }
  }

  factory EffectRegistry.standard() => EffectRegistry(const [
    ModifyRollHook('dice.successFace.3', additionalSuccessFaces: {3}),
    OnDamageHook(
      'dice.face6.damageBoth',
      target: EffectDamageTarget.owner,
      matchingFace: 6,
      damagePerMatchingFace: 1,
    ),
    ModifyRollHook('dice.reroll.twoPerAttack', rerollsPerAttack: 2),
    ModifyRollHook('dice.equalPair.addHit', addHitPerEqualPair: true),
    OnKillHook(
      'combat.damageAllEnemiesInSectorOnKill',
      damageToEnemiesInSameSector: 1,
    ),
    OnColocationHook('boil.explodeOnColocation', explodes: true),
    OnColocationHook('monster.passThroughAttack', attacksPassingPlayers: true),
    MonsterBehaviorHook(
      'monster-standard',
      behavior: MonsterBehavior.standard,
    ),
    MonsterBehaviorHook(
      'monster-reduce-combat-strength',
      behavior: MonsterBehavior.reduceCombatStrength,
    ),
    MonsterBehaviorHook(
      'monster-restore-full-health-if-alive',
      behavior: MonsterBehavior.restoreFullHealthIfAlive,
    ),
    MonsterBehaviorHook(
      'monster-spawn-boils-on-death',
      behavior: MonsterBehavior.spawnBoilsOnDeath,
    ),
    MonsterBehaviorHook(
      'monster-spawn-boil-instead-of-attack',
      behavior: MonsterBehavior.spawnBoilInsteadOfAttack,
    ),
    MonsterBehaviorHook(
      'monster-stationary-block-exits',
      behavior: MonsterBehavior.stationaryBlockExits,
    ),
    MonsterBehaviorHook(
      'monster-move-through-vents',
      behavior: MonsterBehavior.moveThroughVents,
    ),
    MonsterBehaviorHook(
      'monster-target-lowest-health-through-vents',
      behavior: MonsterBehavior.targetLowestHealthThroughVents,
    ),
    MonsterBehaviorHook(
      'monster-mother-ignores-armor-scales-per-hero',
      behavior: MonsterBehavior.motherIgnoresArmorAndScalesPerHero,
    ),
    MonsterBehaviorHook(
      'monster-scales-per-hero',
      behavior: MonsterBehavior.scalesPerHero,
    ),
    MonsterBehaviorHook(
      'monster-scales-per-alive-monster',
      behavior: MonsterBehavior.scalesPerAliveMonster,
    ),
    MonsterBehaviorHook(
      'monster-flees-and-spawns-two-boils',
      behavior: MonsterBehavior.fleesAndSpawnsTwoBoils,
    ),
    MonsterBehaviorHook(
      'boil-explodes-on-colocation',
      behavior: MonsterBehavior.explodesOnColocation,
    ),
    ModifyRollHook('pistol_attack_reroll', rerollsPerAttack: 1),
    OnDamageHook('gu4_rd_pre_attack_roll', target: EffectDamageTarget.target),
    CardBehaviorHook('combat.ignoreEnemyDefense'),
    CardBehaviorHook('combat.addHit'),
    CardBehaviorHook('combat.useScienceInsteadOfStrength'),
    CardBehaviorHook('combat.noHit.takeDamage'),
    CardBehaviorHook('combat.noHit.damageTarget'),
    CardBehaviorHook('combat.rechargeForCredits'),
    CardBehaviorHook('card.preventMonsterLoot'),
    CardBehaviorHook('map.moveHullBetweenAirlocks'),
    CardBehaviorHook('equipment.extraWeaponSlot'),
    CardBehaviorHook('equipment.extraRobotSlot'),
    CardBehaviorHook('equipment.implantRules'),
    CardBehaviorHook('robot.exhaust'),
    CardBehaviorHook('robot.ignoreEnemyFeatures'),
    CardBehaviorHook('map.forceMove'),
    CardBehaviorHook('map.remoteExchange'),
    CardBehaviorHook('map.revealAnyFragment'),
    CardBehaviorHook('damage.ignoreAnyUntilRoundEnd'),
    CardBehaviorHook('health.restore'),
    CardBehaviorHook('dice.reroll.allForSkill'),
    CardBehaviorHook('dice.reroll.anyCountPerAttack'),
    CardBehaviorHook('combat.selfDamageForHit'),
    CardBehaviorHook('card.discardCost'),
    CardBehaviorHook('action.grant'),
    CardBehaviorHook('economy.gainCredits'),
    CardBehaviorHook('economy.spendCredits'),
    CardBehaviorHook('action.spend'),
    CardBehaviorHook('map.moveAirlock'),
    CardBehaviorHook('monster.trapOnEnter'),
    CardBehaviorHook('monster.killNonBoss'),
    CardBehaviorHook('map.openCloseCorridor'),
    CardBehaviorHook('map.freeRevealOnEntry'),
    CardBehaviorHook('health.restoreAll'),
    CardBehaviorHook('damage.preventUntilRoundEnd'),
    CardBehaviorHook('robot.ready'),
    CardBehaviorHook('dice.reroll.one'),
    CardBehaviorHook('equipment.extraBackpackCapacity'),
    CardBehaviorHook('dice.reroll.all'),
    CardBehaviorHook('combat.pushUnkilledEnemy'),
    CardBehaviorHook('health.healingBonus'),
    CardBehaviorHook('damage.ignoreBoil'),
  ]);

  final List<EffectHook> _hookList;
  final Map<String, EffectHook> _hooks;

  EffectHook? operator [](String behaviorId) => _hooks[behaviorId];
  Iterable<String> get behaviorIds => _hooks.keys;

  List<EffectHook> hooksFor(CardDefinition card) {
    requireValid(card);
    return [for (final behaviorId in card.behaviorIds) _hooks[behaviorId]!];
  }

  List<UnknownBehaviorId> validate(CardDefinition card) => [
    for (final behaviorId in card.behaviorIds)
      if (!_hooks.containsKey(behaviorId))
        UnknownBehaviorId(cardId: card.id, behaviorId: behaviorId),
  ];

  void requireValid(CardDefinition card) {
    final errors = validate(card);
    if (errors.isNotEmpty) throw EffectDataValidationException(errors);
  }
}
