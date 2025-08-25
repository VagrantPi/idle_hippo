import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/main_quest_service.dart';
import 'package:idle_hippo/models/game_state.dart';

void main() {
  group('MainQuestService 測試', () {
    late MainQuestService service;
    late GameState initialState;

    setUp(() {
      service = MainQuestService();
      initialState = GameState.initial(1);
    });

    test('應該正確初始化主線任務狀態', () {
      final state = service.ensureMainQuestState(initialState);
      
      expect(state.mainQuest, isNotNull);
      expect(state.mainQuest!.currentStage, equals(1));
      expect(state.mainQuest!.tapCountProgress, equals(0));
      expect(state.mainQuest!.memePointsEarned, equals(0.0));
      expect(state.mainQuest!.unlockedRewards, isEmpty);
      expect(state.mainQuest!.claimable, isFalse);
    });

    test('應該正確更新點擊進度', () {
      var state = service.ensureMainQuestState(initialState);
      
      // 模擬 10 次點擊
      for (int i = 0; i < 10; i++) {
        state = service.onTap(state);
      }
      
      expect(state.mainQuest!.tapCountProgress, equals(10));
    });

    test('應該正確更新迷因點數進度', () {
      var state = service.ensureMainQuestState(initialState);
      
      // 模擬獲得 100 點迷因點數
      state = service.onEarnPoints(state, 100.0);
      
      expect(state.mainQuest!.memePointsEarned, equals(100.0));
    });

    test('應該在滿足條件時標記第一階段為可領取，並在確認後前進與觸發回調', () {
      var state = service.ensureMainQuestState(initialState);
      bool questCompleted = false;
      String? completedQuestId;
      String? rewardType;
      String? rewardId;
      
      // 設定完成回調
      service.setQuestCompletedCallback((questId, rType, rId) {
        questCompleted = true;
        completedQuestId = questId;
        rewardType = rType;
        rewardId = rId;
      });
      
      // 滿足第一階段條件：10 次點擊 + 50 迷因點數
      for (int i = 0; i < 10; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 50.0);
      
      // 先不會自動完成，應為可領取狀態
      expect(questCompleted, isFalse);
      expect(state.mainQuest!.claimable, isTrue);
      expect(state.mainQuest!.currentStage, equals(1));

      // 玩家確認領取後，才前進並觸發回調
      state = service.claimCurrentQuest(state);
      expect(questCompleted, isTrue);
      expect(completedQuestId, equals('stage1'));
      expect(rewardType, equals('equip'));
      expect(rewardId, equals('youtube'));
      expect(state.mainQuest!.currentStage, equals(2));
      expect(state.mainQuest!.unlockedRewards, contains('equip.youtube'));
    });

    test('應該正確處理第二階段：先達成變可領取，確認後前進', () {
      var state = service.ensureMainQuestState(initialState);
      bool questCompleted = false;
      String? rewardType;
      String? rewardId;
      
      service.setQuestCompletedCallback((questId, rType, rId) {
        questCompleted = true;
        rewardType = rType;
        rewardId = rId;
      });
      
      // 先完成第一階段並確認
      for (int i = 0; i < 10; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 50.0);
      state = service.claimCurrentQuest(state);
      
      // 重置回調狀態
      questCompleted = false;
      
      // 完成第二階段：累計 50 次點擊 + 500 迷因點數
      for (int i = 0; i < 40; i++) { // 已有 10 次，再加 40 次
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 450.0); // 已有 50，再加 450

      // 仍需確認才能前進
      expect(questCompleted, isFalse);
      expect(state.mainQuest!.claimable, isTrue);
      expect(state.mainQuest!.currentStage, equals(2));

      state = service.claimCurrentQuest(state);
      expect(questCompleted, isTrue);
      expect(rewardType, equals('system'));
      expect(rewardId, equals('title'));
      expect(state.mainQuest!.currentStage, equals(3));
      expect(state.mainQuest!.unlockedRewards, contains('system.title'));
    });

    test('應該正確處理第三階段：達成→可領取→確認後前進', () {
      var state = service.ensureMainQuestState(initialState);
      bool questCompleted = false;
      
      service.setQuestCompletedCallback((questId, rType, rId) {
        questCompleted = true;
      });
      
      // 直接設置到第三階段的進度
      state = state.copyWith(
        mainQuest: state.mainQuest!.copyWith(
          currentStage: 3,
          tapCountProgress: 200,
          memePointsEarned: 2000.0,
          unlockedRewards: ['equip.youtube', 'system.title'],
        ),
      );
      
      // 重置回調狀態
      questCompleted = false;
      
      // 完成第三階段：累計 300 次點擊 + 5000 迷因點數
      for (int i = 0; i < 100; i++) { // 已有 200 次，再加 100 次
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 3000.0); // 已有 2000，再加 3000

      // 應為可領取
      expect(questCompleted, isFalse);
      expect(state.mainQuest!.claimable, isTrue);
      expect(state.mainQuest!.currentStage, equals(3));

      state = service.claimCurrentQuest(state);
      expect(questCompleted, isTrue);
      expect(state.mainQuest!.currentStage, equals(4));
      expect(state.mainQuest!.unlockedRewards, contains('system.pet'));
    });

    test('應該正確返回任務統計資訊（使用 progress/claimable）', () {
      var state = service.ensureMainQuestState(initialState);
      
      // 設置一些進度
      for (int i = 0; i < 25; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 250.0);
      
      final stats = service.getStats(state);
      
      expect(stats['currentStage'], equals(1));
      // 第 1 階段需求為 10 次點擊，25 次點擊應視為已滿（progress=1.0）
      expect(stats['progress'], equals(1.0));
      // 達成後應為可領取狀態
      expect(stats['claimable'], isTrue);
    });

    test('應該正確返回任務列表（含 status 與 progress）', () {
      var state = service.ensureMainQuestState(initialState);
      
      final questList = service.getQuestList(state);
      
      expect(questList, hasLength(6));
      expect(questList[0]['stage'], equals(1));
      expect(questList[0]['status'], equals('current'));
      expect(questList[0]['progress'], inExclusiveRange(0.0, 1.0));
      expect(questList[1]['status'], equals('locked'));
      expect(questList[1]['progress'], equals(0.0));
    });

    test('應該正確檢查獎勵解鎖狀態（需確認後才解鎖）', () {
      var state = service.ensureMainQuestState(initialState);
      
      expect(service.isRewardUnlocked(state, 'equip.youtube'), isFalse);
      
      // 達成第一階段
      for (int i = 0; i < 10; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 50.0);

      // 未確認前不會解鎖
      expect(service.isRewardUnlocked(state, 'equip.youtube'), isFalse);

      // 確認後解鎖
      state = service.claimCurrentQuest(state);
      expect(service.isRewardUnlocked(state, 'equip.youtube'), isTrue);
      expect(service.isRewardUnlocked(state, 'system.title'), isFalse);
    });

    test('應該正確返回已解鎖獎勵列表（需確認後生效）', () {
      var state = service.ensureMainQuestState(initialState);
      
      expect(service.getUnlockedRewards(state), isEmpty);
      
      // 達成第一階段
      for (int i = 0; i < 10; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 50.0);

      // 確認後應出現在已解鎖列表
      state = service.claimCurrentQuest(state);
      final rewards = service.getUnlockedRewards(state);
      expect(rewards, contains('equip.youtube'));
      expect(rewards, hasLength(1));
    });

    test('不應該重複完成同一階段任務（確認觸發一次）', () {
      var state = service.ensureMainQuestState(initialState);
      int completionCount = 0;
      
      service.setQuestCompletedCallback((questId, rType, rId) {
        completionCount++;
      });
      
      // 滿足第一階段條件多次
      for (int i = 0; i < 20; i++) {
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 100.0);

      // 僅在確認時觸發一次完成
      expect(completionCount, equals(0));
      state = service.claimCurrentQuest(state);
      expect(completionCount, equals(1));
      expect(state.mainQuest!.currentStage, equals(2));
    });

    test('應該正確處理最後階段完成（第六階段確認後 currentStage 將前進到 7）', () {
      var state = service.ensureMainQuestState(initialState);
      bool questCompleted = false;
      
      service.setQuestCompletedCallback((questId, rType, rId) {
        questCompleted = true;
      });
      
      // 直接設置到第六階段的進度
      state = state.copyWith(
        mainQuest: state.mainQuest!.copyWith(
          currentStage: 6,
          tapCountProgress: 4900,
          memePointsEarned: 99000.0,
          unlockedRewards: ['equip.youtube', 'system.title', 'system.pet', 'hippo.skin1', 'hippo.skin2'],
        ),
      );
      
      // 重置回調狀態
      questCompleted = false;
      
      // 完成第六階段：累計 5000 次點擊 + 100000 迷因點數
      for (int i = 0; i < 100; i++) { // 已有 4900 次，再加 100 次
        state = service.onTap(state);
      }
      state = service.onEarnPoints(state, 1000.0); // 已有 99000，再加 1000

      // 應為可領取，但尚未觸發完成
      expect(questCompleted, isFalse);
      expect(state.mainQuest!.claimable, isTrue);
      expect(state.mainQuest!.currentStage, equals(6));

      // 確認後觸發完成，currentStage 會前進到 7
      state = service.claimCurrentQuest(state);
      expect(questCompleted, isTrue);
      expect(state.mainQuest!.currentStage, equals(7));
      expect(state.mainQuest!.unlockedRewards, contains('hippo.skin3'));
    });
  });
}
