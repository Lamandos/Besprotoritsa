import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initializes every hero offered by the roster', () {
    final state = createMvpGameState(
      characterIds: const ['scientist', 'guard', 'mechanic', 'healer'],
    );

    final scientist = state.players[0];
    final mechanic = state.players[2];
    final healer = state.players[3];

    expect(scientist.health, 8);
    expect(scientist.stats.science, 4);
    expect(scientist.stats.endurance, 1);
    expect(scientist.credits, 5);
    expect(scientist.backpack, ['lucky-socks']);
    expect(mechanic.health, 9);
    expect(mechanic.stats.repair, 3);
    expect(mechanic.credits, 4);
    expect(mechanic.backpack, ['hard-hat']);
    expect(healer.health, 8);
    expect(healer.stats.science, 3);
    expect(healer.stats.endurance, 2);
    expect(healer.credits, 4);
    expect(healer.backpack, ['medic-bag']);
  });
}
