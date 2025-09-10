import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_hippo/services/tutorial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('新手教學 TutorialService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final svc = TutorialService();
      await svc.initialize();
      await svc.reset();
    });

    test('初始狀態 step=0, 未完成', () async {
      final svc = TutorialService();
      await svc.initialize();
      expect(svc.state.value.step, 0);
      expect(svc.state.value.completed, false);
    });

    test('漫畫分鏡翻頁與進入第二步', () async {
      final svc = TutorialService();
      await svc.initialize();

      // 第一次進入: 自動到 step=1, mangaPage=1
      expect(await svc.advanceManga(), true);
      expect(svc.state.value.step, 1);
      expect(svc.state.value.mangaPage, 1);

      // 依序翻頁到4
      expect(await svc.advanceManga(), true);
      expect(svc.state.value.mangaPage, 2);
      expect(await svc.advanceManga(), true);
      expect(svc.state.value.mangaPage, 3);
      expect(await svc.advanceManga(), true);
      expect(svc.state.value.mangaPage, 4);

      // 完成本回合後再點一次切到 step=2
      expect(await svc.finishMangaIfReady(), true);
      expect(svc.state.value.step, 2);
    });

    test('完整流程：可從 2 逐步完成至 13 並標記完成', () async {
      final svc = TutorialService();
      await svc.initialize();
      await svc.setStep(2);

      // Step 2：需要累積到 10 點
      await svc.recordAction('hippo'); // 接受但不前進
      await svc.checkMemePoints(10);
      expect(svc.state.value.step, 3);

      // Step 3：主線入口
      expect(await svc.recordAction('btn_mainline'), true);
      expect(svc.state.value.step, 4);

      // Step 4：等待後 Next
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 5);

      // Step 5：領取主線
      expect(await svc.recordAction('btn_mainline_claim'), true);
      expect(svc.state.value.step, 6);

      // Step 6：升級 YouTube
      expect(await svc.recordAction('btn_upgrade_youtube'), true);
      expect(svc.state.value.step, 7);

      // Step 7：返回首頁
      expect(await svc.recordAction('nav_home'), true);
      expect(svc.state.value.step, 8);

      // Step 8：等待後 Next
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 9);

      // Step 9：等待後 Next
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 10);

      // Step 10：設定入口（停留主畫面等待點擊設定）
      expect(await svc.recordAction('btn_settings'), true);
      expect(svc.state.value.step, 11);

      // Step 11：等待後 Next
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 12);

      // Step 12：返回首頁
      expect(await svc.recordAction('nav_home'), true);
      expect(svc.state.value.step, 13);

      // Step 13：等待後 Next → 完成
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.completed, true);
    });

    test('中途退出：到 step=6，重啟後從6繼續', () async {
      final svc1 = TutorialService();
      await svc1.initialize();
      await svc1.setStep(6);

      // 重建服務（模擬 app 重啟）
      final svc2 = TutorialService();
      await svc2.initialize();
      expect(svc2.state.value.step, 6);
      expect(svc2.state.value.completed, false);
    });

    test('重置存檔後從 0 開始', () async {
      final svc = TutorialService();
      await svc.initialize();
      await svc.setStep(13);
      await svc.complete();
      expect(svc.state.value.completed, true);

      await svc.reset();
      expect(svc.state.value.step, 0);
      expect(svc.state.value.completed, false);
    });

    test('Focus 正確性：在步驟 9 僅允許按下 Next', () async {
      final svc = TutorialService();
      await svc.initialize();
      await svc.setStep(9);
      expect(svc.isAllowedTarget('btn_next'), true);
      expect(svc.isAllowedTarget('hippo'), false);
      expect(svc.isAllowedTarget('btn_settings'), false);
    });
  });
}
