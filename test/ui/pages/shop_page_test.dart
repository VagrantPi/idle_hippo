import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/ui/pages/shop_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ConfigService().loadConfig();
    await LocalizationService().init(language: 'zh');
  });

  testWidgets('顯示兩個分頁並可切換', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ShopPage())));

    expect(find.text('常駐資源'), findsOneWidget);
    expect(find.text('限時優惠包'), findsOneWidget);

    // 預設顯示常駐資源的分組標題
    expect(find.text('迷因點數加成卡'), findsWidgets);

    // 切換到限時優惠包
    await tester.tap(find.text('限時優惠包'));
    await tester.pumpAndSettle();

    // 檢查限時優惠包分組標題
    expect(find.text('每日限購禮包'), findsWidgets);
  });

  testWidgets('ads 角標顯示於限時每日包', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ShopPage())));

    // 切換到限時優惠包
    await tester.tap(find.text('限時優惠包'));
    await tester.pumpAndSettle();

    // 角標 🎬 存在
    expect(find.text('🎬'), findsWidgets);
  });
}
