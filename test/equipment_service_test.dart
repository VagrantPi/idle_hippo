import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/equipment_service.dart';
import 'package:idle_hippo/services/game_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final equipment = EquipmentService();

  setUp(() async {
    await GameStateService().initializeForTest(GameState.initial(1));
    equipment.setTapEquipmentsForTest([
      {
        'id': 'rgbKeyboard',
        'type': 'tap',
        'max_level': 10,
        'levels': [
          {'level': 1, 'cost': 10, 'bonus': 1},
          {'level': 2, 'cost': 20, 'bonus': 2},
          {'level': 3, 'cost': 30, 'bonus': 3},
          {'level': 4, 'cost': 50, 'bonus': 4},
          {'level': 5, 'cost': 80, 'bonus': 5},
        ],
      }
    ]);
  });

  tearDown(() {
    equipment.clearTestOverrides();
  });

  test('computeTapGain：無裝備時 base(1) + sumTapBonus(0) = 1', () {
    final state = GameState.initial(1);
    expect(equipment.computeTapGain(state), 1); // base=1 from assets/config/game.json
  });

  test('升級成功：扣除成本並提升等級', () {
    var state = GameState.initial(1).copyWith(memePoints: 15.0);
    expect(equipment.canUpgrade(state, 'rgbKeyboard'), true);

    state = equipment.upgrade(state, 'rgbKeyboard');

    expect(state.memePoints, 5.0); // 15 - cost(10)
    expect(state.equipments['rgbKeyboard'], 1);

    // cumulative bonus at Lv1 = 1
    expect(equipment.computeTapGain(state), 1 + 1);
  });

  test('連續升級至 Lv.3', () {
    var state = GameState.initial(1).copyWith(memePoints: 100.0);
    state = equipment.upgrade(state, 'rgbKeyboard'); // cost 10 -> lv1
    state = equipment.upgrade(state, 'rgbKeyboard'); // cost 20 -> lv2
    state = equipment.upgrade(state, 'rgbKeyboard'); // cost 30 -> lv3

    expect(state.memePoints, 100.0 - (10 + 20 + 30));
    // cumulative bonus at Lv3 = 1+2+3 = 6
    expect(equipment.computeTapGain(state), 1 + 6);
  });

  test('資源不足：無法升級', () {
    var state = GameState.initial(1).copyWith(memePoints: 19.0);
    // first ensure at level 1 already (so next cost is 20)
    state = equipment.upgrade(state.copyWith(memePoints: 29.0), 'rgbKeyboard'); // lv1, mp=19

    expect(equipment.canUpgrade(state, 'rgbKeyboard'), false);
    final next = equipment.upgrade(state, 'rgbKeyboard');
    expect(next, state); // unchanged
  });

  test('達最大等級：無法繼續升級', () {
    // make to level 5 quickly
    var state = GameState.initial(1).copyWith(memePoints: 1000.0);
    for (int i = 0; i < 5; i++) {
      state = equipment.upgrade(state, 'rgbKeyboard');
    }

    // cumulative bonus at Lv5 = 1+2+3+4+5 = 15
    expect(equipment.computeTapGain(state), 1 + 15);

    // next cost should be null when at or above max in this test (5)
    expect(equipment.getNextCost('rgbKeyboard', 5), null);

    final after = equipment.upgrade(state, 'rgbKeyboard');
    expect(after, state);
  });
}
