import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/equipment_service.dart';
import 'package:idle_hippo/services/idle_income_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Step 9 - Idle Equipment Integration Tests', () {
    late ConfigService configService;
    late EquipmentService equipmentService;
    late IdleIncomeService idleIncomeService;

    setUpAll(() async {
      configService = ConfigService();
      await configService.loadConfig();
      equipmentService = EquipmentService();
      idleIncomeService = IdleIncomeService();
      idleIncomeService.enableTestingMode(true);
      idleIncomeService.init(
        onIncomeGenerated: (_) {},
      );
    });

    setUp(() {
      // 重置服務狀態
      idleIncomeService.resetStats();
    });

    test('放置裝備資料載入正確', () async {
      final idleEquipments = equipmentService.listIdleEquipments();
      
      expect(idleEquipments.length, 3);
      
      // 驗證 Youtube
      final youtube = idleEquipments.firstWhere((e) => e['id'] == 'youtube');
      expect(youtube['name_key'], 'equip.youtube.name');
      expect(youtube.containsKey('levels'), isTrue);
      
      // 驗證 BTC
      final btc = idleEquipments.firstWhere((e) => e['id'] == 'btc');
      expect(btc['name_key'], 'equip.btc.name');
      expect(btc.containsKey('levels'), isTrue);
      
      // 驗證 DOGE
      final doge = idleEquipments.firstWhere((e) => e['id'] == 'doge');
      expect(doge['name_key'], 'equip.doge.name');
      expect(doge.containsKey('levels'), isTrue);
    });

    test('放置裝備解鎖條件驗證', () {
      // 初始狀態：所有裝備都未解鎖
      final initialState = GameState.initial(1);
      
      // youtube 無解鎖條件（unlock=null），預設已解鎖
      expect(equipmentService.isIdleEquipmentUnlocked(initialState.equipments, 'youtube'), true);
      expect(equipmentService.isIdleEquipmentUnlocked(initialState.equipments, 'btc'), false);
      expect(equipmentService.isIdleEquipmentUnlocked(initialState.equipments, 'doge'), false);
      
      // 升級點擊裝備到足夠等級（若有依賴）
      var state = initialState;
      
      // 解鎖 BTC 的條件需 youtube Lv.3（依 config）
      // 先補足資源，再升級 youtube 到 Lv.3
      state = state.copyWith(memePoints: 1e9);
      for (int i = 0; i < 3; i++) {
        state = equipmentService.upgradeIdle(state, 'youtube');
      }
      expect(equipmentService.isIdleEquipmentUnlocked(state.equipments, 'youtube'), true);
      expect(equipmentService.isIdleEquipmentUnlocked(state.equipments, 'btc'), true);
      
      expect(equipmentService.isIdleEquipmentUnlocked(state.equipments, 'doge'), false);
      
      // 升級 BTC 到 3 級解鎖 DOGE
      for (int i = 0; i < 3; i++) {
        state = equipmentService.upgradeIdle(state, 'btc');
      }
      expect(equipmentService.isIdleEquipmentUnlocked(state.equipments, 'doge'), true);
    });

    test('放置裝備升級與成本計算', () {
      var state = GameState.initial(1);
      
      // youtube 無解鎖條件；補資源以便升級
      state = state.copyWith(memePoints: 1e9);
      
      // 驗證 Youtube 初始成本
      final initialCost = equipmentService.getIdleNextCost('youtube', 0);
      expect(initialCost, 10);
      
      // 升級 Youtube 到 1 級
      state = equipmentService.upgradeIdle(state, 'youtube');
      expect(state.equipments['youtube'], 1);
      
      // 驗證升級後成本
      final nextCost = equipmentService.getIdleNextCost('youtube', 1);
      expect(nextCost, 20);
      
      // 驗證加成計算
      final bonus = equipmentService.cumulativeIdleBonusFor('youtube', 1);
      expect(bonus, closeTo(0.1, 1e-9));
    });

    test('放置裝備加成整合到 IdleIncomeService', () {
      var state = GameState.initial(1);
      
      // 補資源並升級 Youtube
      state = state.copyWith(memePoints: 1e9);
      state = equipmentService.upgradeIdle(state, 'youtube');
      
      // 更新 IdleIncomeService 的 GameState 參考
      idleIncomeService.updateGameState(state);
      
      // 驗證放置收益包含裝備加成
      final idlePerSec = idleIncomeService.currentIdlePerSec;
      expect(idlePerSec, greaterThan(0.0)); // 至少大於 0（有 youtube Lv.1 的 0.1）
      
      // 再升級一級 Youtube
      state = equipmentService.upgradeIdle(state, 'youtube');
      idleIncomeService.updateGameState(state);
      
      final newIdlePerSec = idleIncomeService.currentIdlePerSec;
      expect(newIdlePerSec, greaterThan(idlePerSec)); // 應該更高
    });

    test('多個放置裝備加成累積', () {
      var state = GameState.initial(1);
      
      // 補資源並解鎖 BTC（需 youtube Lv.3）
      state = state.copyWith(memePoints: 1e9);
      for (int i = 0; i < 3; i++) {
        state = equipmentService.upgradeIdle(state, 'youtube');
      }
      
      // 升級所有放置裝備（先確保 BTC 達 Lv.3 才能升 DOGE）
      state = equipmentService.upgradeIdle(state, 'youtube');
      for (int i = 0; i < 3; i++) {
        state = equipmentService.upgradeIdle(state, 'btc');
      }
      state = equipmentService.upgradeIdle(state, 'doge');
      
      // 驗證總加成
      final totalBonus = equipmentService.sumIdleBonus(state);
      expect(totalBonus, greaterThan(0.2)); // 至少三個裝備各 0.1
      
      // 更新 IdleIncomeService 並驗證
      idleIncomeService.updateGameState(state);
      final idlePerSec = idleIncomeService.currentIdlePerSec;
      expect(idlePerSec, greaterThan(0.2));
    });

    test('放置裝備收益隨時間累積', () {
      var state = GameState.initial(1);
      
      // 補資源並升級 Youtube Lv.1
      state = state.copyWith(memePoints: 1e6);
      state = equipmentService.upgradeIdle(state, 'youtube');
      
      idleIncomeService.updateGameState(state);
      
      // 模擬時間推進（測試模式下手動 tick）
      idleIncomeService.resetStats();
      // 推進 10 秒
      for (int i = 0; i < 10; i++) {
        idleIncomeService.onTickForTest(1.0);
      }
      
      // 驗證收益累積（使用服務內部統計）
      final totalIncome = idleIncomeService.totalIdleIncome;
      expect(totalIncome, greaterThan(0.9)); // 約 1.0 (0.1/秒 * 10秒)
    });

    test('放置裝備最大等級限制', () {
      var state = GameState.initial(1);
      
      // 解鎖 Youtube
      state = state.copyWith(memePoints: 1e9);
      
      // 升級到最大等級
      final maxLevel = 10; // 根據設定檔
      for (int i = 0; i < maxLevel; i++) {
        state = equipmentService.upgradeIdle(state, 'youtube');
      }
      
      expect(state.equipments['youtube'], maxLevel);
      
      // 驗證無法繼續升級
      final nextCost = equipmentService.getIdleNextCost('youtube', maxLevel);
      expect(nextCost, isNull);
    });
  });
}
