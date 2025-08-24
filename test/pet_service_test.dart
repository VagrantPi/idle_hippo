import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/pet.dart';
import 'package:idle_hippo/services/pet_service.dart';

void main() {
  // 初始化 Flutter 測試綁定，避免使用 asset bundle 等服務時拋出 Binding 未初始化錯誤
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PetService', () {
    late PetService petService;

    setUp(() {
      petService = PetService();
    });

    tearDown(() {
      petService.dispose();
    });

    test('應該正確初始化空的寵物狀態', () async {
      await petService.initialize(null);
      
      expect(petService.currentState.pets, isNotEmpty);
      expect(petService.currentState.pets.length, 5); // 五種稀有度
    });

    test('應該正確初始化已保存的寵物狀態', () async {
      final savedPets = [
        const Pet(
          petKey: 'MooDeng',
          name: '彈跳豬 MooDeng',
          imagePath: 'assets/images/pets/moodeng_r.png',
          rarity: PetRarity.r,
          baseIdlePerSec: 10.0,
          level: 5,
          upgradePoints: 100,
          isEquipped: true,
        ),
      ];
      
      final savedState = PetState(
        pets: savedPets,
        equippedPetId: 'MooDeng_R',
      );
      
      await petService.initialize(savedState);
      
      expect(petService.currentState.pets.length, 1);
      expect(petService.currentState.equippedPet?.level, 5);
      expect(petService.currentState.equippedPet?.upgradePoints, 100);
    });

    test('應該正確裝備寵物', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final firstPet = pets.first;
      
      await petService.equipPet(firstPet);
      
      expect(petService.currentState.equippedPet?.petKey, firstPet.petKey);
      expect(petService.currentState.equippedPet?.rarity, firstPet.rarity);
    });

    test('應該正確卸下寵物', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final firstPet = pets.first;
      
      // 先裝備
      await petService.equipPet(firstPet);
      expect(petService.currentState.equippedPet, isNotNull);
      
      // 再卸下
      await petService.unequipPet();
      expect(petService.currentState.equippedPet, isNull);
    });

    test('裝備新寵物時應該自動卸下舊寵物', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final firstPet = pets[0];
      final secondPet = pets[1];
      
      // 裝備第一隻寵物
      await petService.equipPet(firstPet);
      expect(petService.currentState.equippedPet?.petKey, firstPet.petKey);
      
      // 裝備第二隻寵物
      await petService.equipPet(secondPet);
      expect(petService.currentState.equippedPet?.petKey, secondPet.petKey);
      
      // 確認只有一隻寵物被裝備
      final equippedCount = petService.currentState.pets.where((pet) => pet.isEquipped).length;
      expect(equippedCount, 1);
    });

    test('應該正確升級寵物', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final testPet = pets.first.copyWith(upgradePoints: 10); // 給予足夠的升級點數
      
      // 更新寵物狀態
      final updatedState = petService.currentState.updatePet(testPet);
      await petService.initialize(updatedState);
      
      final originalLevel = testPet.level;
      final success = await petService.upgradePet(testPet);
      
      expect(success, true);
      
      final upgradedPet = petService.currentState.pets.firstWhere(
        (pet) => pet.petKey == testPet.petKey && pet.rarity == testPet.rarity
      );
      expect(upgradedPet.level, originalLevel + 1);
    });

    test('升級點數不足時不應該升級', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final testPet = pets.first; // 預設 0 升級點數
      
      final success = await petService.upgradePet(testPet);
      
      expect(success, false);
      
      final unchangedPet = petService.currentState.pets.firstWhere(
        (pet) => pet.petKey == testPet.petKey && pet.rarity == testPet.rarity
      );
      expect(unchangedPet.level, testPet.level);
    });

    test('應該正確為所有寵物增加升級點數', () async {
      await petService.initialize(null);
      
      final originalPoints = petService.currentState.pets.map((pet) => pet.upgradePoints).toList();
      
      await petService.addUpgradePointsToAll(50);
      
      final updatedPoints = petService.currentState.pets.map((pet) => pet.upgradePoints).toList();
      
      for (int i = 0; i < originalPoints.length; i++) {
        expect(updatedPoints[i], originalPoints[i] + 50);
      }
    });

    test('應該正確計算當前裝備寵物的 idlePerSec', () async {
      await petService.initialize(null);
      
      // 沒有裝備寵物時應該返回 0
      expect(petService.getCurrentPetIdlePerSec(), 0.0);
      
      final pets = petService.currentState.pets;
      final testPet = pets.first;
      
      // 裝備寵物後應該返回正確的值
      await petService.equipPet(testPet);
      final idlePerSec = petService.getCurrentPetIdlePerSec();
      
      expect(idlePerSec, greaterThan(0.0));
      expect(idlePerSec, testPet.baseIdlePerSec); // Level 1 時應該等於基礎值
    });

    test('應該正確計算特定寵物的 idlePerSec', () async {
      await petService.initialize(null);
      
      final pets = petService.currentState.pets;
      final testPet = pets.first;
      
      final idlePerSec = petService.getPetIdlePerSec(testPet);
      
      expect(idlePerSec, testPet.baseIdlePerSec); // Level 1 時應該等於基礎值
    });

    test('應該正確計算費氏數列升級需求', () {
      expect(petService.getFibonacciUpgradeRequirement(1), 1);
      expect(petService.getFibonacciUpgradeRequirement(2), 2);
      expect(petService.getFibonacciUpgradeRequirement(3), 3);
      expect(petService.getFibonacciUpgradeRequirement(4), 5);
      expect(petService.getFibonacciUpgradeRequirement(5), 8);
      expect(petService.getFibonacciUpgradeRequirement(6), 13);
      expect(petService.getFibonacciUpgradeRequirement(7), 21);
    });

    test('應該正確計算等級加成倍率', () {
      expect(petService.calculateLevelUpgradeMultiplier(1), 1.0);
      expect(petService.calculateLevelUpgradeMultiplier(2), 1.5); // 假設 base = 0.5
    });

    test('應該正確取得按稀有度排序的寵物列表', () async {
      await petService.initialize(null);
      
      final sortedPets = petService.getSortedPets();
      
      // 應該按稀有度從高到低排序
      for (int i = 0; i < sortedPets.length - 1; i++) {
        expect(sortedPets[i].rarity.sortWeight, 
               greaterThanOrEqualTo(sortedPets[i + 1].rarity.sortWeight));
      }
    });

    test('應該正確根據稀有度取得寵物', () async {
      await petService.initialize(null);
      
      final rarePet = petService.getPetByRarity(PetRarity.r);
      expect(rarePet?.rarity, PetRarity.r);
      
      final ssrPet = petService.getPetByRarity(PetRarity.ssr);
      expect(ssrPet?.rarity, PetRarity.ssr);
    });

    test('應該正確檢查是否有可升級的寵物', () async {
      await petService.initialize(null);
      
      // 初始狀態應該沒有可升級的寵物
      expect(petService.hasUpgradablePets(), false);
      
      // 增加升級點數後應該有可升級的寵物
      await petService.addUpgradePointsToAll(10);
      expect(petService.hasUpgradablePets(), true);
    });

    test('應該正確取得可升級的寵物列表', () async {
      await petService.initialize(null);
      
      // 初始狀態應該沒有可升級的寵物
      expect(petService.getUpgradablePets(), isEmpty);
      
      // 增加升級點數後應該有可升級的寵物
      await petService.addUpgradePointsToAll(10);
      final upgradablePets = petService.getUpgradablePets();
      expect(upgradablePets, isNotEmpty);
      expect(upgradablePets.length, 5); // 所有寵物都可升級
    });

    test('應該正確重置寵物系統', () async {
      await petService.initialize(null);
      
      // 修改狀態
      await petService.addUpgradePointsToAll(100);
      final pets = petService.currentState.pets;
      await petService.equipPet(pets.first);
      
      // 重置
      await petService.reset();
      
      // 檢查是否恢復初始狀態
      expect(petService.currentState.equippedPet, isNull);
      expect(petService.currentState.pets.every((pet) => pet.upgradePoints == 0), true);
      expect(petService.currentState.pets.every((pet) => pet.level == 1), true);
    });

    test('應該正確提供 debug 資訊', () async {
      await petService.initialize(null);
      
      final debugInfo = petService.getDebugInfo();
      
      expect(debugInfo['totalPets'], 5);
      expect(debugInfo['equippedPetId'], isNull);
      expect(debugInfo['equippedPetIdlePerSec'], 0.0);
      expect(debugInfo['pets'], isA<List>());
      expect(debugInfo['upgradeConfig'], isA<Map>());
    });

    test('petStateStream 應該正確發送狀態更新', () async {
      await petService.initialize(null);
      
      final stateUpdates = <PetState>[];
      final subscription = petService.petStateStream.listen((state) {
        stateUpdates.add(state);
      });
      
      // 執行一些操作
      await petService.addUpgradePointsToAll(10);
      final pets = petService.currentState.pets;
      await petService.equipPet(pets.first);
      
      // 等待 stream 更新
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(stateUpdates.length, greaterThanOrEqualTo(2));
      
      subscription.cancel();
    });
  });
}
