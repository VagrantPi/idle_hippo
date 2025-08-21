import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/ui/components/animated_button.dart';
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('MainScreen Widget Tests', () {
    late PageManager pageManager;
    late VoidCallback onCharacterTap;
    int tapCount = 0;

    setUp(() {
      pageManager = PageManager();
      tapCount = 0;
      onCharacterTap = () {
        tapCount++;
      };
      
      // 初始化服務
      LocalizationService().init(language: 'en');
      pageManager.navigateToPage(PageType.home);
    });

    testWidgets('should display meme points in formatted style (e.g., 12.3K)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 12345.0,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 檢查格式化後的 meme points 顯示
      expect(find.text('12.3K'), findsOneWidget);
    });

    testWidgets('should display meme points in formatted style (e.g., 1.23)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1.23,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 檢查格式化後的 meme points 顯示
      expect(find.text('1.23'), findsOneWidget);
    });

    testWidgets('should show character image', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1000.0,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 檢查角色圖片是否存在
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('should have navigation buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1000.0,
            onCharacterTap: onCharacterTap,
            equipments: {},
            onEquipmentUpgrade: (equipmentId) {},
          ),
        ),
      );

      // 檢查是否有導航按鈕
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('should handle character tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1000,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 查找角色區域並點擊
      final characterFinder = find.byType(GestureDetector).first;
      await tester.tap(characterFinder);
      await tester.pump();
      
      // 檢查點擊處理函數是否被調用
      expect(tapCount, 1);
    });

    testWidgets('should show settings button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1000,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 找到所有 AnimatedButton 組件
      final animatedButtons = find.byType(AnimatedButton);
      
      // 找出設置按鈕（圖標路徑包含 'Setting' 或 'setting' 的按鈕）
      final settingsButton = find.byWidgetPredicate(
        (widget) => widget is AnimatedButton && 
                   (widget.iconPath.toLowerCase().contains('setting') || 
                    widget.iconPath.contains('設定')), // 支援英文和中文路徑
      );
      
      // 驗證設置按鈕是否存在
      expect(settingsButton, findsOneWidget, reason: 'Settings button not found');
      
      // 獲取按鈕實例並驗證點擊事件
      final button = tester.widget<AnimatedButton>(settingsButton);
      expect(button.onTap, isNotNull, reason: 'Settings button onTap is null');
    });

    testWidgets('should show resource display', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 12345,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 檢查資源顯示區域的數字已格式化
      expect(find.text('12.3K'), findsOneWidget);
    });

    testWidgets('should display idle income per second formatted (default 0.1 -> 0 /s)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 0.0,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 預設 currentIdlePerSec 來自 ConfigService 未載入時的 default 0.1
      // 格式化後顯示應為 '0 /s'
      expect(find.textContaining('0 /s'), findsOneWidget);
    });
  });
}
