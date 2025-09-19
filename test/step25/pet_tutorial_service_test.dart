import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/gacha_service.dart';
import 'package:idle_hippo/services/pet_tutorial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step25-2 寵物系統引導', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // 確保 gacha 初始化乾淨
      final gacha = GachaService();
      await gacha.initialize();
      // 重置票券為 0
      final initial = gacha.getPetTickets();
      if (initial != 0) {
        // 用相對方式歸零
        await gacha.addPetTickets(-initial);
      }
      // 重置 service
      final petTut = PetTutorialService();
      await petTut.initialize();
      await petTut.reset();
    });

    test('自動觸發：完成第三章後進入 step=1', () async {
      final svc = PetTutorialService();
      await svc.initialize();

      final gs = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(
          currentStage: 4,
          unlockedRewards: ['system.pet'],
        ),
      );
      final triggered = await svc.maybeStartFromGameState(gs);
      expect(triggered, true);
      expect(svc.state.value.step, 1);
      expect(svc.state.value.completed, false);
    });

    test('完整流程：走完 4 步並發放 10 張票券', () async {
      final svc = PetTutorialService();
      await svc.initialize();

      // 模擬主線第三章完成後自動觸發
      final gs = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(
          currentStage: 4,
          unlockedRewards: ['system.pet'],
        ),
      );
      await svc.maybeStartFromGameState(gs);
      expect(svc.state.value.step, 1);

      // Step 1: 等待後點 Next
      expect(svc.isAllowedTarget('btn_next'), true);
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 2);

      // Step 2: 返回首頁 (nav_home)
      expect(svc.isAllowedTarget('nav_home'), true);
      expect(await svc.recordAction('nav_home'), true);
      expect(svc.state.value.step, 3);

      // Step 3: 等待後點 Next
      expect(svc.isAllowedTarget('btn_next'), true);
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.step, 4);

      // Step 4: 點 Next 完成並發放獎勵
      final gacha = GachaService();
      final before = gacha.getPetTickets();
      expect(await svc.recordAction('btn_next'), true);
      expect(svc.state.value.completed, true);
      expect(gacha.getPetTickets(), before + 10);
    });

    test('中途退出：到 step=2，重啟後從 2 繼續', () async {
      final svc1 = PetTutorialService();
      await svc1.initialize();

      // 進入 step=1 後前進到 step=2
      await svc1.setStep(1);
      await svc1.recordAction('btn_next'); // -> step 2
      expect(svc1.state.value.step, 2);

      // 模擬 app 重啟，建立新服務實例
      final svc2 = PetTutorialService();
      await svc2.initialize();
      expect(svc2.state.value.step, 2);
      expect(svc2.state.value.completed, false);
    });

    test('重置存檔：完成後 reset 回到 step=0 並可重觸發', () async {
      final svc = PetTutorialService();
      await svc.initialize();
      await svc.setStep(4);
      await svc.recordAction('btn_next'); // 完成
      expect(svc.state.value.completed, true);

      await svc.reset();
      expect(svc.state.value.step, 0);
      expect(svc.state.value.completed, false);
      expect(svc.rewardGiven, false);
    });

    test('重複領取防護：完成後不會重複發放票券', () async {
      final gacha = GachaService();
      final baseTickets = gacha.getPetTickets();

      final svc = PetTutorialService();
      await svc.initialize();
      await svc.setStep(4);
      await svc.recordAction('btn_next'); // 完成並領取
      final afterFirst = gacha.getPetTickets();
      expect(afterFirst, baseTickets + 10);

      // 再次嘗試任何行為都不應再發票
      await svc.recordAction('btn_next');
      expect(gacha.getPetTickets(), afterFirst);
    });
  });
}

