import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/pet.dart';

void main() {
  group('PetRarity', () {
    test('應該正確從字串轉換為稀有度', () {
      expect(PetRarity.fromString('RR'), PetRarity.rr);
      expect(PetRarity.fromString('R'), PetRarity.r);
      expect(PetRarity.fromString('S'), PetRarity.s);
      expect(PetRarity.fromString('SR'), PetRarity.sr);
      expect(PetRarity.fromString('SSR'), PetRarity.ssr);
    });

    test('應該返回正確的稀有度權重', () {
      expect(PetRarity.rr.sortWeight, 1);
      expect(PetRarity.r.sortWeight, 2);
      expect(PetRarity.s.sortWeight, 3);
      expect(PetRarity.sr.sortWeight, 4);
      expect(PetRarity.ssr.sortWeight, 5);
    });

    test('應該返回正確的稀有度顏色', () {
      expect(PetRarity.rr.getColor().value, 0xFF808080);
      expect(PetRarity.r.getColor().value, 0xFF00FF00);
      expect(PetRarity.s.getColor().value, 0xFF0000FF);
      expect(PetRarity.sr.getColor().value, 0xFF800080);
      expect(PetRarity.ssr.getColor().value, 0xFFFF0000);
    });
  });

  group('Pet', () {
    late Pet testPet;

    setUp(() {
      testPet = const Pet(
        petKey: 'MooDeng',
        name: '彈跳豬 MooDeng',
        imagePath: 'assets/images/pets/moodeng.png',
        rarity: PetRarity.r,
        baseIdlePerSec: 10.0,
        level: 1,
        upgradePoints: 0,
        isEquipped: false,
      );
    });

    test('應該正確建立 Pet 實例', () {
      expect(testPet.petKey, 'MooDeng');
      expect(testPet.name, '彈跳豬 MooDeng');
      expect(testPet.rarity, PetRarity.r);
      expect(testPet.baseIdlePerSec, 10.0);
      expect(testPet.level, 1);
      expect(testPet.upgradePoints, 0);
      expect(testPet.isEquipped, false);
    });

    test('應該正確計算費氏數列升級需求', () {
      expect(testPet.getUpgradeRequirement(1), 1);
      expect(testPet.getUpgradeRequirement(2), 2);
      expect(testPet.getUpgradeRequirement(3), 3);
      expect(testPet.getUpgradeRequirement(4), 5);
      expect(testPet.getUpgradeRequirement(5), 8);
      expect(testPet.getUpgradeRequirement(6), 13);
      expect(testPet.getUpgradeRequirement(7), 21);
      expect(testPet.getUpgradeRequirement(8), 34);
    });

    test('應該正確計算下一級升級需求', () {
      expect(testPet.getUpgradeRequirement(1), 1); // Level 1 -> 2 需要 1 點
      
      final level2Pet = testPet.copyWith(level: 2);
      expect(level2Pet.getUpgradeRequirement(2), 2); // Level 2 -> 3 需要 2 點
      
      final level3Pet = testPet.copyWith(level: 3);
      expect(level3Pet.getUpgradeRequirement(3), 3); // Level 3 -> 4 需要 2 點
    });

    test('應該正確判斷是否可以升級', () {
      final level1Pet = testPet.copyWith(level: 0, upgradePoints: 0);
      expect(level1Pet.canUpgrade, false); // 0 點，需要 1 點
      
      final level1Pet2 = testPet.copyWith(level: 0, upgradePoints: 1);
      expect(level1Pet2.canUpgrade, true); // 1 點，需要 1 點

      final level1Pet3 = testPet.copyWith(level: 0, upgradePoints: 3);
      expect(level1Pet3.canUpgrade, true); // 3 點，需要 1 點
    });

    test('應該正確計算等級加成倍率', () {
      const levelUpUpgradeBase = 0.5;
      const decayLevels = 10;
      const decayRate = 0.5;
      
      // Level 1 應該沒有加成
      expect(testPet.getLevelUpgradeMultiplier(levelUpUpgradeBase, decayLevels, decayRate), 1.0);
      
      // Level 2 應該有 0.5 加成
      final level2Pet = testPet.copyWith(level: 2);
      expect(level2Pet.getLevelUpgradeMultiplier(levelUpUpgradeBase, decayLevels, decayRate), 1.5);
      
      // Level 3 應該有 1.0 加成
      final level3Pet = testPet.copyWith(level: 3);
      expect(level3Pet.getLevelUpgradeMultiplier(levelUpUpgradeBase, decayLevels, decayRate), 2.0);
    });

    test('應該正確計算當前 idlePerSec', () {
      const levelUpUpgradeBase = 0.5;
      const decayLevels = 10;
      const decayRate = 0.5;
      
      // Level 1: 10.0 * 1.0 = 10.0
      expect(testPet.getCurrentIdlePerSec(levelUpUpgradeBase, decayLevels, decayRate), 10.0);
      
      // Level 2: 10.0 * 1.5 = 15.0
      final level2Pet = testPet.copyWith(level: 2);
      expect(level2Pet.getCurrentIdlePerSec(levelUpUpgradeBase, decayLevels, decayRate), 15.0);
    });

    test('應該正確執行升級', () {
      final testPetThis = testPet.copyWith(level: 0);
      
      final petWith5Points = testPetThis.copyWith(upgradePoints: 5);
      final upgradedPet = petWith5Points.upgrade();
      
      expect(upgradedPet.level, 1);
      expect(upgradedPet.upgradePoints, 4); // 5 - 1 = 4
    });

    test('升級點數不足時不應該升級', () {
      final upgradedPet = testPet.upgrade(); // 0 點，需要 1 點
      
      expect(upgradedPet.level, 1); // 等級不變
      expect(upgradedPet.upgradePoints, 0); // 點數不變
    });

    test('應該正確增加升級點數', () {
      final petWithMorePoints = testPet.addUpgradePoints(10);
      
      expect(petWithMorePoints.upgradePoints, 10);
      expect(petWithMorePoints.level, 1); // 其他屬性不變
    });

    test('應該正確設定裝備狀態', () {
      final equippedPet = testPet.setEquipped(true);
      
      expect(equippedPet.isEquipped, true);
      expect(equippedPet.level, 1); // 其他屬性不變
    });

    test('應該正確轉換為 Map', () {
      final map = testPet.toMap();
      
      expect(map['petKey'], 'MooDeng');
      expect(map['name'], '彈跳豬 MooDeng');
      expect(map['rarity'], 'R');
      expect(map['baseIdlePerSec'], 10.0);
      expect(map['level'], 1);
      expect(map['upgradePoints'], 0);
      expect(map['isEquipped'], false);
    });

    test('應該正確從 Map 建立 Pet', () {
      final map = {
        'petKey': 'TestPet',
        'name': '測試寵物',
        'imagePath': 'test.png',
        'rarity': 'SSR',
        'baseIdlePerSec': 20.0,
        'level': 5,
        'upgradePoints': 100,
        'isEquipped': true,
      };
      
      final pet = Pet.fromMap(map);
      
      expect(pet.petKey, 'TestPet');
      expect(pet.name, '測試寵物');
      expect(pet.rarity, PetRarity.ssr);
      expect(pet.baseIdlePerSec, 20.0);
      expect(pet.level, 5);
      expect(pet.upgradePoints, 100);
      expect(pet.isEquipped, true);
    });
  });

  group('PetState', () {
    test('應該正確建立空的 PetState', () {
      const petState = PetState();
      
      expect(petState.pets, isEmpty);
      expect(petState.equippedPetId, isNull);
      expect(petState.equippedPet, isNull);
    });

    test('應該正確取得裝備的寵物', () {
      final pet1 = const Pet(
        petKey: 'Pet1',
        name: '寵物1',
        imagePath: 'pet1.png',
        rarity: PetRarity.r,
        baseIdlePerSec: 10.0,
        isEquipped: false,
      );
      
      final pet2 = const Pet(
        petKey: 'Pet2',
        name: '寵物2',
        imagePath: 'pet2.png',
        rarity: PetRarity.s,
        baseIdlePerSec: 15.0,
        isEquipped: true,
      );
      
      final petState = PetState(
        pets: [pet1, pet2],
        equippedPetId: 'Pet2_S',
      );
      
      expect(petState.equippedPet, pet2);
    });
  });
}
