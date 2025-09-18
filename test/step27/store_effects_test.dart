import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/models/buff_models.dart';
import 'package:idle_hippo/models/game_state.dart';
import 'package:idle_hippo/services/entitlement_manager.dart';
import 'package:idle_hippo/services/game_state_service.dart';

/// Mock GameStateService 用於測試
class MockGameStateService implements GameStateService {
  @override
  ValueNotifier<GameState> gameState = ValueNotifier<GameState>(
    GameState.initial(1),
  );

  GameState _currentState = GameState.initial(1);

  @override
  GameState get currentState => _currentState;

  @override
  Future<void> initialize() async {
    // No-op for tests
  }

  @override
  Future<void> initializeForTest(GameState initialState) async {
    _currentState = initialState;
    gameState.value = initialState;
  }

  @override
  Future<void> updateGameState(
    GameState newState, {
    bool forceReplace = false,
    bool throwOnError = false,
  }) async {
    _currentState = newState;
    gameState.value = newState;
  }
}

void main() {
  // 初始化 Flutter 測試綁定，確保 rootBundle 可載入資產
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('商品效益完整測試', () {
    late EntitlementManagerImpl entitlementManager;
    late MockGameStateService gameStateService;

    setUp(() async {
      gameStateService = MockGameStateService();
      entitlementManager = EntitlementManagerImpl(
        gameStateService: gameStateService,
      );

      // 初始化測試環境
      await entitlementManager.init();
    });

    group('永久效果商品測試', () {
      test('點擊加成永久卡片', () async {
        const skuId = 'store.card_click_perm';
        const orderId = 'test_order_001';

        // 發放權益
        await entitlementManager.grant(skuId: skuId, orderId: orderId);

        // 驗證權益已發放
        expect(entitlementManager.hasEntitlement(skuId), isTrue);
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);

        // 驗證遊戲狀態更新
        final currentState = gameStateService.currentState;
        expect(currentState.buffs, isNotNull);
        expect(currentState.buffs!.permanent.clickBoost, equals(1.5));

        // 驗證點擊倍數計算
        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        final clickMultiplier = currentState.buffs!.getClickMultiplier(
          currentTimeMs,
        );
        expect(clickMultiplier, equals(1.5)); // +50% 加成
      });

      test('Idle 加成永久卡片', () async {
        const skuId = 'store.card_idle_perm';
        const orderId = 'test_order_002';

        await entitlementManager.grant(skuId: skuId, orderId: orderId);

        expect(entitlementManager.hasEntitlement(skuId), isTrue);

        final currentState = gameStateService.currentState;
        expect(currentState.buffs!.permanent.idleBoost, equals(1.2));

        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        final idleMultiplier = currentState.buffs!.getIdleMultiplier(
          currentTimeMs,
        );
        expect(idleMultiplier, equals(1.2)); // +20% 加成
      });

      test('離線時間永久擴展', () async {
        const skuId = 'store.card_offline_perm_6h';

        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.buffs!.permanent.offlineExtended, isTrue);

        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        final offlineCapHours = currentState.buffs!.getOfflineCapHours(
          currentTimeMs,
        );
        expect(offlineCapHours, equals(12)); // 基礎 6 小時 + 永久 6 小時
      });

      test('每日上限永久提升', () async {
        const skuId = 'store.card_cap_perm';

        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.buffs!.permanent.capIncreased, isTrue);

        final dailyCapMultiplier = currentState.buffs!.getDailyCapMultiplier();
        expect(dailyCapMultiplier, equals(1.5)); // +50% 加成
      });
    });

    group('限時效果商品測試', () {
      test('點擊 2x 限時卡片', () async {
        const skuId = 'store.card_click_2x_30m';
        const orderId = 'test_order_003';

        await entitlementManager.grant(skuId: skuId, orderId: orderId);

        final currentState = gameStateService.currentState;
        expect(currentState.buffs!.activeBuffs.length, equals(1));

        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('click_2x'));
        expect(buff.multiplier, equals(2.0));

        // 驗證 buff 未過期
        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        expect(buff.isExpired(currentTimeMs), isFalse);

        // 驗證倍數計算
        final clickMultiplier = currentState.buffs!.getClickMultiplier(
          currentTimeMs,
        );
        expect(clickMultiplier, equals(2.0));
      });

      test('Idle 2x 限時卡片', () async {
        const skuId = 'store.card_idle_2x_1h';

        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('idle_2x'));
        expect(buff.multiplier, equals(2.0));

        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        final idleMultiplier = currentState.buffs!.getIdleMultiplier(
          currentTimeMs,
        );
        expect(idleMultiplier, equals(2.0));
      });

      test('限時 buff 延長機制', () async {
        const skuId = 'store.card_click_2x_30m';

        // 第一次發放
        await entitlementManager.grant(skuId: skuId, orderId: 'order_001');

        final firstState = gameStateService.currentState;
        final firstBuff = firstState.buffs!.activeBuffs.first;
        final firstExpiresAt = firstBuff.expiresAtMs;

        // 等待一小段時間
        await Future.delayed(const Duration(milliseconds: 10));

        // 第二次發放（應該延長時間）
        await entitlementManager.grant(skuId: skuId, orderId: 'order_002');

        final secondState = gameStateService.currentState;
        expect(secondState.buffs!.activeBuffs.length, equals(1)); // 仍然只有一個 buff

        final secondBuff = secondState.buffs!.activeBuffs.first;
        expect(secondBuff.expiresAtMs, greaterThan(firstExpiresAt)); // 時間延長了
      });
    });

    group('即時效果商品測試', () {
      test('寵物抽獎券', () async {
        const skuId = 'store.ticket_pet_single';
        const initialTickets = 5;

        // 設定初始狀態
        final initialState = gameStateService.currentState.copyWith(
          petTickets: initialTickets,
        );
        await gameStateService.updateGameState(initialState);

        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.petTickets, equals(initialTickets + 1));
      });
    });

    group('組合包商品測試', () {
      test('每日禮包', () async {
        const skuId = 'store.pack_daily';
        const initialPoints = 100.0;
        const initialTickets = 1;

        final initialState = gameStateService.currentState.copyWith(
          memePoints: initialPoints,
          petTickets: initialTickets,
        );
        await gameStateService.updateGameState(initialState);

        final grantTime = DateTime.now().millisecondsSinceEpoch;
        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.memePoints, equals(initialPoints + 300));
        expect(currentState.petTickets, equals(initialTickets + 2));
        expect(currentState.buffs!.activeBuffs.length, equals(1));

        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('idle_2x'));
        expect(buff.multiplier, equals(2.0));
        final expectedDurationMs = 30 * 60 * 1000;
        final actualDuration = buff.expiresAtMs - grantTime;
        expect(
          actualDuration,
          inInclusiveRange(expectedDurationMs, expectedDurationMs + 5000),
        );
      });

      test('每月禮包', () async {
        const skuId = 'store.pack_monthly';
        const initialPoints = 500.0;
        const initialTickets = 3;

        final initialState = gameStateService.currentState.copyWith(
          memePoints: initialPoints,
          petTickets: initialTickets,
        );
        await gameStateService.updateGameState(initialState);

        final grantTime = DateTime.now().millisecondsSinceEpoch;
        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.memePoints, equals(initialPoints + 3000));
        expect(currentState.petTickets, equals(initialTickets + 22));
        expect(currentState.buffs!.activeBuffs.length, equals(1));

        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('idle_2x'));
        expect(buff.multiplier, equals(2.0));
        final expectedDurationMs = 24 * 60 * 60 * 1000;
        final actualDuration = buff.expiresAtMs - grantTime;
        expect(
          actualDuration,
          inInclusiveRange(expectedDurationMs, expectedDurationMs + 10000),
        );
      });

      test('新手 7 日禮包', () async {
        const skuId = 'store.pack_7n_starter';
        const initialPoints = 200.0;
        const initialTickets = 0;

        final initialState = gameStateService.currentState.copyWith(
          memePoints: initialPoints,
          petTickets: initialTickets,
        );
        await gameStateService.updateGameState(initialState);

        final grantTime = DateTime.now().millisecondsSinceEpoch;
        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.memePoints, equals(initialPoints + 1000));
        expect(currentState.petTickets, equals(initialTickets + 11));
        expect(currentState.buffs!.activeBuffs.length, equals(1));

        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('idle_2x'));
        expect(buff.multiplier, equals(2.0));
        final expectedDurationMs = 24 * 60 * 60 * 1000;
        final actualDuration = buff.expiresAtMs - grantTime;
        expect(
          actualDuration,
          inInclusiveRange(expectedDurationMs, expectedDurationMs + 10000),
        );
      });

      test('新手 30 日禮包', () async {
        const skuId = 'store.pack_30n_starter';
        const initialPoints = 400.0;
        const initialTickets = 5;

        final initialState = gameStateService.currentState.copyWith(
          memePoints: initialPoints,
          petTickets: initialTickets,
        );
        await gameStateService.updateGameState(initialState);

        final grantTime = DateTime.now().millisecondsSinceEpoch;
        await entitlementManager.grant(skuId: skuId);

        final currentState = gameStateService.currentState;
        expect(currentState.memePoints, equals(initialPoints + 5000));
        expect(currentState.petTickets, equals(initialTickets + 33));
        expect(currentState.buffs!.activeBuffs.length, equals(1));

        final buff = currentState.buffs!.activeBuffs.first;
        expect(buff.type, equals('idle_2x'));
        expect(buff.multiplier, equals(2.0));
        final expectedDurationMs = 120 * 60 * 60 * 1000;
        final actualDuration = buff.expiresAtMs - grantTime;
        expect(
          actualDuration,
          inInclusiveRange(expectedDurationMs, expectedDurationMs + 10000),
        );
      });
    });

    group('冪等性和錯誤處理', () {
      test('重複發放永久商品', () async {
        const skuId = 'store.card_click_perm';
        const orderId = 'test_order_duplicate';

        // 第一次發放
        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        expect(entitlementManager.hasEntitlement(skuId), isTrue);

        final firstState = gameStateService.currentState;
        final firstClickBoost = firstState.buffs!.permanent.clickBoost;

        // 第二次發放（相同 orderId，應該被跳過）
        await entitlementManager.grant(skuId: skuId, orderId: orderId);

        final secondState = gameStateService.currentState;
        expect(
          secondState.buffs!.permanent.clickBoost,
          equals(firstClickBoost),
        );
      });

      test('不存在的商品 SKU', () async {
        const skuId = 'store.non_existent_item';

        await entitlementManager.grant(skuId: skuId);

        // 應該不會拋出異常，但也不會有任何效果
        expect(entitlementManager.hasEntitlement(skuId), isFalse);
      });

      test('清理過期 buff', () async {
        // 創建一個已過期的 buff
        final expiredBuff = TimedBuff(
          type: 'click_2x',
          multiplier: 2.0,
          expiresAtMs: DateTime.now().millisecondsSinceEpoch - 1000, // 1秒前過期
        );

        final stateWithExpiredBuff = gameStateService.currentState.copyWith(
          buffs: BuffState(activeBuffs: [expiredBuff]),
        );
        await gameStateService.updateGameState(stateWithExpiredBuff);

        // 清理過期 buff
        await entitlementManager.cleanupExpiredBuffs();

        final cleanedState = gameStateService.currentState;
        expect(cleanedState.buffs!.activeBuffs.isEmpty, isTrue);
      });
    });

    group('複合效果測試', () {
      test('永久 + 限時效果疊加', () async {
        // 發放永久點擊加成
        await entitlementManager.grant(skuId: 'store.card_click_perm');

        // 發放限時點擊加成
        await entitlementManager.grant(skuId: 'store.card_click_2x_30m');

        final currentState = gameStateService.currentState;
        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;

        // 驗證效果疊加：永久 1.5x * 限時 2x = 3x
        final totalMultiplier = currentState.buffs!.getClickMultiplier(
          currentTimeMs,
        );
        expect(totalMultiplier, equals(3.0));
      });

      test('多個限時效果疊加', () async {
        // 發放點擊限時加成
        await entitlementManager.grant(
          skuId: 'store.card_click_2x_30m',
          orderId: 'order_1',
        );

        // 發放 Idle 限時加成
        await entitlementManager.grant(
          skuId: 'store.card_idle_2x_1h',
          orderId: 'order_2',
        );

        final currentState = gameStateService.currentState;
        expect(currentState.buffs!.activeBuffs.length, equals(2));

        final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
        expect(
          currentState.buffs!.getClickMultiplier(currentTimeMs),
          equals(2.0),
        );
        expect(
          currentState.buffs!.getIdleMultiplier(currentTimeMs),
          equals(2.0),
        );
      });
    });
  });
}
