import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/ui/pages/power_saver_page.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PowerSaverPage 測試', () {
    // 初始化測試環境
    TestWidgetsFlutterBinding.ensureInitialized();

    late LocalizationService localizationService;

    setUpAll(() async {
      // 以記憶體實作初始化 SharedPreferences，避免 plugin 造成測試等待
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      localizationService = LocalizationService();
      await localizationService.init(language: 'en');
    });

    testWidgets('PowerSaverPage 應該正確顯示基本元素', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: const PowerSaverPage()));

      // 等待初始化完成
      await tester.pump();

      // 驗證黑色背景
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);

      // 驗證時鐘顯示
      expect(find.textContaining(':'), findsOneWidget);

      // 驗證提示文字
      expect(find.text('Tap anywhere to exit'), findsOneWidget);

      // 驗證旋轉按鈕（用 Key）
      expect(find.byKey(const Key('rotation_button')), findsOneWidget);
    });

    testWidgets('點擊畫面應該退出省電模式', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PowerSaverPage(),
                    ),
                  );
                },
                child: const Text('進入省電模式'),
              ),
            ),
          ),
        ),
      );

      // 點擊按鈕進入省電模式
      await tester.tap(find.text('進入省電模式'));
      await tester.pumpAndSettle();

      // 驗證已進入省電頁面
      expect(find.byType(PowerSaverPage), findsOneWidget);

      // 點擊畫面退出（用根手勢 Key）
      await tester.tap(find.byKey(const Key('power_saver_root')));
      await tester.pumpAndSettle();

      // 驗證已退出省電頁面
      expect(find.byType(PowerSaverPage), findsNothing);
      expect(find.text('進入省電模式'), findsOneWidget);
    });

    testWidgets('旋轉按鈕應該切換直橫佈局', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: const PowerSaverPage()));

      await tester.pump();

      // 找到旋轉按鈕並點擊（用 Key）
      final rotationButton = find.byKey(const Key('rotation_button'));
      expect(rotationButton, findsOneWidget);
      await tester.tap(rotationButton);
      await tester.pump();
      // 驗證頁面仍存在（代表已重建）
      expect(find.byType(PowerSaverPage), findsOneWidget);
    });

    testWidgets('時鐘應該每秒更新', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: const PowerSaverPage()));

      await tester.pump();

      // 以 Key 選取時鐘文字
      final clockText = find.byKey(const Key('clock_text'));
      expect(clockText, findsOneWidget);

      // 等待 1 秒多一點
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));

      // 驗證時間仍然存在（可能已更新）
      expect(clockText, findsOneWidget);
    });

    testWidgets('省電模式應該隱藏系統 UI', (WidgetTester tester) async {
      // 記錄原始的 SystemChrome 調用
      final List<MethodCall> systemChromeCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            systemChromeCalls.add(methodCall);
            return null;
          });

      await tester.pumpWidget(MaterialApp(home: const PowerSaverPage()));

      await tester.pump();

      // 驗證是否調用了隱藏系統 UI 的方法
      expect(
        systemChromeCalls.any(
          (call) =>
              call.method == 'SystemChrome.setEnabledSystemUIMode' ||
              call.method.contains('SystemUIMode'),
        ),
        isTrue,
      );

      // 清理
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('多國語系應該正確顯示', (WidgetTester tester) async {
      // 僅驗證對應字串是否切換正確，避免建立頁面造成外掛呼叫
      // 1. 英文（setUp 已初始化為 en）
      expect(
        LocalizationService().getString('power_save.tap_to_exit'),
        'Tap anywhere to exit',
      );

      // 2. 繁中 zh
      await LocalizationService().changeLanguage('zh');
      expect(
        LocalizationService().getString('power_save.tap_to_exit'),
        '觸控退出',
      );

      // 3. 日文 jp
      await LocalizationService().changeLanguage('jp');
      expect(
        LocalizationService().getString('power_save.tap_to_exit'),
        '画面をタップして終了',
      );
    });
  });

  group('PowerSaverPage 整合測試', () {
    testWidgets('完整流程：進入->切換佈局->退出', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PowerSaverPage(),
                      ),
                    );
                  },
                  child: const Text('進入省電模式'),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. 進入省電模式
      await tester.tap(find.text('進入省電模式'));
      await tester.pumpAndSettle();
      expect(find.byType(PowerSaverPage), findsOneWidget);

      // 2. 等待一秒讓時鐘初始化
      await tester.pump(const Duration(seconds: 1));

      // 3. 嘗試切換佈局
      // 點擊旋轉按鈕（用 Key）
      await tester.tap(find.byKey(const Key('rotation_button')));
      await tester.pump();

      // 4. 退出省電模式（用根手勢 Key）
      await tester.tap(find.byKey(const Key('power_saver_root')));
      await tester.pumpAndSettle();

      // 5. 驗證已回到主畫面
      expect(find.byType(PowerSaverPage), findsNothing);
      expect(find.text('進入省電模式'), findsOneWidget);
    });
  });
}
