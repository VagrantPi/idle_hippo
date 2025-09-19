import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:idle_hippo/services/config_service.dart';
import 'package:idle_hippo/services/entitlement_manager.dart';
import 'package:idle_hippo/services/pending_grant_store.dart';
import 'package:idle_hippo/services/purchase_orchestrator.dart';
import 'package:idle_hippo/services/purchase_service.dart';
import 'package:idle_hippo/services/verify_client.dart';
import 'package:idle_hippo/models/purchase_models.dart';

class SilentPurchaseService implements PurchaseService {
  final StreamController<PurchaseEvent> _ctr =
      StreamController<PurchaseEvent>.broadcast(sync: true);

  @override
  Stream<PurchaseEvent> get purchaseStream => _ctr.stream;

  @override
  Future<List<ProductInfo>> queryProducts(List<String> ids) async => const [];

  @override
  Future<void> buy(String productId) async {}

  @override
  Future<void> restore() async {}

  @override
  void dispose() {
    _ctr.close();
  }
}

void main() {
  setUpAll(() async {
    await ConfigService().initialize();
  });

  test('中斷後補發：onAppStart 會重新驗證並授權一次（冪等）', () async {
    final pendingStore = InMemoryPendingGrantStore();
    await pendingStore.save(const PendingGrant(
      skuId: 'store.card_click_perm',
      orderId: 'order_crash_001',
    ));

    final ps = SilentPurchaseService();
    final verify = MockVerifyClient()..next = const VerifyResult(ok: true);
    final em = MockEntitlementManager();

    final orch = PurchaseOrchestrator(
      configService: ConfigService(),
      purchaseService: ps,
      verifyClient: verify,
      entitlementManager: em,
      pendingGrantStore: pendingStore,
    );

    await orch.onAppStart();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(em.granted, contains('card_click_perm'));

    // 再次呼叫 onAppStart 不應重複發放
    final before = List<String>.from(em.granted);
    await orch.onAppStart();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(em.granted.length, before.length);

    orch.dispose();
    ps.dispose();
  });
}
