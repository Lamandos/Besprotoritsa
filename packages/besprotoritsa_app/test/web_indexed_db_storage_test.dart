@TestOn('browser')
library;

import 'package:besprotoritsa_app/src/game/mvp_game_state.dart';
import 'package:besprotoritsa_app/src/storage/web_local_storage_game_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IndexedDB save is restored by a fresh browser storage adapter',
    () async {
      final firstPageLoad = WebIndexedDbGameStorage();
      final expected = createMvpGameState();

      await firstPageLoad.saveGame('web-refresh-verification', expected);
      await firstPageLoad.saveSlotName(
        'web-refresh-verification',
        'Проверка F5',
      );

      // A newly constructed adapter models storage opened after a page load.
      final afterRefresh = WebIndexedDbGameStorage();
      final restored = await afterRefresh.loadGame('web-refresh-verification');

      expect(restored, isNotNull);
      expect(restored!.seed, expected.seed);
      expect(restored.round, expected.round);
      expect(
        await afterRefresh.loadSlotName('web-refresh-verification'),
        'Проверка F5',
      );
    },
  );
}
