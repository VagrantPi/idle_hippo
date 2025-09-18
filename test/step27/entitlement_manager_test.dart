import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/entitlement_manager.dart';

void main() {
  group('EntitlementManager 冪等處理測試', () {
    late MockEntitlementManager entitlementManager;

    setUp(() {
      entitlementManager = MockEntitlementManager();
    });

    group('驗收需求 1: non-consumable 冪等', () {
      test('連續兩次 grant 同一 non-consumable 商品，只會處理一次', () async {
        const skuId = 'card_click_perm';
        const orderId = 'A';

        // 第一次發放
        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        
        // 驗證訂單已記錄且商品已發放
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);
        expect(entitlementManager.granted.contains(skuId), isTrue);
        expect(entitlementManager.granted.length, equals(1));

        // 第二次發放（應該被跳過）
        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        
        // 驗證仍然只有一次記錄，沒有重複觸發副作用
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);
        expect(entitlementManager.granted.length, equals(1));
      });
    });

    group('驗收需求 2: consumable 冪等', () {
      test('連續兩次 grant 同一 consumable 訂單，資源僅被加一次', () async {
        const skuId = 'card_click_2x_30m';
        const orderId = 'B';

        // 第一次發放
        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        
        // 驗證訂單已記錄且資源已發放
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);
        expect(entitlementManager.granted.contains(skuId), isTrue);
        final firstGrantCount = entitlementManager.granted.length;

        // 第二次發放（應該被跳過）
        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        
        // 驗證資源僅被加一次，orders.B 僅一筆
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);
        expect(entitlementManager.granted.length, equals(firstGrantCount));
      });

      test('不同 orderId 的相同 consumable 商品，都應該被處理', () async {
        const skuId = 'ticket_pet_single';
        const orderId1 = 'C1';
        const orderId2 = 'C2';

        // 第一次發放
        await entitlementManager.grant(skuId: skuId, orderId: orderId1);
        
        // 第二次發放（不同 orderId，應該被處理）
        await entitlementManager.grant(skuId: skuId, orderId: orderId2);
        
        // 驗證兩個訂單都已記錄
        expect(entitlementManager.hasGrantedOrder(orderId1), isTrue);
        expect(entitlementManager.hasGrantedOrder(orderId2), isTrue);
        // 同一商品可以發放多次（consumable）
        expect(entitlementManager.granted.where((item) => item == skuId).length, equals(2));
      });
    });

    group('驗收需求 3: 缺 orderId（恢復 non-consumable）', () {
      test('non-consumable 商品無 orderId 時仍能設置 entitlement 並具備冪等', () async {
        const skuId = 'card_idle_perm';

        // 第一次發放（無 orderId）
        await entitlementManager.grant(skuId: skuId);
        
        // 驗證商品已發放
        expect(entitlementManager.granted.contains(skuId), isTrue);
        final firstGrantCount = entitlementManager.granted.length;

        // 第二次發放（重複呼叫不再觸發）
        await entitlementManager.grant(skuId: skuId);
        
        // 驗證具備冪等性（重複呼叫不再觸發）
        expect(entitlementManager.granted.length, equals(firstGrantCount));
      });

      test('consumable 商品無 orderId 時每次都會處理', () async {
        const skuId = 'card_idle_2x_1h';

        // 第一次發放（無 orderId）
        await entitlementManager.grant(skuId: skuId);
        
        // 驗證商品已發放
        expect(entitlementManager.granted.contains(skuId), isTrue);
        final firstGrantCount = entitlementManager.granted.length;

        // 第二次發放（無 orderId，應該再次處理）
        await entitlementManager.grant(skuId: skuId);
        
        // 驗證狀態再次變化（consumable 可重複發放）
        expect(entitlementManager.granted.length, equals(firstGrantCount + 1));
      });
    });

    group('邊界情況測試', () {
      test('空字串 orderId 處理', () async {
        const skuId = 'test_sku';
        const orderId = '';

        await entitlementManager.grant(skuId: skuId, orderId: orderId);
        expect(entitlementManager.hasGrantedOrder(orderId), isTrue);
      });

      test('相同 skuId 不同 orderId 處理', () async {
        const skuId = 'test_sku';
        const orderId1 = 'order1';
        const orderId2 = 'order2';

        await entitlementManager.grant(skuId: skuId, orderId: orderId1);
        await entitlementManager.grant(skuId: skuId, orderId: orderId2);

        expect(entitlementManager.hasGrantedOrder(orderId1), isTrue);
        expect(entitlementManager.hasGrantedOrder(orderId2), isTrue);
        expect(entitlementManager.granted.length, equals(2));
      });
    });
  });
}
