import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/equipment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EquipmentService default levels fallback', () {
    setUp(() async {
      // 確保資產可被載入（測試環境需要註冊 asset bundle）
      // 大多數專案使用 flutter_test 預設的資產設定，這裡直接呼叫 loadConfig。
      await ConfigService().loadConfig();
    });

    tearDown(() {
      EquipmentService().clearTestOverrides();
    });

    test('tap：未提供 levels 時，累積加成與下一級成本會回退 default_tap_levels', () async {
      final svc = EquipmentService();

      // 使用測試注入的 tap 裝備（不含 levels）
      svc.setTapEquipmentsForTest([
        {
          'id': 't_tap',
          'icon': 'assets/images/equipment/RGBKeyboard.png',
          'name_key': 'equip.rgbKeyboard.name',
          'type': 'tap',
          'max_level': 10,
          // 無 levels，應回退 default_tap_levels
        },
      ]);

      // level 0 累積 = 0
      expect(svc.cumulativeBonusFor('t_tap', 0), closeTo(0.0, 1e-9));
      // level 1 累積 = 1（來自 default_tap_levels 第 1 級）
      expect(svc.cumulativeBonusFor('t_tap', 1), closeTo(1.0, 1e-9));
      // 下一級成本（從 0 → 1）= 10（default_tap_levels 第 1 級 cost）
      expect(svc.getNextCost('t_tap', 0), 10);
    });

    test('idle：未提供 levels 時，累積加成與下一級成本會回退 default_idle_levels', () async {
      final svc = EquipmentService();

      // 使用測試注入的 idle 裝備（不含 levels）
      svc.setIdleEquipmentsForTest([
        {
          'id': 't_idle',
          'icon': 'assets/images/equipment/YouTube.png',
          'name_key': 'equip.youtube.name',
          'type': 'idle',
          'unlock': null,
          'max_level': 10,
          // 無 levels，應回退 default_idle_levels
        },
      ]);

      // level 0 累積 = 0
      expect(svc.cumulativeIdleBonusFor('t_idle', 0), closeTo(0.0, 1e-9));
      // level 1 累積 = 0.1（default_idle_levels 第 1 級）
      expect(svc.cumulativeIdleBonusFor('t_idle', 1), closeTo(0.1, 1e-9));
      // 下一級成本（從 0 → 1）= 10（default_idle_levels 第 1 級 cost）
      expect(svc.getIdleNextCost('t_idle', 0), 10);
    });
  });
}
