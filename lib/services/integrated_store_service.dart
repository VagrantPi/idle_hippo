import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/purchase_models.dart';
import '../services/config_service.dart';
import '../services/secure_save_service.dart';
import '../services/purchase_repository.dart';
import '../services/purchase_limiter.dart';
import '../services/purchase_service.dart';
import '../services/mock_purchase_service.dart';
import '../services/mock_rewarded_ad_service.dart';
import '../services/entitlement_manager.dart';
import '../services/purchase_limit_policy.dart';
import '../services/game_state_service.dart';

/// 整合的商城服務
///
/// 結合新的購買抽象層與現有的商城功能
/// 提供統一的商城操作介面
class IntegratedStoreService extends ChangeNotifier {
  static final IntegratedStoreService _instance =
      IntegratedStoreService._internal();
  factory IntegratedStoreService() => _instance;
  IntegratedStoreService._internal();

  /// 測試用生成式建構子，建立非單例的新實例，避免使用到已 dispose 的單例
  @visibleForTesting
  IntegratedStoreService.testable();

  late ConfigService _configService;
  late PurchaseRepository _repository;
  late PurchaseLimiter _limiter;
  late PurchaseService _purchaseService;
  late RewardedAdService _rewardedAdService;
  late GameStateService _gameStateService;
  late EntitlementManager _entitlementManager;

  StreamSubscription<PurchaseEvent>? _purchaseSubscription;
  bool _initialized = false;
  bool _disposed = false;

  bool get isInitialized => _initialized;

  /// 初始化服務
  Future<void> initialize({
    ConfigService? configService,
    SecureSaveService? saveService,
    bool useMockServices = true,
    GameStateService? gameStateService,
    EntitlementManager? entitlementManager,
  }) async {
    if (_initialized) return;

    _disposed = false;
    _configService = configService ?? ConfigService();
    _repository = PurchaseRepository();
    _limiter = PurchaseLimiterImpl(_configService, _repository);

    // 遊戲狀態與權益管理（確保購買後能發放效果）
    _gameStateService = gameStateService ?? GameStateService();
    await _gameStateService.initialize();
    _entitlementManager = entitlementManager ??
        EntitlementManagerImpl(gameStateService: _gameStateService);
    await _entitlementManager.init();

    // 根據參數決定使用 Mock 或真實服務
    if (useMockServices) {
      _purchaseService = MockPurchaseService();
      _rewardedAdService = MockRewardedAdService();
    } else {
      // 未來可以切換為真實 IAP 服務
      _purchaseService = MockPurchaseService();
      _rewardedAdService = MockRewardedAdService();
    }

    // 監聽購買事件
    _purchaseSubscription = _purchaseService.purchaseStream.listen(
      _onPurchaseEvent,
    );

    _initialized = true;
  }

  /// 取得商品可購買狀態
  Future<PurchaseAvailability> getAvailability(String productId) async {
    if (!_initialized) {
      // 服務未初始化時，返回不可購買狀態
      return const PurchaseAvailability(
        false,
        reasonKey: 'store.not_initialized',
      );
    }

    try {
      final nowLocal = _getCurrentTaipeiTime();
      return await _limiter.availability(productId, nowLocal);
    } catch (e) {
      // 發生錯誤時返回不可購買狀態
      return const PurchaseAvailability(false, reasonKey: 'store.error');
    }
  }

  /// 購買商品
  Future<void> buyProduct(String productId) async {
    if (!_initialized) {
      throw Exception('IntegratedStoreService not initialized');
    }

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;

    if (productConfig == null) {
      throw Exception('Product not found: $productId');
    }

    final adsPay = productConfig['ads_pay'] as bool? ?? false;

    if (adsPay) {
      // 廣告購買
      final result = await _rewardedAdService.show(
        'store_item',
        productId: productId,
      );
      if (result == RewardedStatus.rewarded) {
        // 廣告成功，觸發購買成功事件
        await _onPurchaseEvent(
          PurchaseEvent(
            productId: productId,
            status: PurchaseStatus.success,
            message: 'Rewarded ad completed',
          ),
        );
      } else {
        // 廣告失敗或取消
        await _onPurchaseEvent(
          PurchaseEvent(
            productId: productId,
            status: PurchaseStatus.canceled,
            message: 'Rewarded ad not completed',
          ),
        );
      }
    } else {
      // IAP 購買
      await _purchaseService.buy(productId);
    }
  }

