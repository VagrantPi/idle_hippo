import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/checkin_service.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step21 規格測試：每日打卡系統', () {
    late CheckinService checkin;
    late GameStateService gs;
    late ConfigService cfg;
    late IdleIncomeService idle;

    setUp(() async {
      checkin = CheckinService();
      gs = GameStateService();
      cfg = ConfigService();
      idle = IdleIncomeService();
      await cfg.initialize();
      await gs.initialize();
      // 清理 idle 覆寫
      idle.setTestingIdlePerSec(null);
      // 觸發初始化，確保有 today 任務
      await checkin.initialize();
    });

    String today() {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    String weekStartOf(String dateStr, int weekStartDow) {
      final parts = dateStr.split('-').map((e) => int.parse(e)).toList();
      final date = DateTime(parts[0], parts[1], parts[2]);
      final dayOfWeek = date.weekday; // Monday=1..Sunday=7
      final daysToSubtract = (dayOfWeek - weekStartDow + 7) % 7;
      final weekStart = date.subtract(Duration(days: daysToSubtract));
      return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    }

    Future<void> forceNewDay({int maxTries = 10}) async {
      // 將 today.date 改為過去，呼叫 checkDayChange 以觸發新任務生成
      for (int i = 0; i < maxTries; i++) {
        final state = gs.currentState;
        final ck = state.checkin;
        final past = DateTime.now().toUtc().add(const Duration(hours: 8)).subtract(const Duration(days: 1));
        final pastStr = '${past.year.toString().padLeft(4, '0')}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
        if (ck == null) {
          await checkin.checkDayChange();
        } else {
          final patched = ck.copyWith(
            today: ck.today.copyWith(date: pastStr, status: 'pending', task: ck.today.task.copyWith(progress: 0)),
          );
          await gs.updateGameState(state.copyWith(checkin: patched));
          await checkin.checkDayChange();
        }
        // 產生了新的一天就返回
        if (gs.currentState.checkin?.today.date == today()) return;
      }
    }

    Future<void> ensureTaskType(String type, {int maxTries = 15}) async {
      for (int i = 0; i < maxTries; i++) {
        if (gs.currentState.checkin?.today.task.type == type) return;
        await forceNewDay();
      }
      fail('在 $maxTries 次嘗試後仍無法生成 $type 任務，可能為隨機機率不幸。');
    }

    test('案例 1：當日任務生成（tap）', () async {
      await ensureTaskType('tap');
      final ck = checkin.getCurrentCheckinState()!;
      final target = ck.today.task.target;
      final tapRange = ck.config.tapRange;
      expect(ck.today.task.type, 'tap', reason: '應為 tap 任務');
      expect(target >= tapRange.first && target <= tapRange.last, isTrue, reason: '目標需落於設定範圍');
      expect(checkin.shouldShowRedDot(), isTrue, reason: '未完成前應顯示紅點');
      final bitIndex = DateTime.parse(today()).difference(DateTime.parse(ck.week.weekStart)).inDays;
      final mask = ck.week.mask;
      expect((mask & (1 << bitIndex)) != 0, isFalse, reason: '未完成前週曆當天格不應亮');
    });

    test('案例 2：當日任務生成（collect）', () async {
      idle.setTestingIdlePerSec(2.0);
      await ensureTaskType('collect');
      final ck = checkin.getCurrentCheckinState()!;
      expect(ck.today.task.type, 'collect');
      expect(ck.today.idlePerSecSnapshot, 2.0);
      final expectedTarget = (2.0 * 8 * 3600).floor();
      expect(ck.today.task.target, expectedTarget);
    });

    test('案例 3：完成簽到（正常達標）', () async {
      await ensureTaskType('tap');
      var ck = checkin.getCurrentCheckinState()!;
      final target = ck.today.task.target;
      // 將進度補到目標
      for (int i = ck.today.task.progress; i < target; i++) {
        await checkin.updateTapProgress();
      }
      expect(checkin.canCompleteToday(), isTrue);
      await checkin.completeToday();
      ck = checkin.getCurrentCheckinState()!;
      expect(ck.today.status, 'done');
      final bitIndex = DateTime.parse(today()).difference(DateTime.parse(ck.week.weekStart)).inDays;
      expect((ck.week.mask & (1 << bitIndex)) != 0, isTrue, reason: '完成後當天 bit 應設位');
      expect(checkin.shouldShowRedDot(), isFalse, reason: '簽到後紅點應消失');
    });

    test('案例 4：廣告跳過簽到', () async {
      await forceNewDay();
      await ensureTaskType('collect');
      var ck = checkin.getCurrentCheckinState()!;
      expect(checkin.canSkipViaAd(), isTrue);
      // 使用向後相容 API 以便不依賴 UI 模擬 3s
      final ok = await checkin.skipWithAd();
      expect(ok, isTrue);
      ck = checkin.getCurrentCheckinState()!;
      expect(ck.today.status, 'skipped');
      expect(ck.today.skipViaAdUsed, isTrue);
      final bitIndex = DateTime.parse(today()).difference(DateTime.parse(ck.week.weekStart)).inDays;
      expect((ck.week.mask & (1 << bitIndex)) != 0, isTrue);
      expect(checkin.shouldShowRedDot(), isFalse);
    });

    test('案例 5：跨日與跨週輪轉', () async {
      // 設置 weekStart 為過去一週，強迫跨週
      var s = gs.currentState;
      final ck = s.checkin!;
      final weekStartDow = ck.config.weekStartDow;
      final oldWeekStart = DateTime.parse(weekStartOf(today(), weekStartDow)).subtract(const Duration(days: 7));
      final patchedWeek = ck.week.copyWith(
        weekStart: '${oldWeekStart.year.toString().padLeft(4, '0')}-${oldWeekStart.month.toString().padLeft(2, '0')}-${oldWeekStart.day.toString().padLeft(2, '0')}',
        mask: 127,
      );
      await gs.updateGameState(s.copyWith(checkin: ck.copyWith(week: patchedWeek)));
      await forceNewDay();
      final after = checkin.getCurrentCheckinState()!;
      final expectedWeekStart = weekStartOf(today(), weekStartDow);
      expect(after.week.weekStart, expectedWeekStart);
      expect(after.week.mask, 0, reason: '跨週後 mask 應重置');
      expect(after.today.date, today(), reason: '生成新任務');
    });

    test('案例 6：連續與最佳', () async {
      await forceNewDay();
      // 將 streak 設置為昨天已簽到，current=3
      var s = gs.currentState;
      var ck = s.checkin!;
      final yesterday = DateTime.now().toUtc().add(const Duration(hours: 8)).subtract(const Duration(days: 1));
      final yStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final patchedStreak = ck.streak.copyWith(current: 3, total: ck.streak.total, best: ck.streak.best, lastDate: yStr);
      await gs.updateGameState(s.copyWith(checkin: ck.copyWith(streak: patchedStreak)));

      // 補足今日進度並完成
      await checkin.completeCheckin();
      ck = checkin.getCurrentCheckinState()!;
      expect(ck.streak.current, 4);
      expect(ck.streak.best >= 4, isTrue);
      expect(ck.streak.lastDate, today());
    });

    test('案例 7：週獎勵（策略 A）', () async {
      await forceNewDay();
      idle.setTestingIdlePerSec(2.0);
      var s = gs.currentState;
      var ck = s.checkin!;
      // 設 streak.total=6，完成後應成為 7 並觸發半日獎勵
      final patchedStreak = ck.streak.copyWith(current: ck.streak.current, best: ck.streak.best, total: 6, lastDate: ck.streak.lastDate);
      await gs.updateGameState(s.copyWith(checkin: ck.copyWith(streak: patchedStreak)));

      final beforePoints = gs.currentState.memePoints;
      final expectedReward = 2.0 * 12 * 3600; // 半日放置
      final ok = await checkin.completeCheckin();
      expect(ok, isTrue);
      final afterPoints = gs.currentState.memePoints;
      expect((afterPoints - beforePoints).round(), expectedReward.round());
    });

    test('案例 8：持久化與紅點', () async {
      await forceNewDay();
      final ck1 = checkin.getCurrentCheckinState()!;
      expect(ck1.today.status, 'pending');
      expect(checkin.shouldShowRedDot(), isTrue);
      // 模擬「重啟」：再次 initialize（單例會保留狀態）
      await checkin.initialize();
      final ck2 = checkin.getCurrentCheckinState()!;
      expect(ck2.today.status, 'pending');
      expect(checkin.shouldShowRedDot(), isTrue);
    });
  });
}
