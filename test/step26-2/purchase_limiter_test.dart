import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/purchase_models.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/purchase_limiter.dart';
import 'package:idle_hippo/services/purchase_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 不引入 SecureSaveService，避免平台相依

class MockConfigService extends ConfigService {
  final Map<String, dynamic> _storeConfig;
  MockConfigService(this._storeConfig) : super.testable();

  @override
  Map<String, dynamic> getStoreConfig() => _storeConfig;
}

void main() {
  group('PurchaseLimiter 測試', () {
    late PurchaseLimiterImpl limiter;
    late MockConfigService mockConfig;
    late PurchaseRepository repository;
    // 不需 SaveService

    setUp(() {
      // 以記憶體實作初始化 SharedPreferences，避免 plugin 造成測試等待
      SharedPreferences.setMockInitialValues({});
      final Map<String, dynamic> storeConfig = {
        'unlimited_item': {
          'purchase_limit_type': 'unlimited',
          'purchase_max_count': 999,
        },
        'limited_item': {
          'purchase_limit_type': 'limited',
          'purchase_max_count': 3,
        },
        'daily_item': {'purchase_limit_type': 'daily', 'purchase_max_count': 2},
        'monthly_item': {
          'purchase_limit_type': 'monthly',
          'purchase_max_count': 5,
        },
        'first7_item': {
          'purchase_limit_type': 'first7',
          'purchase_max_count': 1,
        },
        'first30_item': {
          'purchase_limit_type': 'first30',
          'purchase_max_count': 2,
        },
      };
      mockConfig = MockConfigService(storeConfig);
      repository = PurchaseRepository();
      limiter = PurchaseLimiterImpl(mockConfig, repository);
    });

    group('案例 1：limited 一次性', () {
      test('未購買時應該可以購買', () async {
        final testDate = DateTime(2025, 9, 14);
        final availability = await limiter.availability(
          'limited_item',
          testDate,
        );

        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(3));
      });

      test('達到上限後應該禁用', () async {
        final testDate = DateTime(2025, 9, 14);

        // 購買 3 次
        for (int i = 0; i < 3; i++) {
          await limiter.markPurchased('limited_item', testDate);
        }

        final availability = await limiter.availability(
          'limited_item',
          testDate,
        );
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.limited_cap'));
        expect(availability.remaining, equals(0));
      });

      test('部分購買後應該顯示正確剩餘次數', () async {
        final testDate = DateTime(2025, 9, 14);

        // 購買 1 次
        await limiter.markPurchased('limited_item', testDate);

        final availability = await limiter.availability(
          'limited_item',
          testDate,
        );
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(2));
      });
    });

    group('案例 2：daily 限購 + 跨日', () {
      test('當日未購買時應該可以購買', () async {
        final testDate = DateTime(2025, 9, 14);
        final availability = await limiter.availability('daily_item', testDate);

        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(2));
      });

      test('當日達到上限後應該禁用', () async {
        final testDate = DateTime(2025, 9, 14);

        // 購買 2 次
        for (int i = 0; i < 2; i++) {
          await limiter.markPurchased('daily_item', testDate);
        }

        final availability = await limiter.availability('daily_item', testDate);
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.daily_cap'));
        expect(availability.remaining, equals(0));
      });

      test('跨日後應該重新可買', () async {
        final day1 = DateTime(2025, 9, 14);
        final day2 = DateTime(2025, 9, 15);

        // 第一天購買到上限
        for (int i = 0; i < 2; i++) {
          await limiter.markPurchased('daily_item', day1);
        }

        // 第一天應該不能買
        var availability = await limiter.availability('daily_item', day1);
        expect(availability.canBuy, isFalse);

        // 第二天應該可以買
        availability = await limiter.availability('daily_item', day2);
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(2));
      });
    });

    group('案例 3：monthly 限購 + 跨月', () {
      test('當月未購買時應該可以購買', () async {
        final testDate = DateTime(2025, 9, 14);
        final availability = await limiter.availability(
          'monthly_item',
          testDate,
        );

        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(5));
      });

      test('當月達到上限後應該禁用', () async {
        final testDate = DateTime(2025, 9, 14);

        // 購買 5 次
        for (int i = 0; i < 5; i++) {
          await limiter.markPurchased('monthly_item', testDate);
        }

        final availability = await limiter.availability(
          'monthly_item',
          testDate,
        );
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.monthly_cap'));
        expect(availability.remaining, equals(0));
      });

      test('跨月後應該重新可買', () async {
        final month1 = DateTime(2025, 9, 14);
        final month2 = DateTime(2025, 10, 1);

        // 第一個月購買到上限
        for (int i = 0; i < 5; i++) {
          await limiter.markPurchased('monthly_item', month1);
        }

        // 第一個月應該不能買
        var availability = await limiter.availability('monthly_item', month1);
        expect(availability.canBuy, isFalse);

        // 第二個月應該可以買
        availability = await limiter.availability('monthly_item', month2);
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(5));
      });
    });

    group('案例 4：first7 / first30 有效期', () {
      test('新手期內應該可以購買', () async {
        final installDate = DateTime(2025, 8, 1);
        final testDate = DateTime(2025, 8, 5); // 第 5 天

        // 設定安裝記錄（使用 installDate）
        final installDateStr =
            '${installDate.year.toString().padLeft(4, '0')}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}';
        await repository.saveInstallRecord(
          InstallRecord(firstOpenDate: installDateStr),
        );

        final availability = await limiter.availability(
          'first7_item',
          testDate,
        );
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(1));
      });

      test('超過新手期應該禁用', () async {
        final installDate = DateTime(2025, 8, 1);
        final testDate = DateTime(2025, 8, 10); // 第 10 天，超過 7 天

        // 設定安裝記錄（使用 installDate）
        final installDateStr =
            '${installDate.year.toString().padLeft(4, '0')}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}';
        await repository.saveInstallRecord(
          InstallRecord(firstOpenDate: installDateStr),
        );

        final availability = await limiter.availability(
          'first7_item',
          testDate,
        );
        expect(availability.canBuy, isFalse);
        expect(
          availability.reasonKey,
          equals('store.unavailable.first7_expired'),
        );
        expect(availability.remaining, equals(0));
      });

      test('first30 應該在 30 天內可用', () async {
        final installDate = DateTime(2025, 8, 1);
        final testDate = DateTime(2025, 8, 25); // 第 25 天

        // 設定安裝記錄（使用 installDate）
        final installDateStr =
            '${installDate.year.toString().padLeft(4, '0')}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}';
        await repository.saveInstallRecord(
          InstallRecord(firstOpenDate: installDateStr),
        );

        final availability = await limiter.availability(
          'first30_item',
          testDate,
        );
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(2));
      });

      test('first30 超過 30 天應該禁用', () async {
        final installDate = DateTime(2025, 8, 1);
        final testDate = DateTime(2025, 9, 5); // 超過 30 天

        // 設定安裝記錄（使用 installDate）
        final installDateStr =
            '${installDate.year.toString().padLeft(4, '0')}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}';
        await repository.saveInstallRecord(
          InstallRecord(firstOpenDate: installDateStr),
        );

        final availability = await limiter.availability(
          'first30_item',
          testDate,
        );
        expect(availability.canBuy, isFalse);
        expect(
          availability.reasonKey,
          equals('store.unavailable.first30_expired'),
        );
      });

      test('新手期內購買到上限後應該禁用', () async {
        final installDate = DateTime(2025, 8, 1);
        final testDate = DateTime(2025, 8, 3); // 第 3 天

        // 設定安裝記錄（使用 installDate）
        final installDateStr =
            '${installDate.year.toString().padLeft(4, '0')}-${installDate.month.toString().padLeft(2, '0')}-${installDate.day.toString().padLeft(2, '0')}';
        await repository.saveInstallRecord(
          InstallRecord(firstOpenDate: installDateStr),
        );

        // 購買到上限
        await limiter.markPurchased('first7_item', testDate);

        final availability = await limiter.availability(
          'first7_item',
          testDate,
        );
        expect(availability.canBuy, isFalse);
        expect(availability.reasonKey, equals('store.unavailable.limited_cap'));
        expect(availability.remaining, equals(0));
      });
    });

    group('案例 5：unlimited 無限購買', () {
      test('應該永遠可以購買', () async {
        final testDate = DateTime(2025, 9, 14);

        // 購買多次
        for (int i = 0; i < 100; i++) {
          await limiter.markPurchased('unlimited_item', testDate);
        }

        final availability = await limiter.availability(
          'unlimited_item',
          testDate,
        );
        expect(availability.canBuy, isTrue);
        expect(availability.remaining, equals(-1)); // -1 表示無上限
      });
    });

    group('錯誤處理', () {
      test('不存在的商品應該回傳不可購買', () async {
        final testDate = DateTime(2025, 9, 14);
        final availability = await limiter.availability(
          'nonexistent',
          testDate,
        );

        expect(availability.canBuy, isFalse);
        expect(
          availability.reasonKey,
          equals('store.unavailable.product_not_found'),
        );
      });

      test('未知的限購類型應該預設為 limited', () async {
        // 將未知類型的商品加入現有 config（limiter 使用的同一份）
        mockConfig.getStoreConfig()['unknown_type'] = {
          'purchase_limit_type': 'unknown',
          'purchase_max_count': 1,
        };

        final testDate = DateTime(2025, 9, 14);

        // 第一次應該可以買
        var availability = await limiter.availability('unknown_type', testDate);
        expect(availability.canBuy, isTrue);

        // 購買後應該不能買（因為預設為 limited）
        await limiter.markPurchased('unknown_type', testDate);
        availability = await limiter.availability('unknown_type', testDate);
        expect(availability.canBuy, isFalse);
      });
    });

    group('ensureRollovers 測試', () {
      test('應該正確觸發跨日和跨月重置', () async {
        final oldDate = DateTime(2025, 8, 31);
        final newDate = DateTime(2025, 9, 1);

        // 在舊日期購買
        await limiter.markPurchased('daily_item', oldDate);
        await limiter.markPurchased('monthly_item', oldDate);

        // 檢查舊日期的記錄
        var dailyRecord = await repository.getPurchaseRecord('daily_item');
        var monthlyRecord = await repository.getPurchaseRecord('monthly_item');
        expect(dailyRecord?.daily?.date, equals('2025-08-31'));
        expect(monthlyRecord?.monthly?.ym, equals('2025-08'));

        // 觸發重置
        await limiter.ensureRollovers(newDate);

        // 檢查記錄是否被重置
        dailyRecord = await repository.getPurchaseRecord('daily_item');
        monthlyRecord = await repository.getPurchaseRecord('monthly_item');
        expect(dailyRecord?.daily?.date, equals('2025-09-01'));
        expect(dailyRecord?.daily?.count, equals(0));
        expect(monthlyRecord?.monthly?.ym, equals('2025-09'));
        expect(monthlyRecord?.monthly?.count, equals(0));
      });
    });
  });
}
