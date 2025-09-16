import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/models/purchase_models.dart';
import 'package:idle_hippo/services/entitlement_manager.dart';
import 'package:idle_hippo/services/purchase_orchestrator.dart';
import 'package:idle_hippo/services/purchase_service.dart';
import 'package:idle_hippo/services/verify_client.dart';

class CountingPurchaseService implements PurchaseService {
  final StreamController<PurchaseEvent> _ctr =
      StreamController<PurchaseEvent>.broadcast(sync: true);

  int queryCount = 0;
  List<ProductInfo> canned = const [];

  @override
  Stream<PurchaseEvent> get purchaseStream => _ctr.stream;

  @override
  Future<List<ProductInfo>> queryProducts(List<String> ids) async {
    queryCount += 1;
    if (canned.isNotEmpty) return canned;
    return ids
        .map((id) => ProductInfo(
              id: id,
              name: 'P-$id',
              desc: 'D-$id',
              image: 'assets/images/store/$id.png',
              price: 1.0,
              currency: 'USD',
            ))
        .toList();
  }

  @override
  Future<void> buy(String productId) async {
    // 立即回推成功事件模擬 IAP 成功
    _ctr.add(PurchaseEvent(productId: productId, status: PurchaseStatus.success));
  }

  @override
  Future<void> restore() async {
    // 模擬恢復回推一筆 card_click_perm
    _ctr.add(const PurchaseEvent(
        productId: 'store.card_click_perm',
        status: PurchaseStatus.success,
        message: 'restored'));
  }

  @override
  void dispose() {
    _ctr.close();
  }
}

void main() {
  setUpAll(() async {
    // 載入 config（含 store.json）
    await ConfigService().initialize();
  });

  test('查價快取：同一批不重複 queryProducts', () async {
    final ps = CountingPurchaseService();
    final verify = MockVerifyClient();
    final em = MockEntitlementManager();

    final orch = PurchaseOrchestrator(
      configService: ConfigService(),
      purchaseService: ps,
      verifyClient: verify,
      entitlementManager: em,
    );

    final ids = ['store.card_click_perm', 'store.card_idle_perm'];
    final first = await orch.preloadCatalogPrices(ids);
    expect(first.length, 2);
    expect(ps.queryCount, 1);

    final second = await orch.preloadCatalogPrices(ids);
    expect(second.length, 2);
    expect(ps.queryCount, 1, reason: '第二次不應再呼叫 queryProducts');

    orch.dispose();
    ps.dispose();
  });

  test('購買成功：驗證 ok=true 會授予 entitlement 並推播 success', () async {
    final ps = CountingPurchaseService();
    final verify = MockVerifyClient();
    verify.next = const VerifyResult(ok: true);
    final em = MockEntitlementManager();

    final orch = PurchaseOrchestrator(
      configService: ConfigService(),
      purchaseService: ps,
      verifyClient: verify,
      entitlementManager: em,
    );

    final states = <String>[];
    final sub = orch.stateStream.listen((s) => states.add(s.type));

    await orch.purchase('store.card_click_perm');

    // 等待事件串完
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(em.granted, contains('card_click_perm'));
    expect(states, contains('success'));

    await sub.cancel();
    orch.dispose();
    ps.dispose();
  });

  test('購買失敗（驗證失敗）：不授權並推播 error(verify_failed)', () async {
    final ps = CountingPurchaseService();
    final verify = MockVerifyClient();
    verify.next = const VerifyResult(ok: false, reason: 'sku_not_allowed');
    final em = MockEntitlementManager();

    final orch = PurchaseOrchestrator(
      configService: ConfigService(),
      purchaseService: ps,
      verifyClient: verify,
      entitlementManager: em,
    );

    OrchestratorState? last;
    final sub = orch.stateStream.listen((s) => last = s);

    await orch.purchase('store.card_click_perm');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(em.granted, isEmpty);
    expect(last, isNotNull);
    expect(last!.type, 'error');
    expect(last!.code, 'verify_failed');

    await sub.cancel();
    orch.dispose();
    ps.dispose();
  });

  test('恢復流程（non-consumable）：收到成功事件會授權並 success', () async {
    final ps = CountingPurchaseService();
    final verify = MockVerifyClient();
    final em = MockEntitlementManager();

    final orch = PurchaseOrchestrator(
      configService: ConfigService(),
      purchaseService: ps,
      verifyClient: verify,
      entitlementManager: em,
    );

    OrchestratorState? last;
    final sub = orch.stateStream.listen((s) => last = s);

    await orch.restoreNonConsumables();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(em.granted, contains('card_click_perm'));
    expect(last, isNotNull);
    expect(last!.type, 'success');

    await sub.cancel();
    orch.dispose();
    ps.dispose();
  });
}
