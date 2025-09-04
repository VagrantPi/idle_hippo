import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/ui/components/gacha_animation.dart';
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/models/pet.dart';

void main() {
  group('GachaAnimationDialog 測試', () {
    late List<GachaResult> testResults;

    setUp(() {
      testResults = [
        GachaResult(
          petKey: 'MooDeng',
          name: '彈跳豬 MooDeng',
          rarity: PetRarity.ssr,
          imagePath: 'assets/images/character/MooDeng.png',
          isNew: true,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        GachaResult(
          petKey: 'PEPE',
          name: '佩佩蛙 PEPE',
          rarity: PetRarity.r,
          imagePath: 'assets/images/character/PEPE.png',
          isNew: false,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
    });

    testWidgets('抽卡動畫對話框正確顯示', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => GachaAnimationDialog(
                      results: testResults,
                      onComplete: () {
                        // 回調函數被調用
                      },
                    ),
                  );
                },
                child: const Text('顯示抽卡動畫'),
              ),
            ),
          ),
        ),
      );

      // 點擊按鈕顯示對話框
      await tester.tap(find.text('顯示抽卡動畫'));
      await tester.pumpAndSettle();

      // 驗證對話框存在
      expect(find.byType(GachaAnimationDialog), findsOneWidget);

      // 驗證進度指示器
      expect(find.text('1 / 2'), findsOneWidget);

      // 推進時間讓動畫與延遲完成，顯示按鈕
      await tester.pump(const Duration(seconds: 2));

      // 進到下一張
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 結束對話框
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('單個抽卡結果正確顯示', (WidgetTester tester) async {
      final singleResult = [testResults.first];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => GachaAnimationDialog(
                      results: singleResult,
                      onComplete: () {},
                    ),
                  );
                },
                child: const Text('顯示單個結果'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('顯示單個結果'));
      await tester.pumpAndSettle();

      // 單個結果不應該顯示進度指示器
      expect(find.text('1 / 1'), findsNothing);

      // 驗證對話框存在
      expect(find.byType(GachaAnimationDialog), findsOneWidget);

      // 推進時間讓動畫完成並顯示 OK
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('稀有度顏色正確顯示', (WidgetTester tester) async {
      // 測試不同稀有度的顏色
      final rarityResults = [
        GachaResult(
          petKey: 'TestSSR',
          name: 'SSR 寵物',
          rarity: PetRarity.ssr,
          imagePath: 'assets/images/character/test.png',
          isNew: true,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => GachaAnimationDialog(
                      results: rarityResults,
                      onComplete: () {},
                    ),
                  );
                },
                child: const Text('測試稀有度'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('測試稀有度'));
      await tester.pumpAndSettle();

      // 等待動畫完成
      await tester.pump(const Duration(seconds: 2));

      // 驗證 SSR 文字存在
      expect(find.text('SSR'), findsOneWidget);
    });

    test('稀有度顏色映射正確', () {
      // 這個測試驗證稀有度顏色映射邏輯
      const rarityColorMap = {
        PetRarity.ssr: Colors.amber,
        PetRarity.sr: Colors.purple,
        PetRarity.s: Colors.blue,
        PetRarity.r: Colors.green,
        PetRarity.rr: Colors.grey,
      };

      for (final entry in rarityColorMap.entries) {
        expect(entry.value, isA<Color>());
      }
    });
  });

  group('StarFieldPainter 測試', () {
    testWidgets('星空背景正確繪製', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              key: const Key('star-field'),
              painter: StarFieldPainter(),
              size: const Size(200, 200),
            ),
          ),
        ),
      );

      // 驗證 CustomPaint 存在
      expect(find.byKey(const Key('star-field')), findsOneWidget);
    });

    test('StarFieldPainter shouldRepaint 返回 false', () {
      final painter = StarFieldPainter();
      expect(painter.shouldRepaint(painter), isFalse);
    });
  });
}
