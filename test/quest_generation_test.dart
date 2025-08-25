import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/pet_ticket_quest_service.dart';

void main() {
  group('PetTicketQuestService - Generation', () {
    late PetTicketQuestService service;
    late GameState initialGameState;

    setUp(() {
      service = PetTicketQuestService();
      initialGameState = GameState.initial(1).copyWith(
        mainQuest: const MainQuestState(currentStage: 3),
        petTicketQuest: const PetTicketQuest(available: true),
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
  });
}
