import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/services/rewarded_ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RewardedAdService', () {
    late RewardedAdService rewardedAdService;
    late GameStateService gameStateService; // 使用真實實例管理 state

    setUpAll(() {
      tzdata.initializeTimeZones();
    });

    setUp(() async {
      gameStateService = GameStateService();
      await gameStateService.initializeForTest(GameState.initial(1));
      rewardedAdService = RewardedAdService();
      await rewardedAdService.initializeForTest(gameStateService);
    });

    test('初始化後，剩餘次數應為每日上限', () async {
      final remaining = await rewardedAdService.getRemainingGachaTenPackAd();
      expect(remaining, 1);
    });

    test('canShowGachaTenPackAd 在有剩餘次數時應返回 true', () async {
      final canShow = await rewardedAdService.canShowGachaTenPackAd();
      expect(canShow, isTrue);
    });

    test('消耗一次抽卡機會後，剩餘次數應減少', () async {
      final success = await rewardedAdService.consumeGachaTenPackAd();
      expect(success, isTrue);

      final remaining = await rewardedAdService.getRemainingGachaTenPackAd();
      expect(remaining, 0);
    });

    test('沒有剩餘次數時，canShowGachaTenPackAd 應返回 false', () async {
      await rewardedAdService.consumeGachaTenPackAd();

      final canShow = await rewardedAdService.canShowGachaTenPackAd();
      expect(canShow, isFalse);
    });

    test('沒有剩餘次數時，consumeGachaTenPackAd 應返回 false', () async {
      await rewardedAdService.consumeGachaTenPackAd();

      final success = await rewardedAdService.consumeGachaTenPackAd();
      expect(success, isFalse);
    });

    test('跨日時，每日狀態應重置', () async {
      // 先消耗當前次數
      await rewardedAdService.consumeGachaTenPackAd();
      var remaining = await rewardedAdService.getRemainingGachaTenPackAd();
      expect(remaining, 0);

      // 模擬跨日：將 gacha.lastDate 設為昨天
      final location = tz.getLocation('Asia/Taipei');
      final now = tz.TZDateTime.now(location);
      final yesterday = now.subtract(const Duration(days: 1));
      final ymd = DateFormat('yyyy-MM-dd').format(yesterday);

      final currentState = gameStateService.gameState.value;
      final forcedYesterday = (currentState.gacha ?? GachaState.initial()).copyWith(
        lastDate: ymd,
        tenPackAdRemaining: 0,
      );
      await gameStateService.updateGameState(currentState.copyWith(gacha: forcedYesterday));

      // 觸發服務的日重置檢查
      remaining = await rewardedAdService.getRemainingGachaTenPackAd();
      expect(remaining, 1);
    });

    test('剩餘次數變化時，Stream 應發出新值', () async {
      // 初始值 1，消耗後 0
      expect(rewardedAdService.remainingGachaTenPackAdStream, emitsInOrder([1, 0]));
      await rewardedAdService.consumeGachaTenPackAd();
    });
  });
}
