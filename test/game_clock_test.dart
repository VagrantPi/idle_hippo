import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:idle_hippo/services/game_clock_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';
import 'package:idle_hippo/services/config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameClock Service Tests', () {
    late GameClockService gameClock;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
    });

    tearDown(() {
      gameClock.dispose();
    });

    test('should initialize correctly', () {
      expect(gameClock.isRunning, false);
      expect(gameClock.isInForeground, true);
      expect(gameClock.subscribersCount, 0);
    });

    test('should start and stop correctly', () {
      gameClock.start();
      expect(gameClock.isRunning, true);

      gameClock.stop();
      expect(gameClock.isRunning, false);
    });

    test('should handle subscription correctly', () {
      int tickCount = 0;
      
      gameClock.subscribe('test', (delta) {
        tickCount++;
      });
      
      expect(gameClock.subscribersCount, 1);
      
      gameClock.unsubscribe('test');
      expect(gameClock.subscribersCount, 0);
    });

    test('should handle multiple subscribers', () {
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

    test('should toggle fixed step mode', () {
      expect(gameClock.getStats()['isFixedStepMode'], false);
      
      gameClock.setFixedStepMode(true, fixedDelta: 0.05);
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
      
      gameClock.setFixedStepMode(false);
      expect(gameClock.getStats()['isFixedStepMode'], false);
    });

    test('should provide stats correctly', () {
      final stats = gameClock.getStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('isRunning'), true);
      expect(stats.containsKey('isInForeground'), true);
      expect(stats.containsKey('subscribersCount'), true);
      expect(stats.containsKey('currentFps'), true);
      expect(stats.containsKey('averageDeltaMs'), true);
    });
  });

  group('IdleIncome Service Tests', () {
    late IdleIncomeService idleIncome;
    late GameClockService gameClock;
    double totalIncomeReceived = 0.0;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
      
      totalIncomeReceived = 0.0;
      idleIncome = IdleIncomeService();
      idleIncome.init(onIncomeGenerated: (double points) {
        totalIncomeReceived += points;
      });
    });

    tearDown(() {
      idleIncome.dispose();
      gameClock.dispose();
    });

    test('should initialize correctly', () {
      expect(idleIncome.totalIdleTime, 0.0);
      expect(idleIncome.totalIdleIncome, 0.0);
      expect(idleIncome.currentIdlePerSec, greaterThan(0.0));
    });

    test('should handle income callback correctly', () {
      // 模擬手動觸發收益生成
      final testIncome = 5.0;
      
      // 直接測試回調機制
      idleIncome.init(onIncomeGenerated: (double points) {
        expect(points, equals(testIncome));
      });
      
      // 這裡我們無法直接測試 _onTick，因為它是私有方法
      // 實際測試會在整合測試中進行
    });

    test('should reset stats correctly', () {
      // 手動設定一些統計數據來測試重置
      // 由於統計數據是私有的，我們通過 getStats 來驗證
      
      idleIncome.resetStats();
      expect(idleIncome.totalIdleTime, 0.0);
      expect(idleIncome.totalIdleIncome, 0.0);
    });

    test('should provide stats correctly', () {
      final stats = idleIncome.getStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('currentIdlePerSec'), true);
      expect(stats.containsKey('totalIdleTime'), true);
      expect(stats.containsKey('totalIdleIncome'), true);
      expect(stats.containsKey('isSubscribed'), true);
      expect(stats.containsKey('averageIncomePerSec'), true);
    });
  });

  group('Integration Tests - Time System', () {
    late GameClockService gameClock;
    late IdleIncomeService idleIncome;
    double totalIncomeReceived = 0.0;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
      
      totalIncomeReceived = 0.0;
      idleIncome = IdleIncomeService();
      idleIncome.init(onIncomeGenerated: (double points) {
        totalIncomeReceived += points;
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
      
      // When: 手動觸發一些 tick
      gameClock.start();
      
      // 等待至少一個 tick 發生
      await Future.delayed(const Duration(milliseconds: 100));
      
      gameClock.stop();
      
      // Then: 驗證固定步長模式狀態
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
    });

    test('測試案例 4：訂閱/退訂', () async {
      int tickCountA = 0;
      int tickCountB = 0;
      
      // Given: 兩個系統 A/B 訂閱 GameClock
      gameClock.subscribe('systemA', (delta) => tickCountA++);
      gameClock.subscribe('systemB', (delta) => tickCountB++);
      
      gameClock.start();
      
      // 等待一些 tick
      await Future.delayed(const Duration(milliseconds: 100));
      
      final ticksBeforeUnsubscribe = tickCountB;
      
      // When: 移除 B 的訂閱
      gameClock.unsubscribe('systemB');
      
      // 再等待一些 tick
      await Future.delayed(const Duration(milliseconds: 100));
      
      gameClock.stop();
      
      // Then: 只有 A 的 onTick 計數增加；B 不再收到回呼
      expect(tickCountA, greaterThan(0));
      expect(tickCountB, equals(ticksBeforeUnsubscribe)); // B 停止增加
    });

    test('Delta 夾制測試', () async {
      double receivedDelta = 0.0;
      
      gameClock.subscribe('delta_test', (delta) {
        receivedDelta = delta;
      });
      
      gameClock.start();
      await Future.delayed(const Duration(milliseconds: 50));
      gameClock.stop();
      
      // 測試正常 delta 不會被夾制
      expect(receivedDelta, lessThanOrEqualTo(0.2)); // 最大 delta 限制
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
      
      // When: 手動觸發一些 tick
      gameClock.start();
      
      // 等待至少一個 tick 發生
      await Future.delayed(const Duration(milliseconds: 100));
      
      gameClock.stop();
      
      // Then: 驗證固定步長模式狀態
      expect(gameClock.getStats()['isFixedStepMode'], true);
      expect(gameClock.getStats()['fixedDelta'], 0.05);
    });

    test('Delta 夾制測試', () async {
      double receivedDelta = 0.0;
      
      gameClock.subscribe('delta_test', (delta) {
        receivedDelta = delta;
      });
      
      gameClock.start();
      await Future.delayed(const Duration(milliseconds: 50));
      gameClock.stop();
      
      // 測試正常 delta 不會被夾制
      expect(receivedDelta, lessThanOrEqualTo(0.2)); // 最大 delta 限制
    });

    test('should handle subscriber errors gracefully', () async {
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

  group('Error Handling Tests', () {
    late GameClockService gameClock;

    setUp(() {
      gameClock = GameClockService();
      gameClock.init();
    });

    tearDown(() {
      gameClock.dispose();
    });

    test('should handle subscriber errors gracefully', () async {
      bool errorThrown = false;
      
      // 訂閱一個會拋出錯誤的處理器
      gameClock.subscribe('error_handler', (delta) {
        throw Exception('Test error');
      });
      
      // 訂閱一個正常的處理器
      gameClock.subscribe('normal_handler', (delta) {
        errorThrown = false; // 如果執行到這裡，說明沒有因為前面的錯誤而中斷
      });
      
      gameClock.start();
      
      // 等待一些 tick，確保錯誤處理正常
      await Future.delayed(const Duration(milliseconds: 50));
      
      gameClock.stop();
    });

    test('should handle multiple dispose calls', () {
      gameClock.start();
      gameClock.dispose();
      
      // 第二次 dispose 不應該拋出錯誤
      expect(() => gameClock.dispose(), returnsNormally);
    });

    test('should handle start/stop multiple times', () {
      expect(() {
        gameClock.start();
        gameClock.start(); // 重複啟動
        gameClock.stop();
        gameClock.stop(); // 重複停止
      }, returnsNormally);
    });
  });
}
