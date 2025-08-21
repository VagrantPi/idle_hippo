import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/decimal_utils.dart';
import 'package:idle_hippo/services/equipment_service.dart';

void main() {
  final equipment = EquipmentService();

  setUp(() {
    // 測試注入：建立一個裝備在 Lv1 提供 0.8 的加成
    equipment.setTapEquipmentsForTest([
      {
        'id': 'tester_item',
        'type': 'tap',
        'max_level': 1,
        'levels': [
          {'level': 1, 'cost': 0, 'bonus': 0.8},
        ],
      }
    ]);
  });

  tearDown(() {
    equipment.clearTestOverrides();
  });

  test('tap_gain=1.8 連續兩次後，memePoints 應近似 3.6', () {
    // Given: base=1（來自預設 game.json），+ 裝備加成 0.8 at Lv1
    var state = GameState.initial(1).copyWith(
      memePoints: 0.0,
      equipments: {'tester_item': 1},
    );

    final gain = equipment.computeTapGain(state); // 應為 1.8
    expect(gain, closeTo(1.8, 1e-9));

    // When: 連續兩次加總（用 DecimalUtils 處理十進位）
    var total = DecimalUtils.add(state.memePoints, gain);
    total = DecimalUtils.add(total, gain);

    // Then: 結果近似 3.6（避免浮點誤差）
    expect(total, closeTo(3.6, 1e-9));
  });
}
