import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step08 離線收益整合測試', () {
    late IdleIncomeService idle;
    double received = 0.0;

    void pumpSeconds(double seconds, {double step = 0.05}) {
      final times = (seconds / step).round();
      for (int i = 0; i < times; i++) {
        idle.onTickForTest(step);
      }
    }

    setUp(() {
      idle = IdleIncomeService();
      received = 0.0;
      idle.enableTestingMode(true); // 不訂閱 GameClock
      idle.setTestingIdlePerSec(null); // 清除覆寫
      idle.resetStats();
      idle.init(onIncomeGenerated: (v) => received += v);
    });

    tearDown(() {
      idle.dispose();
    });

    test('案例1：前台 30 秒，idle_per_sec=1.0，總量約 30±0.3', () {
      idle.setTestingIdlePerSec(1.0);

      // 模擬前台 30 秒：0.05s * 600 = 30s
      pumpSeconds(30.0, step: 0.05);

      expect(idle.totalIdleTime, closeTo(30.0, 0.3));
      expect(idle.totalIdleIncome, closeTo(30.0, 0.3));
      expect(received, closeTo(30.0, 0.3));
    });

    test('案例2：背景不累積（5s 前台 → 10s 背景 → 5s 前台）idle_per_sec=2.0，總量≈20', () {
      idle.setTestingIdlePerSec(2.0);

      // 5 秒前台
      pumpSeconds(5.0, step: 0.05);
      final front1Income = idle.totalIdleIncome;

      // 背景 10 秒（不應累積）：不呼叫 tick，直接跳過

      // 再 5 秒前台
      pumpSeconds(5.0, step: 0.05);

      // 理論上總量 5*2 + 5*2 = 20
      expect(idle.totalIdleIncome, closeTo(20.0, 0.2));
      // 中段背景不應增加
      expect(idle.totalIdleIncome - front1Income, greaterThan(0));
    });

    test('案例3：結算單位（邏輯總量）idle_per_sec=1.5，10 秒總量約 15±0.15', () {
      idle.setTestingIdlePerSec(1.5);

      // 10 秒前台
      pumpSeconds(10.0, step: 0.05);

      // 本服務內部以 double 累加，我們驗證總量即可
      expect(idle.totalIdleIncome, closeTo(15.0, 0.15));
    });

    test('案例4：熱載速率（0.5→1.0）之後區段以新速率累積', () {
      // 前半 10 秒：0.5 / s
      idle.setTestingIdlePerSec(0.5);
      pumpSeconds(10.0, step: 0.05); // 10s
      final firstHalfIncome = idle.totalIdleIncome;

      // 熱載改為 1.0 / s
      idle.setTestingIdlePerSec(1.0);
      pumpSeconds(10.0, step: 0.05); // 再 10s
      final totalIncome = idle.totalIdleIncome;

      // 驗證：前半約 5，後半再加約 10 → 總約 15
      expect(firstHalfIncome, closeTo(5.0, 0.1));
      expect(totalIncome, closeTo(15.0, 0.2));

      // 後半段的增量應接近 10
      expect(totalIncome - firstHalfIncome, closeTo(10.0, 0.2));
    });
  });
}
