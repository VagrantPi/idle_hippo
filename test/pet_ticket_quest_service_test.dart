import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/pet_ticket_quest_service.dart';

void main() {
  group('PetTicketQuestService 測試', () {
    late PetTicketQuestService service;
    late GameState initialGameState;

    setUp(() {
      service = PetTicketQuestService();
      initialGameState = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(currentStage: 3), // 預設為已解鎖狀態
        petTicketQuest: const PetTicketQuest(available: true), // 預設為可用
      );
    });

    test('案例 1: 首次任務生成', () {
      // Given
      const idlePerSec = 5.0;
      var gameState = initialGameState.copyWith(
        petTicketQuest: const PetTicketQuest(available: true, k: 0, target: 0),
      );

      // When
      final newState = service.generateFirstQuest(gameState, currentIdlePerSec: idlePerSec);

      // Then
      final quest = newState.petTicketQuest!;
      // 5 * (60*60*48) + 200 = 864,200
      expect(quest.target, 864200.0);
      expect(quest.progress, 0);
      expect(quest.k, 0);
      expect(quest.idleSnapshot, 5.0);
    });


    test('案例 2: 完成並累加 k', () {
      // Given
      const idlePerSec = 5.0;
      var gameState = initialGameState.copyWith(
        petTicketQuest: const PetTicketQuest(
          available: true,
          k: 0,
          // 5 * (60*60*48) + 200
          target: 20736200,
          progress: 20736200, // 任務已完成
          idleSnapshot: idlePerSec,
        ),
      );

      // When
      final newState = service.claimReward(gameState, withAd: false, currentIdlePerSec: idlePerSec);

      // Then
      final quest = newState.petTicketQuest!;
      expect(newState.petTickets, 1);
      expect(quest.k, 0.05);
      // 5*(60*60*48)*1.05 + 200 = 907,400
      expect(quest.target, 907400.0);
      expect(quest.progress, 0);
    });

    test('案例 3: 廣告翻倍', () {
      // Given
      const idlePerSec = 5.0;
      var gameState = initialGameState.copyWith(
        petTicketQuest: const PetTicketQuest(
          available: true,
          k: 0,
          target: 20736200,
          progress: 20736200,
          idleSnapshot: idlePerSec,
        ),
      );

      // When
      final newState = service.claimReward(gameState, withAd: true, currentIdlePerSec: idlePerSec);

      // Then
      expect(newState.petTickets, 2);
      expect(newState.petTicketQuest!.k, 0.05);
      expect(newState.petTicketQuest!.target, 907400.0);
    });

    test('案例 4: 解鎖條件 - 未達標', () {
      // Given
      var gameState = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(currentStage: 2), // 未達到 stage 3
        petTicketQuest: const PetTicketQuest(available: false),
      );

      // When
      final newState = service.checkAndUnlock(gameState);

      // Then
      expect(newState.petTicketQuest?.available, isFalse);
    });

    test('案例 4: 任務解鎖', () {
      // Given: Stage 4 (已完成 stage 3)，應解鎖
      var gameState = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(currentStage: 4),
        petTicketQuest: const PetTicketQuest(available: false),
      );

      // When
      var newState = service.checkAndUnlock(gameState);
      newState = service.generateFirstQuest(newState, currentIdlePerSec: 5.0);

      // Then: Available and first quest generated
      expect(newState.petTicketQuest!.available, isTrue);
      expect(newState.petTicketQuest!.target, 864200.0);
    });

    test('案例 5: 首頁數值更新 (由 GameState 直接驗證)', () {
      // Given
      const idlePerSec = 5.0;
      var gameState = initialGameState.copyWith(
        petTickets: 3,
        petTicketQuest: const PetTicketQuest(
          available: true,
          k: 0,
          target: 100,
          progress: 100,
          idleSnapshot: idlePerSec,
        ),
      );

      // When
      final newState = service.claimReward(gameState, withAd: false, currentIdlePerSec: idlePerSec);

      // Then
      expect(newState.petTickets, 4);
    });

    test('進度增加', () {
      // Given
      var gameState = initialGameState.copyWith(
        petTicketQuest: const PetTicketQuest(available: true, k: 0, target: 100, progress: 10),
      );

      // When
      final newState = service.addProgress(gameState, 50);

      // Then
      expect(newState.petTicketQuest!.progress, 60);
    });

    test('進度在完成後不應再增加', () {
      // Given
      var gameState = initialGameState.copyWith(
        petTicketQuest: const PetTicketQuest(available: true, k: 0, target: 100, progress: 100),
      );

      // When
      final newState = service.addProgress(gameState, 50);

      // Then
      expect(newState.petTicketQuest!.progress, 100);
    });
  });
}
