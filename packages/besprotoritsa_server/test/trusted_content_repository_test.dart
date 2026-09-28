import 'dart:io';

import 'package:besprotoritsa_server/src/trusted_content_repository.dart';
import 'package:test/test.dart';

void main() {
  group('TrustedContentRepository', () {
    final repository = TrustedContentRepository(Directory('content'));

    test('loads a party supported by the selected MVP content', () {
      final state = repository.createGame(
        contentSetId: 'mvp',
        partySize: 2,
        mode: const {},
        seed: 1,
      );

      expect(state.players.map((player) => player.characterId), [
        'engineer',
        'guard',
      ]);
    });

    test('rejects a party larger than the selected MVP character roster', () {
      expect(
        () => repository.createGame(
          contentSetId: 'mvp',
          partySize: 3,
          mode: const {},
          seed: 1,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('characters available in content set mvp'),
          ),
        ),
      );
    });
  });
}
