import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/purchase_models.dart';
import 'package:idle_hippo/services/mock_rewarded_ad_service.dart';

void main() {
  group('MockRewardedAdService 測試', () {
    late MockRewardedAdService service;

    setUp(() {
      service = MockRewardedAdService();
    });

    test('廣告播放應該在 2 秒後成功', () async {
      final stopwatch = Stopwatch()..start();
      final result = await service.show('store_item', productId: 'test_product');
      stopwatch.stop();

      // 檢查時間約為 2 秒
      expect(stopwatch.elapsedMilliseconds, greaterThan(1900));
      expect(stopwatch.elapsedMilliseconds, lessThan(2100));

      // 檢查結果
      expect(result, equals(RewardedStatus.rewarded));
    });

    test('應該能處理不同的 placement', () async {
      final result1 = await service.show('store_item');
      final result2 = await service.show('daily_reward');
      final result3 = await service.show('level_up');

      expect(result1, equals(RewardedStatus.rewarded));
      expect(result2, equals(RewardedStatus.rewarded));
      expect(result3, equals(RewardedStatus.rewarded));
    });

    test('應該能處理帶 productId 的請求', () async {
      final result = await service.show('store_item', productId: 'pack_daily');
      expect(result, equals(RewardedStatus.rewarded));
    });

    test('應該能處理多個並行廣告請求', () async {
      final futures = [
        service.show('store_item', productId: 'product1'),
        service.show('store_item', productId: 'product2'),
        service.show('store_item', productId: 'product3'),
      ];

      final results = await Future.wait(futures);

      expect(results, hasLength(3));
      expect(results.every((r) => r == RewardedStatus.rewarded), isTrue);
    });
  });
}