  /// 強制使用 IAP 流程（不看 ads_pay 設定）
  Future<void> buyProductViaIap(String productId) async {
    if (!_initialized) {
      throw Exception('IntegratedStoreService not initialized');
    }

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) {
      throw Exception('Product not found: $productId');
    }

    await _purchaseService.buy(productId);
  }

  /// 強制使用廣告流程（不看 ads_pay 設定）
  Future<void> buyProductViaAd(String productId) async {
    if (!_initialized) {
      throw Exception('IntegratedStoreService not initialized');
    }

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) {
      throw Exception('Product not found: $productId');
    }

    final result = await _rewardedAdService.show(
      'store_item',
      productId: productId,
    );
    if (result == RewardedStatus.rewarded) {
      await _onPurchaseEvent(
        PurchaseEvent(
          productId: productId,
          status: PurchaseStatus.success,
          message: 'Rewarded ad completed',
        ),
      );
    } else {
      await _onPurchaseEvent(
        PurchaseEvent(
          productId: productId,
          status: PurchaseStatus.canceled,
          message: 'Rewarded ad not completed',
        ),
      );
    }
  }

  /// 恢復購買
  Future<void> restorePurchases() async {
    await _purchaseService.restore();
  }

  /// 查詢商品資訊
  Future<List<ProductInfo>> queryProducts(List<String> productIds) async {
    return await _purchaseService.queryProducts(productIds);
  }

  /// 取得商品購買記錄
  Future<PurchaseRecord?> getPurchaseRecord(String productId) async {
    return await _repository.getPurchaseRecord(productId);
  }

  /// 取得新手期商品（first7/first30）的剩餘倒數（例如：6天23小時）
  Future<String?> getFirstPeriodCountdown(String productId) async {
    if (!_initialized) return null;

    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) return null;

    final type = productConfig['purchase_limit_type'] as String?;
    if (type != 'first7' && type != 'first30') return null;

    final days = type == 'first7' ? 7 : 30;
    final nowLocal = _getCurrentTaipeiTime();
    final installRecord = await _repository.ensureInstallRecord(nowLocal);
    final firstOpen = DateTime.parse(installRecord.firstOpenDate);
    final endAt = firstOpen.add(Duration(days: days));
    final diff = endAt.difference(nowLocal);
    if (diff.inSeconds <= 0) return null;

    final d = diff.inDays;
    final h = diff.inHours % 24;
    if (d > 0) {
      return '$d天$h小時';
    } else {
      final m = diff.inMinutes % 60;
      return '$h小時$m分';
    }
  }

  /// 處理購買事件
  Future<void> _onPurchaseEvent(PurchaseEvent event) async {
    if (_disposed || !_initialized) return;
    if (event.status == PurchaseStatus.success) {
      // 更新購買記錄
      final nowLocal = _getCurrentTaipeiTime();
      await _limiter.markPurchased(event.productId, nowLocal);

      // 發放對應權益（例如：store.card_click_perm 啟用永久點擊 1.5x）
      try {
        // EntitlementManager 的配置鍵為 'store.*'，若傳入 sku 需補上前綴
        final grantId = event.productId.startsWith('store.')
            ? event.productId
            : 'store.${event.productId}';
        await _entitlementManager.grant(skuId: grantId);
      } catch (e) {
        debugPrint('Entitlement grant failed for ${event.productId}: $e');
      }

      // 通知 UI 更新
      notifyListeners();

      // 這裡未來可以加入權益下發邏輯
      debugPrint('Purchase successful: ${event.productId}');
    } else {
      debugPrint(
        'Purchase event: ${event.status} for ${event.productId} - ${event.message}',
      );
    }
  }

  /// 取得當前台北時間
  DateTime _getCurrentTaipeiTime() {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(const Duration(hours: 8)); // Asia/Taipei = UTC+8
  }

  /// 重置所有購買記錄（測試用）
  Future<void> resetAllPurchases() async {
    // 清除購買存檔（包含安裝紀錄與各商品計數）
    await _repository.clearAll();
    // 清除限購偏好資料（每日/月/首次啟動等快取）
    await PurchaseLimitPolicy.resetAllPrefs();
    // 一併清除權益持久化資料，避免殘留永久權益或訂單紀錄
    try {
      await _entitlementManager.resetPersistedData();
    } catch (_) {}
    notifyListeners();
  }

  /// 取得新手期商品（first7/first30）的剩餘倒數時間
  /// 回傳 map: { 'days': d, 'hours': h, 'minutes': m }
  /// 若商品不是新手期型別，仍回傳 0 結構以簡化 UI 判斷。
  Future<Map<String, int>> getFirstPeriodRemaining(String productId) async {
    // 讀取商品設定，判斷是否為 first7/first30
    final storeConfig = _configService.getStoreConfig();
    final productConfig = storeConfig[productId] as Map<String, dynamic>?;
    if (productConfig == null) {
      return const {'days': 0, 'hours': 0, 'minutes': 0};
    }

    final type = (productConfig['purchase_limit_type'] as String?) ?? 'limited';
    int periodDays;
    if (type == 'first7') {
      periodDays = 7;
    } else if (type == 'first30') {
      periodDays = 30;
    } else {
      return const {'days': 0, 'hours': 0, 'minutes': 0};
    }

    // 以 Asia/Taipei 的「當前時間」計算
    final nowLocal = _getCurrentTaipeiTime();
    // 確保安裝記錄存在
    final install = await _repository.ensureInstallRecord(nowLocal);
    DateTime startLocal;
    try {
      startLocal = DateTime.parse(install.firstOpenDate);
    } catch (_) {
      // 若解析失敗，視為已過期
      return const {'days': 0, 'hours': 0, 'minutes': 0};
    }

    final endLocal = startLocal.add(Duration(days: periodDays));
    Duration remain = endLocal.difference(nowLocal);
    if (remain.isNegative) {
      return const {'days': 0, 'hours': 0, 'minutes': 0};
    }

    // 粗略拆解天/時/分
    final totalMinutes = remain.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes - days * 24 * 60) ~/ 60;
    final minutes = totalMinutes - days * 24 * 60 - hours * 60;
    return {'days': days, 'hours': hours, 'minutes': minutes};
  }

  /// 釋放資源
  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    if (_initialized) {
      _purchaseService.dispose();
    }
    _initialized = false;
    _disposed = true;
    super.dispose();
  }

  // ========== 向後相容的方法 ==========
  // 為了不破壞現有 UI，保留一些舊的方法名稱

  /// 檢查商品是否可購買（向後相容）
  Future<bool> canPurchase(String itemKey) async {
    final availability = await getAvailability(itemKey);
    return availability.canBuy;
  }

  /// 購買商品（向後相容）
  Future<void> purchase(String itemKey) async {
    await buyProduct(itemKey);
  }

  /// 取得購買次數（向後相容）
  Future<int> getCount(String itemKey) async {
    final record = await getPurchaseRecord(itemKey);
    return record?.total ?? 0;
  }

  /// 取得每日購買次數（向後相容）
  Future<int> getDailyCount(String itemKey) async {
    final record = await getPurchaseRecord(itemKey);
    final nowLocal = _getCurrentTaipeiTime();
    final currentDate = _formatDate(nowLocal);

    if (record?.daily?.date == currentDate) {
      return record!.daily!.count;
    }
    return 0;
  }

  /// 取得每月購買次數（向後相容）
  Future<int> getMonthlyCount(String itemKey) async {
    final record = await getPurchaseRecord(itemKey);
    final nowLocal = _getCurrentTaipeiTime();
    final currentYm = _formatYearMonth(nowLocal);

    if (record?.monthly?.ym == currentYm) {
      return record!.monthly!.count;
    }
    return 0;
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatYearMonth(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}';
  }
}
