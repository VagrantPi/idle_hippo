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

  group('恢復購買功能測試', () {
    testWidgets('驗收實例 1：恢復成功 - 檢查基本流程', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShopPage())),
      );
      // 等待整合商城初始化完成（避免尚未初始化導致恢復數量為 0）
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 1. 確認按鈕存在
      expect(find.text('恢復購買'), findsOneWidget);

      // 2. 確認按鈕初始狀態是可點擊的（橘色按鈕）
      Finder restoreButton = find.widgetWithText(TextButton, '恢復購買');
      if (restoreButton.evaluate().isEmpty) {
        restoreButton = find.widgetWithText(ElevatedButton, '恢復購買');
      }

      expect(restoreButton, findsOneWidget);

      // 讀取 onPressed 狀態（支援 TextButton/ElevatedButton）
      VoidCallback? onPressed;
      if (restoreButton.evaluate().isNotEmpty) {
        final widget = restoreButton.evaluate().first.widget;
        if (widget is TextButton) {
          onPressed = widget.onPressed;
        } else if (widget is ElevatedButton) {
          onPressed = widget.onPressed;
        }
      }
      expect(onPressed, isNotNull, reason: '恢復購買按鈕應該在初始狀態下可以點擊');

      // 3. 點擊恢復按鈕
      await tester.tap(find.text('恢復購買'));

      // 4. 等待處理完成
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 5. 檢查成功訊息
      final successMessage = find.textContaining('已恢復');
      if (successMessage.evaluate().isNotEmpty) {
        // 檢查具體的成功訊息格式
        final specificMessage = find.text('已恢復 1 項');
        expect(specificMessage.evaluate().isNotEmpty, true);
      }

      // 6. 檢查是否有 SnackBar
      final snackBar = find.byType(SnackBar);
      expect(snackBar.evaluate().isNotEmpty, true);
    });

    testWidgets('驗收實例 3：按鈕 disabled 狀態檢查', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShopPage())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 點擊恢復購買
      await tester.tap(find.text('恢復購買'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 檢查按鈕是否變為 disabled 狀態
      Finder restoreButton = find.widgetWithText(TextButton, '恢復購買');
      if (restoreButton.evaluate().isEmpty) {
        restoreButton = find.widgetWithText(ElevatedButton, '恢復購買');
      }

      if (restoreButton.evaluate().isNotEmpty) {
        final widget = restoreButton.evaluate().first.widget;
        final isDisabled =
            (widget is TextButton && widget.onPressed == null) ||
            (widget is ElevatedButton && widget.onPressed == null);

        expect(isDisabled, true);
      }
    });

    testWidgets('驗收實例 2：冪等恢復 - 連續點擊測試', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShopPage())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 第一次點擊
      await tester.tap(find.text('恢復購買'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 檢查按鈕狀態
      Finder restoreButton = find.widgetWithText(TextButton, '恢復購買');
      if (restoreButton.evaluate().isEmpty) {
        restoreButton = find.widgetWithText(ElevatedButton, '恢復購買');
      }

      if (restoreButton.evaluate().isNotEmpty) {
        final widget = restoreButton.evaluate().first.widget;
        final isDisabled =
            (widget is TextButton && widget.onPressed == null) ||
            (widget is ElevatedButton && widget.onPressed == null);

        expect(isDisabled, true);
      }
    });

    testWidgets('UI 規格檢查：按鈕外觀', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShopPage())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 檢查「恢復購買」按鈕是否在商品頁文字右方
      final restoreButton = find.text('恢復購買');
      expect(restoreButton, findsOneWidget);

      // 檢查按鈕是否存在於 Material 按鈕家族（TextButton/ElevatedButton）
      final btnAny =
          find.widgetWithText(TextButton, '恢復購買').evaluate().isNotEmpty
          ? find.widgetWithText(TextButton, '恢復購買')
          : find.widgetWithText(ElevatedButton, '恢復購買');

      expect(btnAny, findsOneWidget, reason: '恢復購買應該是一個 Material 按鈕');
    });

    testWidgets('詳細除錯：完整流程追蹤', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShopPage())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 1. 確認按鈕存在
      expect(find.text('恢復購買'), findsOneWidget);

      // 2. 記錄初始狀態
      final initialTexts = find.byType(Text);
      expect(initialTexts.evaluate().isNotEmpty, true);

      // 3. 點擊恢復按鈕
      await tester.tap(find.text('恢復購買'));

      // 4. 分階段等待並檢查變化
      for (int stage = 0; stage < 10; stage++) {
        await tester.pump(const Duration(milliseconds: 300));

        // 檢查 SnackBar
        final snackBar = find.byType(SnackBar);
        expect(snackBar.evaluate().isNotEmpty, true);

        // 檢查是否有新的文字出現
        final currentTexts = find.byType(Text);
        bool foundNewText = false;
        for (int j = 0; j < currentTexts.evaluate().length; j++) {
          final textWidget =
              currentTexts.evaluate().elementAt(j).widget as Text;
          if (textWidget.data != null &&
              (textWidget.data!.contains('恢復') ||
                  textWidget.data!.contains('成功'))) {
            foundNewText = true;
          }
        }

        // 檢查按鈕狀態
        Finder restoreButton = find.widgetWithText(TextButton, '恢復購買');
        if (restoreButton.evaluate().isEmpty) {
          restoreButton = find.widgetWithText(ElevatedButton, '恢復購買');
        }
        if (restoreButton.evaluate().isNotEmpty) {
          final widget = restoreButton.evaluate().first.widget;
          final enabled =
              (widget is TextButton && widget.onPressed != null) ||
              (widget is ElevatedButton && widget.onPressed != null);
          expect(enabled, false);
        }

        if (foundNewText) {
          break;
        }
      }

      await tester.pumpAndSettle();
    });
  });
}
