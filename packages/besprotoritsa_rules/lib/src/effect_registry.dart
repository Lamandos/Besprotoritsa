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
    ModifyRollHook('pistol_attack_reroll', rerollsPerAttack: 1),
    OnDamageHook('gu4_rd_pre_attack_roll', target: EffectDamageTarget.target),
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
