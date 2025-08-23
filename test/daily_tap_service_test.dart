import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/daily_tap_service.dart';

void main() {
  group('每日點擊服務（DailyTapService）', () {
    DateTime baseUtc = DateTime.utc(2025, 8, 20, 15, 59, 50); // = 2025-08-21 23:59:50+08
    DateTime now() => baseUtc;

    late DailyTapService svc;
    late GameState state;

    setUp(() {
      svc = DailyTapService(now: now);
      state = GameState.initial(1);
    });

    test('首次 applyTap 應初始化每日區塊並增加收益', () {
      final result = svc.applyTap(state, 1);
      final gained = result.allowedGain.floor();
      expect(gained, 1);
      final stats = svc.getStats(result.state);
      expect(stats['todayGained'], 1);
      expect(stats['effectiveCap'], 200);
    });

    test('上限規則：允許收益應被夾制到剩餘值', () {
      // Set today gained to 199 by applying 199
      var st = state;
      var res = svc.applyTap(st, 199);
      st = res.state;
      expect(res.allowedGain, 199);

      // request 5 -> only 1 allowed to reach 200
      res = svc.applyTap(st, 5);
      expect(res.allowedGain, 1);
      final stats = svc.getStats(res.state);
      expect(stats['todayGained'], 200);
      // further taps blocked
      final res2 = svc.applyTap(res.state, 10);
      expect(res2.allowedGain, 0);
    });

    test('廣告加倍將有效上限提升至 400', () {
      // Reach base cap 200 first
      var st = state;
      var total = 0;
      while (total < 200) {
        final step = svc.applyTap(st, 50);
        total += step.allowedGain.floor();
        st = step.state;
      }
      expect(total, 200);
      // enable ad doubled
      st = svc.setAdDoubled(st, enabled: true);
      final stats1 = svc.getStats(st);
      expect(stats1['adDoubledToday'], true);
      expect(stats1['effectiveCap'], 400);

      // can gain up to 400 in the same day
      var res = svc.applyTap(st, 250);
      expect(res.allowedGain, 200); // 200 remaining from 200->400
      final stats2 = svc.getStats(res.state);
      expect(stats2['todayGained'], 400);

      // beyond 400 is blocked
      final res2 = svc.applyTap(res.state, 10);
      expect(res2.allowedGain, 0);
    });

    test('跨日重置 todayGained（Asia/Taipei）', () {
      // gain 5 before midnight +08
      var res = svc.applyTap(state, 5);
      expect(res.allowedGain, 5);

      // advance baseUtc 20 seconds to cross +08 date boundary
      baseUtc = DateTime.utc(2025, 8, 20, 16, 0, 10); // = 2025-08-22 00:00:10+08

      // ensure block resets on ensureDailyBlock/applyTap
      final s1 = svc.ensureDailyBlock(res.state);
      final stats1 = svc.getStats(s1);
      expect(stats1['todayGained'], 0);

      // first tap today
      final res2 = svc.applyTap(s1, 3);
      expect(res2.allowedGain, 3);
      final stats2 = svc.getStats(res2.state);
      expect(stats2['todayGained'], 3);
    });

    test('負值請求應被夾到 0 並且不改變狀態', () {
      final s0 = svc.ensureDailyBlock(state);
      final res = svc.applyTap(s0, -5);
      expect(res.allowedGain, 0);
      final stats = svc.getStats(res.state);
      expect(stats['todayGained'], 0);
    });

    test('setAdDoubled 設定相同值應具冪等性', () {
      final s0 = svc.ensureDailyBlock(state);
      final s1 = svc.setAdDoubled(s0, enabled: true);
      final s2 = svc.setAdDoubled(s1, enabled: true);
      expect(s1, s2);
    });
  });
}
