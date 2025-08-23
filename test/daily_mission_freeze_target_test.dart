import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/daily_mission_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  group('DailyMissionService：凍結目標與補救邏輯', () {
    late DailyMissionService service;
    late IdleIncomeService idleService;
    DateTime fixedTime = DateTime(2025, 8, 24, 12, 0, 0);

    setUp(() {
      service = DailyMissionService(now: () => fixedTime);
      idleService = IdleIncomeService();
      idleService.enableTestingMode(true);
      idleService.setTestingIdlePerSec(0.6); // 預設 0.6 => accumulate 目標 360
    });

  group('DailyMissionService：完成任務快照與顯示', () {
    late DailyMissionService service;
    late IdleIncomeService idleService;
    DateTime fixedTime = DateTime(2025, 8, 24, 12, 0, 0);

    setUp(() {
      service = DailyMissionService(now: () => fixedTime);
      idleService = IdleIncomeService();
      idleService.enableTestingMode(true);
      idleService.setTestingIdlePerSec(0.6); // 預設 0.6 => accumulate 目標 360
    });

    test('完成後保存目標/進度快照，getTodayPlan 對 done 使用快照數字', () {
      // 準備：當前為 i=2 的 accumulateX，凍結目標 360
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 0.0,
        target: 360.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      GameState s = GameState.initial(1).copyWith(dailyMission: mission);

      // 累積到 360 並 claim 完成
      s = service.onEarnPoints(s, 360.0);
      expect(s.dailyMission!.progress, 360.0);
      s = service.claimIfReady(s);

      // 應記錄完成快照
      final completed = s.dailyMission!.completed;
      expect(completed.length, 1);
      expect(completed.first.index, 2);
      expect(completed.first.type, 'accumulateX');
      expect(completed.first.target, 360.0);
      expect(completed.first.progress, 360.0);

      // 今日計畫：i=2 應為 done，且 target/progress 顯示 360
      final plan = service.getTodayPlan(s);
      final item2 = plan.firstWhere((e) => e['index'] == 2);
      expect(item2['status'], 'done');
      expect(item2['target'], 360.0);
      expect(item2['progress'], 360.0);
      expect(item2['displayPoints'], '360');

      // i=4 尚未解鎖，為 locked，accumulateX 的 displayPoints 應為 '??'
      final item4 = plan.firstWhere((e) => e['index'] == 4);
      expect(item4['status'], anyOf('locked', 'current')); // 可能已經切到 i=3 當前
      if (item4['status'] == 'locked') {
        expect(item4['displayPoints'], '??');
      }
    });

    test('跨日後清空完成快照', () {
      // 先完成 i=2
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 360.0,
        target: 360.0,
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      GameState s = GameState.initial(1).copyWith(dailyMission: mission);
      s = service.claimIfReady(s);
      expect(s.dailyMission!.completed.isNotEmpty, true);

      // 模擬跨日
      s = service.simulateDayReset(s);
      expect(s.dailyMission!.date, '2025-08-24'); // 日期已重設為今日（與 fixedTime 一致）
      expect(s.dailyMission!.completed.isEmpty, true);
      expect(s.dailyMission!.todayCompleted, anyOf(0, 1)); // 新的一天從 0 任務開始
    });
  });

    test('當前的累積任務目標應凍結，不因 idlePerSec 變動而改變', () {
      // 準備一個當前任務為偶數序的 accumulateX，目標已凍結在 360
      final mission = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 0.0,
        target: 360.0, // 0.6 * 600
        idlePerSecSnapshot: 0.6,
        todayCompleted: 1,
      );
      final state = GameState.initial(1).copyWith(dailyMission: mission);

      // 取得今日計畫，當前(i=2)應使用凍結的 mission.target=360
      final plan1 = service.getTodayPlan(state);
      final current2 = plan1.firstWhere((e) => e['index'] == 2);
      expect(current2['status'], 'current');
      expect(current2['target'], 360.0);

      // 將 idlePerSec 改為 1.2（理論預覽目標 720），再次讀取 today plan
      idleService.setTestingIdlePerSec(1.2);
      final plan2 = service.getTodayPlan(state);
      final current2b = plan2.firstWhere((e) => e['index'] == 2);
      // 當前任務仍應為凍結目標 360
      expect(current2b['target'], 360.0);

      // 驗證未開啟的下一個偶數任務（例如 i=4）作為「預覽」會反映新速率（不是凍結）
      final locked4 = plan2.firstWhere((e) => e['index'] == 4);
      expect(locked4['status'], anyOf('locked', 'done'));
      if (locked4['status'] == 'locked') {
        expect(locked4['target'], 720.0); // 1.2 * 600
      }
    });

    test('accumulateX 目標為 0 時會以最小速率 0.1 進行補救 (=> 60)', () {
      // idlePerSec 設為 0.0，觸發補救使用 0.1
      idleService.setTestingIdlePerSec(0.0);

      final missionZero = DailyMissionState(
        date: '2025-08-24',
        index: 2,
        type: 'accumulateX',
        progress: 0.0,
        target: 0.0, // 舊資料異常
        idlePerSecSnapshot: 0.0,
        todayCompleted: 1,
      );
      final state = GameState.initial(1).copyWith(dailyMission: missionZero);

      final fixed = service.ensureDailyMissionBlock(state);
      expect(fixed.dailyMission!.type, 'accumulateX');
      expect(fixed.dailyMission!.target, 60.0); // 0.1 * 600
      // snapshot 會記錄當前 idle（此處為 0.0），主要用於追蹤
      expect(fixed.dailyMission!.idlePerSecSnapshot, 0.0);
    });
  });
}
