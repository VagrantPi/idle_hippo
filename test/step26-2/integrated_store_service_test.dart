import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/integrated_store_service.dart';
// SecureSaveService 未在整合商城測試中使用，避免引入平台相依介面
import 'package:shared_preferences/shared_preferences.dart';

class MockConfigService extends ConfigService {
  MockConfigService() : super.testable();
  final Map<String, dynamic> _storeConfig = {
    'iap_product': {
      'purchase_limit_type': 'limited',
      'purchase_max_count': 1,
      'ads_pay': false,
    },
    'ad_product': {
      'purchase_limit_type': 'daily',
      'purchase_max_count': 3,
      'ads_pay': true,
    },
    'unlimited_product': {'purchase_limit_type': 'unlimited', 'ads_pay': false},
    'card_click_perm': {
      'purchase_limit_type': 'limited',
      'purchase_max_count': 1,
      'ads_pay': false,
    },
  };

  @override
  Map<String, dynamic> getStoreConfig() => _storeConfig;
}

// 移除 MockSecureSaveService：本測試不需操作 SecureSaveService

void main() {
  group('IntegratedStoreService 測試', () {
    late IntegratedStoreService service;
    late MockConfigService configService;
    // 不需 saveService，整合商城不直接使用它

    setUp(() async {
      // 以記憶體實作初始化 SharedPreferences，避免 plugin 造成測試等待
      SharedPreferences.setMockInitialValues({});
      service = IntegratedStoreService.testable();
      configService = MockConfigService();

      await service.initialize(
        configService: configService,
        useMockServices: true,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('案例 1：limited 一次性', () {
      test('未購買時應該可以購買', () async {
        final availability = await service.getAvailability('iap_product');
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(1));
      });

      test('購買後應該禁用', () async {
        // 購買
        await service.buyProduct('iap_product');

        // 等待購買事件處理完成
        await Future.delayed(const Duration(milliseconds: 2100));

        final availability = await service.getAvailability('iap_product');
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.limited_cap'));
      });
    });

    group('案例 2：daily 限購 + 跨日', () {
      test('當日可以購買多次直到上限', () async {
        // 第一次購買
        var availability = await service.getAvailability('ad_product');
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(3));

        await service.buyProduct('ad_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        // 第二次購買
        availability = await service.getAvailability('ad_product');
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(2));

        await service.buyProduct('ad_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        // 第三次購買
        availability = await service.getAvailability('ad_product');
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(1));

        await service.buyProduct('ad_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        // 第四次應該不能購買
        availability = await service.getAvailability('ad_product');
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.daily_cap'));
      });
    });

    group('案例 3：ads_pay 購買', () {
      test('廣告商品應該通過廣告服務購買', () async {
        // 廣告商品購買
        await service.buyProduct('ad_product');

        // 等待廣告播放完成（2秒）
        await Future.delayed(const Duration(milliseconds: 2100));

        // 檢查購買記錄
        final record = await service.getPurchaseRecord('ad_product');
        expect(record?.daily?.count, equals(1));
      });

      test('IAP 商品應該通過購買服務購買', () async {
        // IAP 商品購買
        await service.buyProduct('iap_product');

        // 等待購買完成（2秒）
        await Future.delayed(const Duration(milliseconds: 2100));

        // 檢查購買記錄
        final record = await service.getPurchaseRecord('iap_product');
        expect(record?.total, equals(1));
      });
    });

    group('案例 4：切換 Service', () {
      test('使用 Mock 服務時購買應該成功', () async {
        await service.initialize(
          configService: configService,
          useMockServices: true,
        );

        await service.buyProduct('iap_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        final record = await service.getPurchaseRecord('iap_product');
        expect(record?.total, equals(1));
      });
    });

    group('案例 5：查詢商品', () {
      test('應該能查詢商品資訊', () async {
        final products = await service.queryProducts([
          'iap_product',
          'ad_product',
        ]);

        expect(products, hasLength(2));
        expect(products[0].id, equals('iap_product'));
        expect(products[0].price, equals(1.99));
        expect(products[0].currency, equals('USD'));
      });
    });

    group('案例 6：恢復購買', () {
      test('應該能恢復購買', () async {
        await service.restorePurchases();

        // 等待恢復完成（1秒）
        await Future.delayed(const Duration(milliseconds: 1100));

        // Mock 服務會恢復 card_click_perm
        final record = await service.getPurchaseRecord('card_click_perm');
        expect(record?.total, equals(1));
      });
    });

    group('案例 7：重啟持久化', () {
      test('重新初始化後購買記錄應該保持', () async {
        // 購買商品
        await service.buyProduct('iap_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        // 檢查記錄
        var record = await service.getPurchaseRecord('iap_product');
        expect(record?.total, equals(1));

        // 重新初始化服務（模擬重啟）
        service.dispose();
        service = IntegratedStoreService.testable();
        await service.initialize(
          configService: configService,
          useMockServices: true,
        );

        // 檢查記錄是否保持
        record = await service.getPurchaseRecord('iap_product');
        expect(record?.total, equals(1));
      });
    });

    group('向後相容性測試', () {
      test('canPurchase 方法應該正常運作', () async {
        var canBuy = await service.canPurchase('iap_product');
        expect(canBuy, isTrue);

        await service.purchase('iap_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        canBuy = await service.canPurchase('iap_product');
        expect(canBuy, isFalse);
      });

      test('getCount 方法應該正常運作', () async {
        var count = await service.getCount('iap_product');
        expect(count, equals(0));

        await service.purchase('iap_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        count = await service.getCount('iap_product');
        expect(count, equals(1));
      });

      test('getDailyCount 方法應該正常運作', () async {
        var count = await service.getDailyCount('ad_product');
        expect(count, equals(0));

        await service.purchase('ad_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        count = await service.getDailyCount('ad_product');
        expect(count, equals(1));
      });
    });

    group('錯誤處理', () {
      test('不存在的商品應該拋出例外', () async {
        expect(() => service.buyProduct('nonexistent'), throwsException);
      });

      test('不存在商品的可用性應該回傳不可購買', () async {
        final availability = await service.getAvailability('nonexistent');
        expect(availability.canBuy, isFalse);
        expect(
          availability.reasonKey,
          equals('store.unavailable.product_not_found'),
        );
      });
    });

    group('重置功能', () {
      test('resetAllPurchases 應該清除所有購買記錄', () async {
        // 購買一些商品
        await service.buyProduct('iap_product');
        await service.buyProduct('ad_product');
        await Future.delayed(const Duration(milliseconds: 2100));

        // 檢查記錄存在
        var record1 = await service.getPurchaseRecord('iap_product');
        var record2 = await service.getPurchaseRecord('ad_product');
        expect(record1?.total, equals(1));
        expect(record2?.daily?.count, equals(1));

        // 重置
        await service.resetAllPurchases();

        // 檢查記錄被清除
        record1 = await service.getPurchaseRecord('iap_product');
        record2 = await service.getPurchaseRecord('ad_product');
        expect(record1?.total, isNull);
        expect(record2?.daily, isNull);
      });
    });
  });
}
