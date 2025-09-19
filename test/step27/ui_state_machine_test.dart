import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/integrated_store_service.dart';
import 'package:idle_hippo/ui/widgets/shop_purchase_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 不再使用 Orchestrator 進行 UI 測試；控件改走 IntegratedStoreService。

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ConfigService().initialize();
    // 設定 SharedPreferences 模擬，避免 MissingPluginException
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final iss = IntegratedStoreService();
    if (!iss.isInitialized) {
      await iss.initialize();
    }
  });

  setUp(() async {
    // 確保每個測試開始前，購買狀態為乾淨（避免前次測試或本機殘留影響）
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final iss = IntegratedStoreService();
    if (!iss.isInitialized) {
      await iss.initialize();
    }
    await iss.resetAllPurchases();
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<void> waitForState(
    WidgetTester tester,
    String state, {
    Duration timeout = const Duration(seconds: 4),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (find.text(state).evaluate().isNotEmpty) return;
      await tester.pump(step);
    }
    // 最後再判斷一次讓測試有明確錯誤訊息
    expect(find.text(state), findsOneWidget);
  }

  Future<void> waitForStateByKey(
    WidgetTester tester,
    String itemKey,
    String expected, {
    Duration timeout = const Duration(seconds: 6),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final key = Key('${itemKey}__state');
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final finder = find.byKey(key);
      if (finder.evaluate().isNotEmpty) {
        final text = tester.widget<Text>(finder);
        if (text.data == expected) return;
      }
      await tester.pump(step);
    }
    final text = tester.widget<Text>(find.byKey(key));
    expect(text.data, expected);
  }

  testWidgets('價格載入完成後狀態為 ready', (tester) async {
    await tester.pumpWidget(wrap(const ShopPurchaseControls(
      itemKey: 'store.card_click_perm',
      limitType: 'limited',
    )));

    // 初始 loadingPrice
    expect(find.text('loadingPrice'), findsOneWidget);

    // 等待預載入完成 → ready（Mock 查價含 500ms 延遲）
    await waitForStateByKey(tester, 'store.card_click_perm', 'ready');
  });

  testWidgets('購買成功：purchasing -> verifying -> owned 並顯示成功提示', (tester) async {
    await tester.pumpWidget(wrap(const ShopPurchaseControls(
      itemKey: 'store.card_click_perm',
      limitType: 'limited',
    )));
    await waitForStateByKey(tester, 'store.card_click_perm', 'ready');

    // 點擊購買
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await waitForStateByKey(tester, 'store.card_click_perm', 'purchasing');

    // 驗證中
    // Mock IAP 購買約需 2s 才返回，再切換 verifying
    await waitForStateByKey(tester, 'store.card_click_perm', 'verifying');

    // 成功 -> owned
    await waitForStateByKey(tester, 'store.card_click_perm', 'owned');
  });
}
