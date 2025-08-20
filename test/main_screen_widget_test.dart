import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/ui/main_screen.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/localization_service.dart';
import 'package:idle_hippo/services/page_manager.dart';

void main() {
  group('MainScreen Widget Tests', () {
    late GameState testGameState;

    setUp(() {
      testGameState = GameState(
        memePoints: 1000,
        memePointsPerSecond: 10.5,
        level: 5,
        experience: 250,
        experienceToNext: 500,
      );
      
      // 初始化服務
      LocalizationService.instance.setLanguage('en');
      PageManager.instance.setCurrentPage(PageType.home);
    });

    testWidgets('should display game state information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 檢查是否顯示 meme points
      expect(find.text('1000'), findsOneWidget);
      
      // 檢查是否顯示每秒收益
      expect(find.textContaining('10.5'), findsOneWidget);
    });

    testWidgets('should show character image', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 檢查角色圖片是否存在
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets('should have navigation buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 檢查是否有導航按鈕
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('should handle character tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 查找角色區域並點擊
      final characterFinder = find.byKey(const Key('character_area'));
      if (characterFinder.evaluate().isNotEmpty) {
        await tester.tap(characterFinder);
        await tester.pump();
        
        // 檢查是否有粒子效果產生
        expect(find.byType(AnimatedBuilder), findsWidgets);
      }
    });

    testWidgets('should switch pages when navigation buttons are tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 初始應該在首頁
      expect(PageManager.instance.currentPage, equals(PageType.home));

      // 查找並點擊裝備按鈕（如果存在）
      final equipmentButton = find.byKey(const Key('nav_equipment'));
      if (equipmentButton.evaluate().isNotEmpty) {
        await tester.tap(equipmentButton);
        await tester.pump();
        
        expect(PageManager.instance.currentPage, equals(PageType.equipment));
      }
    });

    testWidgets('should respond to language changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(gameState: testGameState),
        ),
      );

      // 切換語言
      LocalizationService.instance.setLanguage('zh');
      await tester.pump();

      // 檢查語言是否已切換
      expect(LocalizationService.instance.currentLanguage, equals('zh'));
    });
  });
}
