import 'package:idle_hippo/models/game_state.dart';

class PetTicketQuestService {
  // 公式中定義的常數
  // 48 小時的秒數：60 * 60 * 48
  static const double _SECONDS_IN_48_HOURS = 60 * 60 * 48;
  static const double _K_INCREMENT = 0.05;
  static const double _BASE_BONUS = 200.0;
  static const int _UNLOCK_STAGE = 3;

  /// 檢查任務是否應該解鎖
  /// 當主線任務「完成」stage 3 後解鎖。
  /// 規則：
  /// - 若 currentStage > 3（已領取並前進到 4），解鎖。
  GameState checkAndUnlock(GameState gameState) {
    final quest = gameState.petTicketQuest ?? const PetTicketQuest();
    // print('quest.available: ${quest.available}');
    if (quest.available) {
      return gameState; // 已解鎖，不需更動
    }

    final mainQuest = gameState.mainQuest ?? const MainQuestState();
    if (mainQuest.currentStage > _UNLOCK_STAGE) {
      return gameState.copyWith(
        petTicketQuest: quest.copyWith(available: true),
      );
    }

    return gameState;
  }

  /// 當能量增加時，更新任務進度
  GameState addProgress(GameState gameState, double energyToAdd) {
    var quest = gameState.petTicketQuest;
    // print('energyToAdd: $energyToAdd');
    // print('quest.available: ${quest?.available}');
    if (quest == null || !quest.available || quest.progress >= quest.target) {
      return gameState; // 任務未啟用或已完成，不處理
    }

    quest = quest.copyWith(progress: quest.progress + energyToAdd);
    return gameState.copyWith(petTicketQuest: quest);
  }

  /// 領取獎勵並生成下一個任務
  /// [withAd] - 是否觀看廣告以獲得翻倍獎勵
  /// [currentIdlePerSec] - 用於計算下一個任務目標的當前每秒被動收益
  GameState claimReward(GameState gameState, {bool withAd = false, required double currentIdlePerSec}) {
    var quest = gameState.petTicketQuest;
    if (quest == null || !quest.available || quest.progress < quest.target) {
      // 任務未完成，無法領取
      return gameState;
    }

    final rewardAmount = withAd ? 2 : 1;
    final newK = quest.k + _K_INCREMENT;
    final newTarget = (currentIdlePerSec * _SECONDS_IN_48_HOURS * (1 + newK)) + _BASE_BONUS;

    final newQuest = quest.copyWith(
      k: newK,
      target: newTarget,
      progress: 0,
      idleSnapshot: currentIdlePerSec,
    );

    return gameState.copyWith(
      petTickets: gameState.petTickets + rewardAmount,
      petTicketQuest: newQuest,
    );
  }

  /// 產生第一個抽獎券任務
  GameState generateFirstQuest(GameState gameState, {required double currentIdlePerSec}) {
    var quest = gameState.petTicketQuest;
    if (quest == null || !quest.available || quest.target > 0) {
      return gameState; // 未解鎖或已有任務，不生成
    }

    const initialK = 0.0;
    final newTarget = (currentIdlePerSec * _SECONDS_IN_48_HOURS * (1 + initialK)) + _BASE_BONUS;

    final newQuest = quest.copyWith(
      k: initialK,
      target: newTarget,
      progress: 0,
      idleSnapshot: currentIdlePerSec,
    );

    return gameState.copyWith(petTicketQuest: newQuest);
  }
}
