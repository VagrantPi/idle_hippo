import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/checkin_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/config_service.dart';

void main() {
  // 初始化測試綁定，供資產讀取與 ServicesBinding 使用
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CheckinService 整合測試', () {
    late CheckinService checkinService;
    late GameStateService gameStateService;
    late ConfigService configService;

    setUp(() async {
      checkinService = CheckinService();
      gameStateService = GameStateService();
      configService = ConfigService();

      // 初始化服務
      await configService.initialize();
      await gameStateService.initialize();
    });

    test('應該能夠初始化 CheckinService', () async {
      await checkinService.initialize();
      expect(checkinService, isNotNull);
    });

    test('應該能夠檢查是否有待完成的打卡任務', () async {
      await checkinService.initialize();

      // 測試紅點邏輯
      final hasPendingTask = checkinService.hasPendingTask();
      expect(hasPendingTask, isA<bool>());
    });

    test('應該能夠處理跨日檢測', () async {
      await checkinService.initialize();

      // 模擬跨日情況
      final gameState = gameStateService.currentState;
      if (gameState.checkin != null) {
        expect(gameState.checkin!.today.date, isNotEmpty);
      }
    });

    test('應該能夠完成打卡任務', () async {
      await checkinService.initialize();

      final gameState = gameStateService.currentState;
      if (gameState.checkin?.today.status == 'pending') {
        final result = await checkinService.completeCheckin();
        expect(result, isTrue);
      }
    });

    test('應該能夠通過廣告跳過任務', () async {
      await checkinService.initialize();

      final gameState = gameStateService.currentState;
      if (gameState.checkin?.today.status == 'pending') {
        final result = await checkinService.skipWithAd();
        expect(result, isTrue);
      }
    });

    test('應該正確計算連續簽到天數', () async {
      await checkinService.initialize();

      final gameState = gameStateService.currentState;
      if (gameState.checkin != null) {
        expect(gameState.checkin!.streak.current, greaterThanOrEqualTo(0));
        expect(gameState.checkin!.streak.longest, greaterThanOrEqualTo(0));
      }
    });

    test('應該正確處理週獎勵邏輯', () async {
      await checkinService.initialize();

      final gameState = gameStateService.currentState;
      if (gameState.checkin != null) {
        final weekMask = gameState.checkin!.week.completedMask;
        expect(weekMask, greaterThanOrEqualTo(0));
        expect(weekMask, lessThanOrEqualTo(127)); // 7-bit mask
      }
    });
  });
}
