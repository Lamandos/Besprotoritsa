import 'package:besprotoritsa_app/src/game/projected_game_state_codec.dart';
import 'package:besprotoritsa_rules/besprotoritsa_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains a hidden pending decision as a blocking placeholder', () {
    final state = const ProjectedGameStateCodec().decode(<String, Object?>{
      'schemaVersion': 1,
      'round': 1,
      'phase': 'playersTurn',
      'activePlayerId': 'ada',
      'actionsLeft': 2,
      'board': <Object?>[],
      'players': <Object?>[
        <String, Object?>{
          'id': 'ada',
          'characterId': 'scientist',
          'coord': <String, int>{'q': 0, 'r': 0},
          'damage': 0,
          'health': 10,
          'credits': 0,
          'equipped': <String, Object?>{},
          'backpack': <Object?>[],
          'carriedMods': <Object?>[],
          'implanted': <Object?>[],
          'conditions': <Object?>[],
          'alive': true,
        },
      ],
      'monsters': <Object?>[],
      'decks': <String, Object?>{},
      'quests': <String, Object?>{'storyQuestIds': <Object?>[]},
      'log': <Object?>[],
      'pendingDecision': <String, String>{
        'type': 'hidden',
        'awaitingPlayerId': 'boris',
      },
    });

    expect(state.pendingDecision, isA<AwaitingOtherPlayerDecision>());
    expect(
      (state.pendingDecision! as AwaitingOtherPlayerDecision).awaitingPlayerId,
      'boris',
    );
  });
}
