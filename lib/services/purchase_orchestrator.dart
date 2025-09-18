import 'dart:async';

import '../models/purchase_models.dart';
import 'config_service.dart';
import 'entitlement_manager.dart';
import 'purchase_service.dart';
import 'verify_client.dart';

/// Orchestrator 狀態
class OrchestratorState {
  final String type; // loading | purchasing | verifying | success | error
  final String? productId;
  final String? orderId;
  final String? code; // verify_failed 等
  final String? message;

  const OrchestratorState._(
      {required this.type,
      this.productId,
      this.orderId,
      this.code,
      this.message});

  factory OrchestratorState.loading() => const OrchestratorState._(type: 'loading');
  factory OrchestratorState.purchasing(String productId) =>
      OrchestratorState._(type: 'purchasing', productId: productId);
  factory OrchestratorState.verifying({String? orderId}) =>
      OrchestratorState._(type: 'verifying', orderId: orderId);
  factory OrchestratorState.success(String productId) =>
      OrchestratorState._(type: 'success', productId: productId);
  factory OrchestratorState.error(String code, String message) =>
      OrchestratorState._(type: 'error', code: code, message: message);
}

/// IAP 流程協調器（Orchestrator）
class PurchaseOrchestrator {
  final ConfigService _configService;
  final PurchaseService _purchaseService;
  final VerifyClient _verifyClient;
  final EntitlementManager _entitlementManager;

  final StreamController<OrchestratorState> _stateCtr =
      StreamController<OrchestratorState>.broadcast(sync: true);
  StreamSubscription<PurchaseEvent>? _purchaseSub;

  // 以 productId 為 key 的商品資訊快取
  final Map<String, ProductInfo> _priceCache = <String, ProductInfo>{};

  // 恢復模式旗標：僅在 restoreNonConsumables 時為 true
  bool _restoring = false;

  bool _disposed = false;

  Stream<OrchestratorState> get stateStream => _stateCtr.stream;

  PurchaseOrchestrator({
    required ConfigService configService,
    required PurchaseService purchaseService,
    required VerifyClient verifyClient,
    required EntitlementManager entitlementManager,
  })  : _configService = configService,
        _purchaseService = purchaseService,
        _verifyClient = verifyClient,
        _entitlementManager = entitlementManager {
    // 監聽底層購買事件
    _purchaseSub = _purchaseService.purchaseStream.listen(_onPurchaseEvent);
  }

  /// 將 storeId 轉為 skuId（目前先 1:1 映射；若未來 config 有 sku_id 欄位再調整）
  String _toSkuId(String storeId) {
    return storeId; // MVP: 直接使用同一 ID
  }

  /// 查價快取：對已存在於快取的商品不重複查詢
  Future<List<ProductInfo>> preloadCatalogPrices(List<String> storeIds) async {
    final ids = storeIds.map(_toSkuId).toList();
    final missing = <String>[];
    for (final id in ids) {
      if (!_priceCache.containsKey(id)) missing.add(id);
    }
    if (missing.isNotEmpty) {
      final list = await _purchaseService.queryProducts(missing);
      for (final p in list) {
        _priceCache[p.id] = p;
      }
    }
    // 回傳所請求的商品資訊（來自快取或新查詢）
    return ids.map((id) => _priceCache[id]).whereType<ProductInfo>().toList();
  }

  /// 觸發購買流程
  Future<void> purchase(String storeId) async {
    if (_disposed) return;
    final skuId = _toSkuId(storeId);
    _stateCtr.add(OrchestratorState.purchasing(skuId));
    await _purchaseService.buy(skuId);
    // 後續由 _onPurchaseEvent 處理
  }

  /// 恢復購買（iOS 必備）。僅針對 non-consumable 進行權益套用。
  Future<void> restoreNonConsumables() async {
    if (_disposed) return;
    _restoring = true;
    try {
      await _purchaseService.restore();
    } finally {
      // 讓 onEvent 能在本輪事件流處理完之前仍視為 restoring
      // 在第一個成功事件處理後關閉 restoring
      // 這裡不立即還原旗標，交由事件處理端決定
    }
  }

  Future<void> _onPurchaseEvent(PurchaseEvent event) async {
    if (_disposed) return;

    switch (event.status) {
      case PurchaseStatus.success:
        if (_restoring) {
          // 僅針對 non-consumable 嘗試權益發放
          if (_isNonConsumable(event.productId)) {
            final entitlement = _entitlementKeyFor(event.productId);
            await _entitlementManager.grant(skuId: entitlement);
            _stateCtr.add(OrchestratorState.success(event.productId));
          }
          // 單輪恢復後即退出恢復模式（若有多筆也逐筆處理）
          _restoring = false;
        } else {
          // 正常購買流程：需進行驗證
          _stateCtr.add(OrchestratorState.verifying(orderId: null));
          try {
            // 目前沒有實際 orderId，先給一個 placeholder
            final verify = await _verifyClient.verify(
              skuId: event.productId,
              orderId: 'mock-order',
            );
            if (verify.ok) {
              final entitlement = _entitlementKeyFor(event.productId);
              await _entitlementManager.grant(skuId: entitlement, orderId: 'mock-order');
              _stateCtr.add(OrchestratorState.success(event.productId));
            } else {
              _stateCtr.add(OrchestratorState.error('verify_failed',
                  verify.reason ?? 'verify not ok'));
            }
          } catch (e) {
            _stateCtr.add(OrchestratorState.error('verify_exception', '$e'));
          }
        }
        break;
      case PurchaseStatus.pending:
        _stateCtr.add(OrchestratorState.loading());
        break;
      case PurchaseStatus.canceled:
        _stateCtr.add(OrchestratorState.error('canceled', event.message ?? ''));
        break;
      case PurchaseStatus.error:
        _stateCtr.add(OrchestratorState.error('purchase_error', event.message ?? ''));
        break;
    }
  }

  bool _isNonConsumable(String productId) {
    final store = _configService.getStoreConfig();
    final cfg = store[productId] as Map<String, dynamic>?;
    if (cfg == null) return false;
    final type = cfg['purchase_limit_type'] as String?;
    final max = cfg['purchase_max_count'] as int?;
    return type == 'limited' && (max == null || max == 1);
  }

  String _entitlementKeyFor(String productId) {
    // 規格案例：store.card_click_perm => grant('card_click_perm')
    if (productId.startsWith('store.')) {
      return productId.substring('store.'.length);
    }
    return productId;
  }

  void dispose() {
    _disposed = true;
    _purchaseSub?.cancel();
    _stateCtr.close();
  }
}
