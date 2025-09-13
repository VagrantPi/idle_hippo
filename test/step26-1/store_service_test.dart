import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:idle_hippo/services/store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('限購商品可購買至達到上限', () async {
    final store = StoreService();
    await store.initialize();

    const key = 'store.card_click_perm';
    expect(store.getCount(key), 0);
    expect(store.canPurchaseLimited(key, 1), true);

    await store.purchase(key);
    expect(store.getCount(key), 1);
    expect(store.canPurchaseLimited(key, 1), false);
  });

  test('限購商品上限為 2 時可購買兩次', () async {
    final store = StoreService();
    await store.initialize();

    const key = 'store.card_offline_perm_6h';
    expect(store.getCount(key), 0);
    expect(store.canPurchaseLimited(key, 2), true);

    await store.purchase(key);
    expect(store.getCount(key), 1);
    expect(store.canPurchaseLimited(key, 2), true);

    await store.purchase(key);
    expect(store.getCount(key), 2);
    expect(store.canPurchaseLimited(key, 2), false);
  });

  test('重置會清空所有購買計數', () async {
    final store = StoreService();
    await store.initialize();
    const key = 'store.card_cap_perm';
    await store.purchase(key);
    expect(store.getCount(key), 1);
    await store.reset();
    expect(store.getCount(key), 0);
  });

  test('可重複購買商品計數會持續累加', () async {
    final store = StoreService();
    await store.initialize();
    const key = 'store.card_idle_2x_1h';
    for (int i = 0; i < 5; i++) {
      await store.purchase(key);
    }
    expect(store.getCount(key), 5);
  });

  test(
    '每日商品當天至上限，隔日重置為 0',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = StoreService();
      await store.initialize();

      const key = 'store.pack_daily';
      // Max 1 per day
      expect(store.getDailyCount(key), 0);
      expect(store.canPurchaseDaily(key, 1), true);
      await store.purchaseDaily(key);
      expect(store.getDailyCount(key), 1);
      expect(store.canPurchaseDaily(key, 1), false);

      // Simulate next day by changing stored date and querying again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store.daily.date', '2000-01-01');
      await prefs.reload(); // ensure cached prefs inside service observe new value
      // Trigger date check
      await store.refreshDailyWindow();
      expect(store.getDailyCount(key), 0);
      expect(store.canPurchaseDaily(key, 1), true);
    },
  );

  test(
    '每月商品當月至上限，跨月重置為 0',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = StoreService();
      await store.initialize();

      const key = 'store.pack_monthly';
      // Max 1 per month
      expect(store.getMonthlyCount(key), 0);
      expect(store.canPurchaseMonthly(key, 1), true);
      await store.purchaseMonthly(key);
      expect(store.getMonthlyCount(key), 1);
      expect(store.canPurchaseMonthly(key, 1), false);

      // Simulate next month by changing stored month
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store.monthly.month', '2000-01');
      await prefs.reload(); // ensure cached prefs inside service observe new value
      // Trigger month check
      await store.refreshMonthlyWindow();
      expect(store.getMonthlyCount(key), 0);
      expect(store.canPurchaseMonthly(key, 1), true);
    },
  );

  String todayTaipei() {
    final utcNow = DateTime.now().toUtc();
    final t = utcNow.add(const Duration(hours: 8));
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  String daysAgoTaipei(int days) {
    final utcNow = DateTime.now().toUtc();
    final t = utcNow
        .add(const Duration(hours: 8))
        .subtract(Duration(days: days));
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  test(
    '前 7 天視窗：僅在前 7 天內可購買且遵守上限',
    () async {
      SharedPreferences.setMockInitialValues({
        'store.install.date': todayTaipei(),
      });
      final store = StoreService();
      await store.initialize();

      const key = 'store.pack_7n_starter';
      expect(store.canPurchaseFirst7(key, 1), true);
      await store.purchaseFirstWindow(key);
      expect(store.canPurchaseFirst7(key, 1), false);
    },
  );

  test('前 7 天視窗：超過第 7 天後不可購買', () async {
    SharedPreferences.setMockInitialValues({
      'store.install.date': daysAgoTaipei(8),
    });
    final store = StoreService();
    await store.initialize();
    const key = 'store.pack_7n_starter';
    expect(store.canPurchaseFirst7(key, 1), false);
  });

  test(
    '前 30 天視窗：僅在前 30 天內可購買且遵守上限',
    () async {
      SharedPreferences.setMockInitialValues({
        'store.install.date': todayTaipei(),
      });
      final store = StoreService();
      await store.initialize();

      const key = 'store.pack_30n_starter';
      expect(store.canPurchaseFirst30(key, 1), true);
      await store.purchaseFirstWindow(key);
      expect(store.canPurchaseFirst30(key, 1), false);
    },
  );

  test('前 30 天視窗：超過第 30 天後不可購買', () async {
    SharedPreferences.setMockInitialValues({
      'store.install.date': daysAgoTaipei(31),
    });
    final store = StoreService();
    await store.initialize();
    const key = 'store.pack_30n_starter';
    expect(store.canPurchaseFirst30(key, 1), false);
  });
}
