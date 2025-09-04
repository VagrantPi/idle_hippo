import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/pet.dart';

void main() {
  // 規格：
  // - 費氏數列升級需求：1,2,3,5,8,13...
  // - 升級加成：base=0.5， 每 10 等級減半，decayRate=0.5
  const levelUpUpgradeBase = 0.5;
  const decayLevels = 10;
  const decayRate = 0.5;

  double expectedMultiplier(int level) {
    if (level <= 1) return 1.0;
    double total = 0.0;
    double current = levelUpUpgradeBase;
    for (int i = 2; i <= level; i++) {
      total += current;
      if (i % decayLevels == 0) {
        current *= decayRate;
      }
    }
    return 1.0 + total;
  }

  group('Step18 寵物升級（費氏數列與加成）', () {
    test('案例1：S 級寵物升級 4 次（需 2+3+5+8=18 碎片），升至 Lv5 並清空碎片', () {
      // baseIdlePerSec 依規格：S = 0.3/s
      var pet = Pet(
        petKey: 'PEPE',
        name: '佩佩蛙',
        imagePath: 'assets/images/pet/PEPE.png',
        rarity: PetRarity.s,
        baseIdlePerSec: 0.3,
        level: 1,
        upgradePoints: 18, // 2+3+5+8
        isEquipped: false,
      );

      // 升級 1->2(2), 2->3(3), 3->4(5), 4->5(8)
      for (int i = 0; i < 4; i++) {
        expect(pet.canUpgrade, isTrue);
        pet = pet.upgrade();
      }

      expect(pet.level, 5);
      expect(pet.upgradePoints, 0);

      final multiplier = pet.getLevelUpgradeMultiplier(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(multiplier, closeTo(expectedMultiplier(5), 1e-9));
      final idle = pet.getCurrentIdlePerSec(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(idle, closeTo(0.3 * expectedMultiplier(5), 1e-9));
    });

    test('案例2：S 級寵物升至 Lv10，扣除碎片總和並驗證 idlePerSec', () {
      // 準備充足碎片（2+3+5+8+13+21+34+55+89）= 230
      int totalNeeded = 2 + 3 + 5 + 8 + 13 + 21 + 34 + 55 + 89;
      var pet = Pet(
        petKey: 'PEPE',
        name: '佩佩蛙',
        imagePath: 'assets/images/pet/PEPE.png',
        rarity: PetRarity.s,
        baseIdlePerSec: 0.3,
        level: 1,
        upgradePoints: totalNeeded,
        isEquipped: false,
      );

      while (pet.level < 10) {
        expect(pet.canUpgrade, isTrue);
        final beforeReq = pet.nextLevelRequirement;
        final beforePoints = pet.upgradePoints;
        pet = pet.upgrade();
        expect(beforePoints - beforeReq, equals(pet.upgradePoints));
      }

      expect(pet.level, 10);
      final multiplier = pet.getLevelUpgradeMultiplier(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(multiplier, closeTo(expectedMultiplier(10), 1e-9));
      final idle = pet.getCurrentIdlePerSec(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(idle, closeTo(0.3 * expectedMultiplier(10), 1e-9));
    });

    test('案例3：碎片不足時不可升級（Lv3 -> Lv4 需 5 碎片）', () {
      final pet = Pet(
        petKey: 'MooDeng',
        name: '彈跳豬',
        imagePath: 'assets/images/pets/moodeng_r.png',
        rarity: PetRarity.r,
        baseIdlePerSec: 0.2,
        level: 3,
        upgradePoints: 1, // 不足以升級（需要 5）
        isEquipped: false,
      );

      expect(pet.nextLevelRequirement, 5);
      expect(pet.canUpgrade, isFalse);
      expect(pet.upgrade(), equals(pet)); // 不應變動
    });

    test('案例4：重複抽到相同角色同稀有度 → 轉為 1 碎片（升級點數 +1）', () {
      final pet = Pet(
        petKey: 'PEPE',
        name: '佩佩蛙',
        imagePath: 'assets/images/pet/PEPE.png',
        rarity: PetRarity.ssr,
        baseIdlePerSec: 0.5,
        level: 1,
        upgradePoints: 0,
        isEquipped: false,
      );

      final after = pet.addUpgradePoints(1);
      expect(after.upgradePoints, 1);
      expect(after.level, 1);
    });

    test('案例5：升級後 idlePerSec 需即時提升', () {
      var pet = Pet(
        petKey: 'MooDeng',
        name: '彈跳豬',
        imagePath: 'assets/images/pets/moodeng_r.png',
        rarity: PetRarity.sr,
        baseIdlePerSec: 0.4,
        level: 1,
        upgradePoints: 2,
        isEquipped: false,
      );

      final before = pet.getCurrentIdlePerSec(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(pet.canUpgrade, isTrue);
      pet = pet.upgrade();
      final after = pet.getCurrentIdlePerSec(
        levelUpUpgradeBase,
        decayLevels,
        decayRate,
      );
      expect(after, greaterThan(before));
    });
  });
}
