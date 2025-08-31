import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/equipment_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';

void main() {
  // 測試環境初始化（避免未初始化的 Binding 與平台通道）
  TestWidgetsFlutterBinding.ensureInitialized();
  group('裝備相依關係（requires）', () {
    final svc = EquipmentService();

    setUp(() async {
      // 以測試模式初始化 GameStateService，避免 secure storage 寫入
      await GameStateService().initializeForTest(GameState.initial(1));
      svc.setTapEquipmentsForTest([
        {
          'id': 'rgbKeyboard',
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
          'requires': {'id': 'rgbKeyboard', 'level': 3},
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

    test('未達前置條件時應為鎖定', () {
      var state = GameState.initial(1).copyWith(memePoints: 100.0);
      // prerequisite not met (rgb level 0)
      expect(svc.isUnlockedBy(state.equipments, 'faceMask'), false);
      expect(svc.canUpgrade(state, 'faceMask'), false);

      // even calling upgrade should not change state
      final next = svc.upgrade(state, 'faceMask');
      expect(next, state);
    });

    test('達到前置條件後應解鎖', () {
      var state = GameState.initial(1).copyWith(memePoints: 100.0);
      // upgrade rgbKeyboard to level 3: costs 10 + 20 + 30 = 60
      state = svc.upgrade(state, 'rgbKeyboard');
      state = svc.upgrade(state, 'rgbKeyboard');
      state = svc.upgrade(state, 'rgbKeyboard');

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
