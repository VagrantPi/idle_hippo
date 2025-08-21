import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/equipment_service.dart';

void main() {
  group('Equipment dependencies (requires)', () {
    final svc = EquipmentService();

    setUp(() {
      svc.setTapEquipmentsForTest([
        {
          'id': 'rgb_keyboard',
          'type': 'tap',
          'max_level': 10,
          'levels': [
            {'level': 1, 'cost': 10, 'bonus': 1},
            {'level': 2, 'cost': 20, 'bonus': 1},
            {'level': 3, 'cost': 30, 'bonus': 1},
          ],
        },
        {
          'id': 'faceMask',
          'type': 'tap',
          'requires': {'id': 'rgb_keyboard', 'level': 3},
          'max_level': 10,
          'levels': [
            {'level': 1, 'cost': 10, 'bonus': 1},
          ],
        },
      ]);
    });

    tearDown(() {
      svc.clearTestOverrides();
    });

    test('locked when prerequisite not met', () {
      var state = GameState.initial(1).copyWith(memePoints: 100.0);
      // prerequisite not met (rgb level 0)
      expect(svc.isUnlockedBy(state.equipments, 'faceMask'), false);
      expect(svc.canUpgrade(state, 'faceMask'), false);

      // even calling upgrade should not change state
      final next = svc.upgrade(state, 'faceMask');
      expect(next, state);
    });

    test('unlocked after reaching prerequisite', () {
      var state = GameState.initial(1).copyWith(memePoints: 100.0);
      // upgrade rgb_keyboard to level 3: costs 10 + 20 + 30 = 60
      state = svc.upgrade(state, 'rgb_keyboard');
      state = svc.upgrade(state, 'rgb_keyboard');
      state = svc.upgrade(state, 'rgb_keyboard');

      expect(svc.isUnlockedBy(state.equipments, 'faceMask'), true);
      expect(svc.canUpgrade(state, 'faceMask'), true);

      final beforeMp = state.memePoints;
      state = svc.upgrade(state, 'faceMask');
      // cost 10 for faceMask lv1
      expect(state.memePoints, beforeMp - 10);
      expect(state.equipments['faceMask'], 1);
    });
  });
}
