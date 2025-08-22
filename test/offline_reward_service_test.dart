import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/offline_reward_service.dart';

void main() {
  // 初始化 Widgets 綁定，供 OfflineRewardService 使用 WidgetsBindingObserver
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OfflineRewardService', () {
    late OfflineRewardService service;
    late GameState state;
    late int nowMs;
    double lastReward = 0;
    Duration lastEffective = Duration.zero;

    setUp(() {
      service = OfflineRewardService();
      nowMs = DateTime.utc(2025, 1, 1, 0, 0, 0).millisecondsSinceEpoch;
      state = GameState(
        saveVersion: 1,
        memePoints: 0,
        equipments: const {},
        lastTs: nowMs,
        offline: const OfflineState(),
      );
      lastReward = 0;
      lastEffective = Duration.zero;

      service.init(
        getIdlePerSec: () => state.offline.idleRateSnapshot,
        getGameState: () => state,
        onPersist: (updated) async {
          state = updated; // 模擬持久化後的狀態更新
        },
        onPendingReward: (r, d) {
          lastReward = r;
          lastEffective = d;
        },
        nowUtcMsProvider: () => nowMs,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('no lastExit -> no reward (no auto-claim)', () async {
      // 未曾離線
      state = state.copyWith(
        offline: state.offline.copyWith(
          lastExitUtcMs: 0,
          idleRateSnapshot: 2.0,
        ),
      );

      // 直接回前台
      await service.simulateAddSeconds(60);
      expect(state.offline.pendingReward, 0);
      expect(state.memePoints, 2 * 60);
      expect(lastReward, 2 * 60);
    });

    test('basic 60s at 2/sec -> 120 auto-claimed', () async {
      // 背景時刻
      state = state.copyWith(
        offline: state.offline.copyWith(
          lastExitUtcMs: nowMs,
          idleRateSnapshot: 2.0,
        ),
      );

      // 模擬 +60s 離線
      await service.simulateAddSeconds(60);

      // 新規則：直接入帳，pendingReward 維持 0，並透過 callback 通知本次金額
      expect(state.memePoints, closeTo(120.0, 1e-6));
      expect(state.offline.pendingReward, 0);
      expect(lastReward, closeTo(120.0, 1e-6));
      expect(lastEffective.inSeconds, 60);
    });

    test('cap at 6h', () async {
      // 7 小時離線，cap 應該以 6 小時計
      state = state.copyWith(
        offline: state.offline.copyWith(
          lastExitUtcMs: nowMs - 7 * 3600 * 1000,
          idleRateSnapshot: 2.0,
        ),
      );

      // 觸發回前台結算
      await service.simulateAddSeconds(1); // 任意值，觸發 _onResumed()

      // 6h = 21600s, *2/sec = 43200，直接入帳
      expect(state.memePoints, closeTo(43200.0, 1e-6));
      expect(state.offline.pendingReward, 0);
      expect(lastReward, closeTo(43200.0, 1e-6));
      expect(lastEffective.inSeconds, 21600);
    });

    test('existing pendingReward does not recompute', () async {
      // 兼容舊版本：若已有待領取，回前台時自動入帳並清空
      state = state.copyWith(
        offline: state.offline.copyWith(
          lastExitUtcMs: nowMs - 60000,
          idleRateSnapshot: 3.0,
          pendingReward: 999.0,
        ),
      );

      await service.simulateAddSeconds(60);

      // 新規則：直接將 999 入帳，pending 清 0，callback 告知 999
      expect(state.memePoints, closeTo(999.0, 1e-6));
      expect(state.offline.pendingReward, 0);
      expect(lastReward, 999.0);
    });

    test('clearPending clears reward', () async {
      state = state.copyWith(
        offline: state.offline.copyWith(
          lastExitUtcMs: nowMs,
          idleRateSnapshot: 1.0,
        ),
      );
      await service.simulateAddSeconds(10);
      // 新規則：已自動入帳，pendingReward 應為 0
      expect(state.offline.pendingReward, 0);
      expect(state.memePoints, closeTo(10.0, 1e-6));

      await service.clearPending();
      expect(state.offline.pendingReward, 0);
    });
  });
}
