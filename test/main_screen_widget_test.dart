import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/ui/components/animated_button.dart';
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('MainScreen 元件測試', () {
    late PageManager pageManager;
    late VoidCallback onCharacterTap;
    late ConfigService configService;
    int tapCount = 0;

    setUp(() {
      pageManager = PageManager();
      configService = ConfigService();
      tapCount = 0;
      onCharacterTap = () {
        tapCount++;
      };
      
      // 初始化服務
      LocalizationService().init(language: 'en');
      pageManager.navigateToPage(PageType.home);
    });

    testWidgets('應以格式化樣式顯示 meme points（例如 12.3K）', (WidgetTester tester) async {
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

    testWidgets('應以格式化樣式顯示 meme points（例如 1.2）', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 1.23,
            onCharacterTap: onCharacterTap,
          ),
        ),
      );

      // 檢查格式化後的 meme points 顯示（目前顯示一位小數）
      expect(find.text('1.2'), findsOneWidget);
    });

    testWidgets('應顯示角色圖片', (WidgetTester tester) async {
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

    testWidgets('應顯示導覽按鈕', (WidgetTester tester) async {
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

    testWidgets('應處理角色點擊事件', (WidgetTester tester) async {
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

    testWidgets('應顯示設定按鈕', (WidgetTester tester) async {
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

    testWidgets('應顯示資源數值（格式化）', (WidgetTester tester) async {
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

    // 預設 currentIdlePerSec 來自 ConfigService 未載入時的 default 0.1
    // 格式化後顯示應為 '0 /s'
    testWidgets('應以格式化顯示每秒離線收益（預設 0.1 → 顯示 0.0 /s）', (WidgetTester tester) async {
      configService.loadConfig();

      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            memePoints: 0.0,
            onCharacterTap: () {},
          ),
        ),
      );

      expect(find.text('0.0 /s'), findsOneWidget);
    });
  });
}
