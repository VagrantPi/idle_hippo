import 'package:flutter_test/flutter_test.dart';

import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/checkin_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Checkin collect accumulation', () {
    late GameStateService gs;
    late CheckinService checkin;

    setUp(() async {
      gs = GameStateService();
      checkin = CheckinService();

      // 構造一個今日為 collect 類型的打卡任務
      final today = CheckinToday(
        date: '2025-01-01',
        status: 'pending',
        task: CheckinTask(type: 'collect', target: 10, progress: 0),
      );
      final ci = CheckinState(today: today);
      final init = GameState.initial(1).copyWith(checkin: ci);
      await gs.initializeForTest(init);
    });

    test('小於 1 的多次累積應轉化為整數進度', () async {
      // 連續多次 <1 的累積
      for (int i = 0; i < 5; i++) {
        await checkin.updateCollectProgress(0.3); // 共 1.5
      }

      final s1 = gs.currentState;
      expect(s1.checkin?.today.task.progress, 1, reason: '0.3 * 5 = 1.5 -> 進度 +1');

      for (int i = 0; i < 20; i++) {
        await checkin.updateCollectProgress(0.25); // 累加 5
      }
      final s2 = gs.currentState;
      expect(s2.checkin?.today.task.progress, 6, reason: '之前 1 + 0.25*20=5 -> 6');
    });

    test('非 collect 任務時應忽略並重置緩衝', () async {
      // 切換成 tap 任務（模擬跨日或重新生成）
      final s0 = gs.currentState;
      final newToday = s0.checkin!.today.copyWith(
        task: s0.checkin!.today.task.copyWith(type: 'tap', target: 5, progress: 0),
      );
      await gs.updateGameState(s0.copyWith(checkin: s0.checkin!.copyWith(today: newToday)));

      await checkin.updateCollectProgress(10.0); // 應被忽略且不殘留緩衝

      final s1 = gs.currentState;
      expect(s1.checkin?.today.task.type, 'tap');
      expect(s1.checkin?.today.task.progress, 0);
    });
  });
}

