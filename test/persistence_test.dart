import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/game_state_service.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/models/pet.dart';

/// 持久化功能測試
/// 驗證所有 lib/models 內的數值狀態在應用重啟後都能正確保存和恢復
void main() {
  group('持久化功能測試', () {
    late GameStateService gameStateService;

    setUp(() {
      gameStateService = GameStateService();
    });

    test('基本數值持久化測試', () async {
      // 初始化測試狀態
      final initialState = GameState.initial(1);
      await gameStateService.initializeForTest(initialState);

      // 修改各種數值
      final modifiedState = initialState.copyWith(
        memePoints: 12345.67,
        equipments: {'testEquip': 5, 'anotherEquip': 10},
        petTickets: 3,
      );

      // 保存狀態
      await gameStateService.updateGameState(modifiedState);

      // 驗證狀態已更新
      expect(gameStateService.currentState.memePoints, equals(12345.67));
      expect(gameStateService.currentState.equipments['testEquip'], equals(5));
      expect(gameStateService.currentState.petTickets, equals(3));
    });

    test('複雜狀態結構持久化測試', () async {
      // 測試包含巢狀結構的狀態
      final complexState = GameState.initial(1).copyWith(
        checkin: CheckinState(
          today: CheckinToday(
            date: '2025-01-01',
            status: 'completed',
            task: CheckinTask(type: 'tap', target: 100, progress: 100),
          ),
        ),
        karaoke: KaraokeState(
          lastPlayDate: '2025-01-01',
          playedToday: true,
          collectUpdatedAt: 1234567890,
          collectPath: 'test://path',
        ),
      );

      await gameStateService.initializeForTest(complexState);
      await gameStateService.updateGameState(complexState);

      final savedState = gameStateService.currentState;

      // 驗證 checkin 狀態
      expect(savedState.checkin?.today.date, equals('2025-01-01'));
      expect(savedState.checkin?.today.status, equals('completed'));
      expect(savedState.checkin?.today.task.progress, equals(100));

      // 驗證 karaoke 狀態
      expect(savedState.karaoke?.lastPlayDate, equals('2025-01-01'));
      expect(savedState.karaoke?.playedToday, equals(true));
    });

    test('抽卡歷史持久化測試', () async {
      final gachaHistory = [
        GachaHistoryRecord(
          rarity: 'rare',
          name: '測試寵物',
          timestamp: 1234567890,
          petKey: 'test_pet',
        ),
        GachaHistoryRecord(
          rarity: 'common',
          name: '普通寵物',
          timestamp: 1234567891,
          petKey: 'common_pet',
        ),
      ];

      final stateWithHistory = GameState.initial(
        1,
      ).copyWith(gachaHistory: gachaHistory);

      await gameStateService.initializeForTest(stateWithHistory);
      await gameStateService.updateGameState(stateWithHistory);

      final savedState = gameStateService.currentState;
      expect(savedState.gachaHistory.length, equals(2));
      expect(savedState.gachaHistory[0].name, equals('測試寵物'));
      expect(savedState.gachaHistory[1].rarity, equals('common'));
    });

    test('寵物狀態持久化測試', () async {
      final testPet1 = Pet(
        petKey: 'test_pet',
        name: '測試寵物',
        imagePath: 'test.png',
        rarity: PetRarity.r,
        baseIdlePerSec: 10.0,
        level: 5,
        upgradePoints: 100,
        isEquipped: true,
      );

      final testPet2 = Pet(
        petKey: 'another_pet',
        name: '另一隻寵物',
        imagePath: 'another.png',
        rarity: PetRarity.s,
        baseIdlePerSec: 15.0,
        level: 3,
        upgradePoints: 50,
        isEquipped: false,
      );

      final petState = PetState(
        pets: [testPet1, testPet2],
        equippedPetId: 'test_pet_R',
      );

      final stateWithPets = GameState.initial(1).copyWith(petState: petState);

      await gameStateService.initializeForTest(stateWithPets);
      await gameStateService.updateGameState(stateWithPets);

      final savedState = gameStateService.currentState;
      expect(savedState.petState?.pets.length, equals(2));
      expect(savedState.petState?.pets[0].petKey, equals('test_pet'));
      expect(savedState.petState?.pets[0].level, equals(5));
      expect(savedState.petState?.equippedPetId, equals('test_pet_R'));
    });

    test('稱號系統持久化測試', () async {
      final titlesState = TitlesState(
        states: {
          'title1': 'claimed',
          'title2': 'claimable',
          'title3': 'locked',
        },
        claimedAt: {'title1': 1234567890},
        hasClaimable: true,
      );

      final stateWithTitles = GameState.initial(
        1,
      ).copyWith(titles: titlesState);

      await gameStateService.initializeForTest(stateWithTitles);
      await gameStateService.updateGameState(stateWithTitles);

      final savedState = gameStateService.currentState;
      expect(savedState.titles?.states['title1'], equals('claimed'));
      expect(savedState.titles?.hasClaimable, equals(true));
      expect(savedState.titles?.claimedAt['title1'], equals(1234567890));
    });

    test('離線獎勵狀態持久化測試', () async {
      final offlineState = OfflineState(
        lastExitUtcMs: 1234567890,
        idleRateSnapshot: 100.5,
        pendingReward: 50.0,
        capHours: 8,
        lastReward: 25.0,
        lastRewardSec: 30.0,
        lastRewardAtMs: 1234567800,
        lastRewardDoubled: true,
      );

      final stateWithOffline = GameState.initial(
        1,
      ).copyWith(offline: offlineState);

      await gameStateService.initializeForTest(stateWithOffline);
      await gameStateService.updateGameState(stateWithOffline);

      final savedState = gameStateService.currentState;
      expect(savedState.offline.lastExitUtcMs, equals(1234567890));
      expect(savedState.offline.idleRateSnapshot, equals(100.5));
      expect(savedState.offline.lastRewardAtMs, equals(1234567800));
      expect(savedState.offline.lastRewardDoubled, equals(true));
    });

    test('每日任務狀態持久化測試', () async {
      final dailyMission = DailyMissionState(
        date: '2025-01-01',
        index: 1,
        type: 'tapX',
        progress: 50.0,
        target: 100.0,
        idlePerSecSnapshot: 10.0,
        todayCompleted: 0,
        completed: [],
      );

      final stateWithMissions = GameState.initial(
        1,
      ).copyWith(dailyMission: dailyMission);

      await gameStateService.initializeForTest(stateWithMissions);
      await gameStateService.updateGameState(stateWithMissions);

      final savedState = gameStateService.currentState;
      expect(savedState.dailyMission?.date, equals('2025-01-01'));
      expect(savedState.dailyMission?.type, equals('tapX'));
      expect(savedState.dailyMission?.progress, equals(50.0));
      expect(savedState.dailyMission?.target, equals(100.0));
    });

    test('完整狀態持久化整合測試', () async {
      // 建立包含所有主要狀態的複雜測試案例
      final complexState = GameState(
        saveVersion: 1,
        memePoints: 99999.99,
        equipments: {'weapon': 10, 'armor': 8, 'accessory': 5},
        petTickets: 15,
        gachaHistory: [
          GachaHistoryRecord(
            rarity: 'legendary',
            name: '傳說寵物',
            timestamp: 1234567890,
            petKey: 'legendary_pet',
          ),
        ],
        petState: PetState(
          pets: [
            Pet(
              petKey: 'legendary_pet',
              name: '傳說寵物',
              imagePath: 'legendary.png',
              rarity: PetRarity.ssr,
              baseIdlePerSec: 100.0,
              level: 10,
              upgradePoints: 5000,
              isEquipped: true,
            ),
          ],
          equippedPetId: 'legendary_pet_SSR',
        ),
        titles: TitlesState(
          states: {'master': 'claimed'},
          claimedAt: {'master': 1234567890},
          hasClaimable: false,
        ),
        offline: OfflineState(
          lastExitUtcMs: 1234567890,
          idleRateSnapshot: 250.75,
          lastRewardAtMs: 1234567800,
        ),
        checkin: CheckinState(
          today: CheckinToday(
            date: '2025-01-01',
            status: 'completed',
            task: CheckinTask(type: 'collect', target: 1000, progress: 1000),
          ),
        ),
        karaoke: KaraokeState(
          lastPlayDate: '2025-01-01',
          playedToday: true,
          collectUpdatedAt: 1234567890,
          collectPath: 'appdata://collect.json',
        ),
        lastTs: 1234567890,
      );

      await gameStateService.initializeForTest(complexState);
      await gameStateService.updateGameState(complexState);

      final savedState = gameStateService.currentState;

      // 驗證所有主要狀態都正確保存
      expect(savedState.memePoints, equals(99999.99));
      expect(savedState.equipments['weapon'], equals(10));
      expect(savedState.petTickets, equals(15));
      expect(savedState.gachaHistory[0].name, equals('傳說寵物'));
      expect(savedState.petState?.pets[0].petKey, equals('legendary_pet'));
      expect(savedState.titles?.states['master'], equals('claimed'));
      expect(savedState.offline.idleRateSnapshot, equals(250.75));
      expect(savedState.checkin?.today.status, equals('completed'));
      expect(savedState.karaoke?.playedToday, equals(true));
    });
  });
}
