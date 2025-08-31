import 'package:flutter_test/flutter_test.dart';

import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/game_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TitlesState 序列化與持久化', () {
    test('TitlesState toMap/fromMap round-trip', () {
      final origin = TitlesState(
        states: {
          't_a': 'locked',
          't_b': 'claimable',
          't_c': 'claimed',
        },
        claimedAt: {
          't_c': 1700000000000,
        },
        hasClaimable: true,
      );

      final map = origin.toMap();
      final restored = TitlesState.fromMap(map);

      expect(restored, equals(origin));
      expect(restored.states['t_b'], 'claimable');
      expect(restored.claimedAt['t_c'], 1700000000000);
      expect(restored.hasClaimable, isTrue);
    });

    test('GameStateService.updateGameState 會正確持久化 titles 狀態', () async {
      final svc = GameStateService();
      final initial = GameState.initial(1);
      await svc.initializeForTest(initial);

      // 初始應為空 TitlesState
      expect(svc.gameState.value.titles, isNotNull);
      expect(svc.gameState.value.titles!.states, isEmpty);

      // 更新：將 t_x 標記為 claimed，並設定 claimedAt 與紅點
      final now = 1710000000000;
      final current = svc.gameState.value;
      final titles = current.titles ?? const TitlesState();
      final updatedTitles = titles.copyWith(
        states: {
          ...titles.states,
          't_x': 'claimed',
        },
        claimedAt: {
          ...titles.claimedAt,
          't_x': now,
        },
        hasClaimable: false,
      );

      await svc.updateGameState(current.copyWith(titles: updatedTitles));

      final after = svc.gameState.value;
      expect(after.titles, isNotNull);
      expect(after.titles!.states['t_x'], 'claimed');
      expect(after.titles!.claimedAt['t_x'], now);
      expect(after.titles!.hasClaimable, isFalse);
      expect(after.validate(), isTrue);
    });
  });
}
