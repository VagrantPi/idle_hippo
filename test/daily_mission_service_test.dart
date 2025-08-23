import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/daily_mission_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  group('DailyMissionService 測試', () {
    late DailyMissionService service;
    late IdleIncomeService idleService;
    DateTime fixedTime = DateTime(2025, 8, 24, 12, 0, 0); // 2025-08-24 12:00:00 UTC

    setUp(() {
      service = DailyMissionService(now: () => fixedTime);
      idleService = IdleIncomeService();
      idleService.enableTestingMode(true);
      idleService.setTestingIdlePerSec(0.6); // 設定固定的 idle per sec
    });

    test('應該正確建立初始每日任務狀態', () {
      final initialState = GameState.initial(1);
      final result = service.ensureDailyMissionBlock(initialState);

      expect(result.dailyMission, isNotNull);
      expect(result.dailyMission!.date, '2025-08-24');
      expect(result.dailyMission!.index, 1);
      expect(result.dailyMission!.type, 'tapX');
      expect(result.dailyMission!.progress, 0.0);
      expect(result.dailyMission!.target, 50.0);
      expect(result.dailyMission!.todayCompleted, 0);
    });

    test('應該在跨日時重置任務', () {
      final oldMission = DailyMissionState(
        date: '2025-08-23', // 昨天
        index: 5,
        type: 'accumulateX',
        progress: 25.0,
        target: 100.0,
        idlePerSecSnapshot: 0.5,
        todayCompleted: 4,
      );
      final state = GameState.initial(1).copyWith(dailyMission: oldMission);

      final result = service.ensureDailyMissionBlock(state);

      expect(result.dailyMission!.date, '2025-08-24');
      expect(result.dailyMission!.index, 1);
      expect(result.dailyMission!.type, 'tapX');
      expect(result.dailyMission!.progress, 0.0);
      expect(result.dailyMission!.todayCompleted, 0);
    });

    test('應該正確生成奇數序任務（點擊50次）', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 100.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1, // 完成了1個，下一個是第2個（偶數）
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final result = service.generateNextMission(state);

      expect(result.dailyMission!.index, 2);
      expect(result.dailyMission!.type, 'accumulateX');
      expect(result.dailyMission!.progress, 0.0);
      expect(result.dailyMission!.target, 360.0); // 0.6 * 600 = 360
      expect(result.dailyMission!.idlePerSecSnapshot, 0.6);
    });

    test('應該正確生成偶數序任務（累積點數）', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 1,
        type: 'tapX',
        progress: 50.0,
        target: 50.0,
        idlePerSecSnapshot: 0.0,
        todayCompleted: 0, // 還沒完成，下一個是第1個（奇數）
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final result = service.generateNextMission(state);

      expect(result.dailyMission!.index, 1);
      expect(result.dailyMission!.type, 'tapX');
      expect(result.dailyMission!.progress, 0.0);
      expect(result.dailyMission!.target, 50.0);
    });

    test('應該正確處理有效點擊事件', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 1,
        type: 'tapX',
        progress: 25.0,
        target: 50.0,
        idlePerSecSnapshot: 0.0,
        todayCompleted: 0,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final result = service.onValidTap(state);

      expect(result.dailyMission!.progress, 26.0);
      expect(result.dailyMission!.todayCompleted, 0); // 還沒完成
    });

    test('應該正確處理資源獲得事件', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 50.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final result = service.onEarnPoints(state, 25.0);

      expect(result.dailyMission!.progress, 75.0);
      expect(result.dailyMission!.todayCompleted, 1); // 還沒完成
    });

    test('應該在任務完成時發放正確獎勵並生成下一個任務', () {
      double rewardReceived = 0.0;
      service.setRewardCallback((points) => rewardReceived = points);

      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 1,
        type: 'tapX',
        progress: 49.0,
        target: 50.0,
        idlePerSecSnapshot: 0.0,
        todayCompleted: 0,
      );
      final state = GameState.initial(1).copyWith(
        memePoints: 100.0,
        dailyMission: mission,
      );

      // 先達標（不會自動完成）
      final s1 = service.onValidTap(state);
      // 達標後由 claim 流程發放獎勵並切換任務
      final result = service.claimIfReady(s1);

      // 檢查獎勵
      expect(rewardReceived, 1.0); // 第1個任務獎勵是1
      expect(result.memePoints, 101.0); // 100 + 1

      // 檢查任務狀態
      expect(result.dailyMission!.todayCompleted, 1);
      expect(result.dailyMission!.index, 2); // 生成下一個任務
      expect(result.dailyMission!.type, 'accumulateX'); // 第2個是偶數序
      expect(result.dailyMission!.progress, 0.0); // 重置進度
    });

    test('應該在完成10個任務後不再生成新任務', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 10,
        type: 'accumulateX',
        progress: 100.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 9, // 已完成9個
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      // 先達標（不會自動完成）
      final s1 = service.onEarnPoints(state, 1.0);
      // 由 claim 流程計入完成，且不再生成新任務
      final result = service.claimIfReady(s1);

      expect(result.dailyMission!.todayCompleted, 10);
      expect(result.dailyMission!.index, 10); // 不生成新任務
    });

    test('應該正確處理獎勵序列', () {
      final rewards = <double>[];
      service.setRewardCallback((points) => rewards.add(points));

      // 模擬完成多個任務
      GameState state = GameState.initial(1).copyWith(memePoints: 0.0);
      
      for (int i = 1; i <= 5; i++) {
        state = service.ensureDailyMissionBlock(state);
        state = service.generateNextMission(state);
        state = service.forceCompleteMission(state);
      }

      expect(rewards, [1.0, 2.0, 3.0, 5.0, 8.0]);
    });

    test('應該忽略非相關任務類型的事件', () {
      // 測試點擊事件對累積任務無效
      final accumulateTask = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 25.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      final state1 = GameState.initial(1).copyWith(dailyMission: accumulateTask);
      final result1 = service.onValidTap(state1);
      expect(result1.dailyMission!.progress, 25.0); // 無變化

      // 測試資源事件對點擊任務無效
      final tapTask = DailyMissionState(
        date: '2025-08-24',
        index: 1,
        type: 'tapX',
        progress: 25.0,
        target: 50.0,
        idlePerSecSnapshot: 0.0,
        todayCompleted: 0,
      );
      final state2 = GameState.initial(1).copyWith(dailyMission: tapTask);
      final result2 = service.onEarnPoints(state2, 10.0);
      expect(result2.dailyMission!.progress, 25.0); // 無變化
    });

    test('應該正確處理模擬跨日重置', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 5,
        type: 'accumulateX',
        progress: 75.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 4,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final result = service.simulateDayReset(state);

      expect(result.dailyMission!.date, '2025-08-24');
      expect(result.dailyMission!.index, 1);
      expect(result.dailyMission!.type, 'tapX');
      expect(result.dailyMission!.progress, 0.0);
      expect(result.dailyMission!.todayCompleted, 0);
    });

    test('應該正確獲取統計資訊', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 3,
        type: 'tapX',
        progress: 30.0,
        target: 50.0,
        idlePerSecSnapshot: 0.0,
        todayCompleted: 2,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final stats = service.getStats(state);

      expect(stats['date'], '2025-08-24');
      expect(stats['index'], 3);
      expect(stats['type'], 'tapX');
      expect(stats['progress'], 30.0);
      expect(stats['target'], 50.0);
      expect(stats['todayCompleted'], 2);
      expect(stats['isCompleted'], false);
      expect(stats['nextReward'], 3); // 第3個任務的獎勵
    });

    test('應該正確獲取顯示參數', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 150.5,
        target: 360.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final params = service.getDisplayParams(state);

      expect(params['type'], 'accumulateX');
      expect(params['progress'], 150); // 轉為整數
      expect(params['target'], 360);
      expect(params['points'], 360); // 用於文案參數
    });

    test('應該在完成所有任務後顯示完成狀態', () {
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 10,
        type: 'accumulateX',
        progress: 100.0,
        target: 100.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 10,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      final params = service.getDisplayParams(state);

      expect(params['type'], 'completed');
      expect(params['progress'], 10);
      expect(params['target'], 10);
    });
  });
}
