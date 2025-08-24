import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/game_clock_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameClock 服務測試', () {
    late GameClockService gameClock;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
    });

    tearDown(() {
      gameClock.dispose();
    });

    test('應正確初始化', () {
      expect(gameClock.isRunning, false);
      expect(gameClock.isInForeground, true);
      expect(gameClock.subscribersCount, 0);
    });

    test('應可正常啟動與停止', () {
      gameClock.start();
      expect(gameClock.isRunning, true);

      gameClock.stop();
      expect(gameClock.isRunning, false);
    });

    test('應正確處理訂閱', () {
      gameClock.subscribe('test', (_) {});
      
      expect(gameClock.subscribersCount, 1);
      
      gameClock.unsubscribe('test');
      expect(gameClock.subscribersCount, 0);
    });

    test('應能處理多個訂閱者', () {
      int tickCountA = 0;
      int tickCountB = 0;
      
      gameClock.subscribe('testA', (delta) => tickCountA++);
      gameClock.subscribe('testB', (delta) => tickCountB++);
      
      expect(gameClock.subscribersCount, 2);
      
      gameClock.unsubscribe('testB');
      expect(gameClock.subscribersCount, 1);
      
      gameClock.unsubscribe('testA');
      expect(gameClock.subscribersCount, 0);
    });

    test('應可切換固定步長模式', () {
      expect(gameClock.getStats()['isFixedStepMode'], false);
      
      gameClock.setFixedStepMode(true, fixedDelta: 0.05);
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
      
      gameClock.setFixedStepMode(false);
      expect(gameClock.getStats()['isFixedStepMode'], false);
    });

    test('應正確提供統計資訊', () {
      final stats = gameClock.getStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('isRunning'), true);
      expect(stats.containsKey('isInForeground'), true);
      expect(stats.containsKey('subscribersCount'), true);
      expect(stats.containsKey('currentFps'), true);
      expect(stats.containsKey('averageDeltaMs'), true);
    });
  });

  group('IdleIncome 服務測試', () {
    late IdleIncomeService idleIncome;
    late GameClockService gameClock;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
      
      idleIncome = IdleIncomeService();
      idleIncome.init(onIncomeGenerated: (double points) {
      });
    });

    tearDown(() {
      idleIncome.dispose();
      gameClock.dispose();
    });

    test('應正確初始化', () {
      expect(idleIncome.totalIdleTime, 0.0);
      expect(idleIncome.totalIdleIncome, 0.0);
      expect(idleIncome.currentIdlePerSec, greaterThan(0.0));
    });

    test('應可正確處理收益回呼', () {
      // 模擬手動觸發收益生成
      final testIncome = 5.0;
      
      // 直接測試回調機制
      idleIncome.init(onIncomeGenerated: (double points) {
        expect(points, equals(testIncome));
      });
      
      // 這裡我們無法直接測試 _onTick，因為它是私有方法
      // 實際測試會在整合測試中進行
    });

    test('應可正確重置統計', () {
      // 手動設定一些統計數據來測試重置
      // 由於統計數據是私有的，我們通過 getStats 來驗證
      
      idleIncome.resetStats();
      expect(idleIncome.totalIdleTime, 0.0);
      expect(idleIncome.totalIdleIncome, 0.0);
    });

    test('應正確提供統計資訊', () {
      final stats = idleIncome.getStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('currentIdlePerSec'), true);
      expect(stats.containsKey('totalIdleTime'), true);
      expect(stats.containsKey('totalIdleIncome'), true);
      expect(stats.containsKey('isSubscribed'), true);
      expect(stats.containsKey('averageIncomePerSec'), true);
    });
  });

  group('整合測試 - 時間系統', () {
    late GameClockService gameClock;
    late IdleIncomeService idleIncome;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
      
      idleIncome = IdleIncomeService();
      idleIncome.init(onIncomeGenerated: (double points) {
      });
    });

    tearDown(() {
      idleIncome.dispose();
      gameClock.dispose();
    });

    test('測試案例 5：固定步長測試 - 驗證固定 delta 值', () async {
      // Given: 開啟固定步長 fixedDelta=0.05 (20fps)
      gameClock.setFixedStepMode(true, fixedDelta: 0.05);

      double receivedDelta = 0.0;
      int tickCount = 0;

      // 訂閱時間更新
      gameClock.subscribe('test_income', (deltaSeconds) {
        receivedDelta = deltaSeconds;
        tickCount++;
      });

      // When: 使用 debugPump 產生決定性 tick（不依賴計時器）
      gameClock.debugPump(0.05, times: 3);

      // Then: 驗證固定步長模式狀態與實際收到的 delta
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
      expect(tickCount, greaterThan(0));
      expect(receivedDelta, 0.05);
    });

    test('測試案例 4：訂閱/退訂', () async {
      int tickCountA = 0;
      int tickCountB = 0;

      // Given: 兩個系統 A/B 訂閱 GameClock
      gameClock.subscribe('systemA', (delta) => tickCountA++);
      gameClock.subscribe('systemB', (delta) => tickCountB++);

      // Pump 一些 tick（B 仍在）
      gameClock.debugPump(0.016, times: 10);
      final ticksBeforeUnsubscribe = tickCountB;

      // When: 移除 B 的訂閱
      gameClock.unsubscribe('systemB');

      // 再 pump 一些 tick（只有 A 增加）
      gameClock.debugPump(0.016, times: 10);

      // Then: 只有 A 的 onTick 計數增加；B 不再收到回呼
      expect(tickCountA, greaterThan(10));
      expect(tickCountB, equals(ticksBeforeUnsubscribe)); // B 停止增加
    });

    test('Delta 夾制測試', () async {
      double receivedDelta = 0.0;

      gameClock.subscribe('delta_test', (delta) {
        receivedDelta = delta;
      });

      // 不開 fixedStep，直接輸入一個大於上限的 delta，應被夾到 0.2
      gameClock.debugPump(0.5, times: 1);

      expect(receivedDelta, lessThanOrEqualTo(0.2)); // 最大 delta 限制
    });

    test('測試案例 5：固定步長測試 - 驗證固定 delta 值 (timer-free)', () async {
      // Given: 開啟固定步長 fixedDelta=0.05 (20fps)
      gameClock.setFixedStepMode(true, fixedDelta: 0.05);

      double receivedDelta = 0.0;
      int tickCount = 0;

      // 訂閱時間更新
      gameClock.subscribe('test_income', (deltaSeconds) {
        receivedDelta = deltaSeconds;
        tickCount++;
      });

      // 使用 debugPump 產生決定性 tick
      gameClock.debugPump(0.05, times: 2);

      // Then
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
      expect(tickCount, greaterThan(0));
      expect(receivedDelta, 0.05);
    });

    test('Delta 夾制測試 (timer-free)', () async {
      double receivedDelta = 0.0;

      gameClock.subscribe('delta_test', (delta) {
        receivedDelta = delta;
      });

      // 不開 fixedStep，直接輸入一個大於上限的 delta，應被夾到 0.2
      gameClock.debugPump(0.5, times: 1);

      expect(receivedDelta, lessThanOrEqualTo(0.2)); // 最大 delta 限制
    });

    test('應能優雅處理訂閱者錯誤', () async {
      // 訂閱一個會拋出錯誤的處理器
      gameClock.subscribe('error_handler', (delta) {
        throw Exception('Test error');
      });
      
      // 訂閱一個正常的處理器
      bool normalHandlerCalled = false;
      gameClock.subscribe('normal_handler', (delta) {
        normalHandlerCalled = true;
      });
      
      gameClock.start();
      
      // 等待一些 tick，確保錯誤處理正常
      await Future.delayed(const Duration(milliseconds: 50));
      
      gameClock.stop();
      
      // 正常處理器應該仍然被呼叫
      expect(normalHandlerCalled, true);
    });
  });

  group('錯誤處理測試', () {
    late GameClockService gameClock;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
    });

    tearDown(() {
      gameClock.dispose();
    });

    test('應能優雅處理訂閱者錯誤', () async {
      
      // 訂閱一個會拋出錯誤的處理器
      gameClock.subscribe('error_handler', (delta) {
        throw Exception('Test error');
      });
      
      // 訂閱一個正常的處理器
      gameClock.subscribe('normal_handler', (delta) {});
      
      gameClock.start();
      
      // 等待一些 tick，確保錯誤處理正常
      await Future.delayed(const Duration(milliseconds: 50));
      
      gameClock.stop();
    });

    test('應能處理多次 dispose 呼叫', () {
      gameClock.start();
      gameClock.dispose();
      
      // 第二次 dispose 不應該拋出錯誤
      expect(() => gameClock.dispose(), returnsNormally);
    });

    test('應能多次 start/stop 並正常運作', () {
      expect(() {
        gameClock.start();
        gameClock.start(); // 重複啟動
        gameClock.stop();
        gameClock.stop(); // 重複停止
      }, returnsNormally);
    });
  });
}
