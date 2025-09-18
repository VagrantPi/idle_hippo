import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/buff_models.dart';
import 'game_state_service.dart';

/// 商品效果配置
class StoreEffectConfig {
  final String type; // permanent, timed, instant, bundle
  final Map<String, dynamic> effects;
  final String? description;

  const StoreEffectConfig({
    required this.type,
    required this.effects,
    this.description,
  });

  factory StoreEffectConfig.fromMap(Map<String, dynamic> map) {
    return StoreEffectConfig(
      type: map['type'] as String,
      effects: Map<String, dynamic>.from(map['effects'] as Map),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'effects': effects,
      if (description != null) 'description': description,
    };
  }
}

/// 權益資料模型
class EntitlementData {
  final Map<String, bool> entitlements; // skuId -> granted
  final Map<String, int> orders; // orderId -> timestamp

  const EntitlementData({this.entitlements = const {}, this.orders = const {}});

  EntitlementData copyWith({
    Map<String, bool>? entitlements,
    Map<String, int>? orders,
  }) {
    return EntitlementData(
      entitlements: entitlements ?? this.entitlements,
      orders: orders ?? this.orders,
    );
  }

  EntitlementData setEntitlement(String skuId, bool granted) {
    final newEntitlements = Map<String, bool>.from(entitlements);
    newEntitlements[skuId] = granted;
    return copyWith(entitlements: newEntitlements);
  }

  EntitlementData addOrder(String orderId, int timestamp) {
    final newOrders = Map<String, int>.from(orders);
    newOrders[orderId] = timestamp;
    return copyWith(orders: newOrders);
  }

  bool hasEntitlement(String skuId) {
    return entitlements[skuId] == true;
  }

  bool hasGrantedOrder(String orderId) {
    return orders.containsKey(orderId);
  }

  factory EntitlementData.fromMap(Map<String, dynamic> map) {
    return EntitlementData(
      entitlements: Map<String, bool>.from(map['entitlements'] ?? {}),
      orders: Map<String, int>.from(map['orders'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {'entitlements': entitlements, 'orders': orders};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EntitlementData &&
        mapEquals(other.entitlements, entitlements) &&
        mapEquals(other.orders, orders);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(entitlements.entries),
    Object.hashAllUnordered(orders.entries),
  );
}

/// 權益管理器介面
abstract class EntitlementManager {
  /// 初始化
  Future<void> init();

  /// 發放權益
  /// [skuId] 商品 ID
  /// [orderId] 訂單 ID（可選，用於冪等檢查）
  Future<void> grant({required String skuId, String? orderId});

  /// 檢查是否擁有權益
  bool hasEntitlement(String skuId);

  /// 檢查訂單是否已處理
  bool hasGrantedOrder(String orderId);

  /// 清理過期的限時 buff
  Future<void> cleanupExpiredBuffs();

  /// 清除所有權益持久化資料（Debug/重置用）
  /// - 刪除安全儲存中的紀錄
  /// - 清空記憶體中的快取資料
  Future<void> resetPersistedData();
}

/// 權益管理器實作
class EntitlementManagerImpl implements EntitlementManager {
  final GameStateService _gameStateService;
  final FlutterSecureStorage _storage;
  final String _storageKey = 'entitlement_data';

  EntitlementData _data = const EntitlementData();
  Map<String, StoreEffectConfig> _effectsConfig = {};

  EntitlementManagerImpl({
    required GameStateService gameStateService,
    FlutterSecureStorage? storage,
  }) : _gameStateService = gameStateService,
       _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> init() async {
    await _loadEffectsConfig();
    await _loadData();
  }

  /// 載入商品效果配置
  Future<void> _loadEffectsConfig() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/config/store_effects.json',
      );
      final Map<String, dynamic> configMap = json.decode(jsonString);

      _effectsConfig = configMap.map(
        (key, value) => MapEntry(
          key,
          StoreEffectConfig.fromMap(value as Map<String, dynamic>),
        ),
      );

      debugPrint('[EntitlementManager] 載入商品效果配置: ${_effectsConfig.length} 項');
    } catch (e) {
      debugPrint('[EntitlementManager] 載入商品效果配置失敗: $e');
      _effectsConfig = {};
    }
  }

  /// 載入權益資料
  Future<void> _loadData() async {
    try {
      final jsonString = await _storage.read(key: _storageKey);
      if (jsonString != null) {
        final Map<String, dynamic> dataMap = json.decode(jsonString);
        _data = EntitlementData.fromMap(dataMap);
      }
    } catch (e) {
      debugPrint('[EntitlementManager] 載入權益資料失敗: $e');
      _data = const EntitlementData();
    }
  }

  /// 儲存權益資料
  Future<void> _saveData() async {
    try {
      final jsonString = json.encode(_data.toMap());
      await _storage.write(key: _storageKey, value: jsonString);
    } catch (e) {
      debugPrint('[EntitlementManager] 儲存權益資料失敗: $e');
    }
  }

  @override
  Future<void> grant({required String skuId, String? orderId}) async {
    final resolvedSkuId = _resolveSkuId(skuId);

    // 冪等檢查
    if (orderId != null && _data.hasGrantedOrder(orderId)) {
      debugPrint('[EntitlementManager] 訂單已處理，跳過: $orderId');
      return;
    }

    // 取得商品配置
    final config = _effectsConfig[resolvedSkuId];
    if (config == null) {
      debugPrint('[EntitlementManager] 找不到商品配置: $skuId');
      return;
    }

    // 處理商品效果
    await _processStoreItem(resolvedSkuId, config, orderId);

    // 記錄訂單
    if (orderId != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _data = _data.addOrder(orderId, now);
    }

    // 儲存資料
    await _saveData();
  }

  @override
  bool hasEntitlement(String skuId) {
    final resolvedSkuId = _resolveSkuId(skuId);
    return _data.hasEntitlement(resolvedSkuId);
  }

  @override
  bool hasGrantedOrder(String orderId) {
    return _data.hasGrantedOrder(orderId);
  }

  /// 將輸入的 SKU 標準化為配置中使用的鍵值
  String _resolveSkuId(String skuId) {
    if (_effectsConfig.containsKey(skuId)) {
      return skuId;
    }

    if (!skuId.startsWith('store.')) {
      final prefixed = 'store.$skuId';
      if (_effectsConfig.containsKey(prefixed)) {
        return prefixed;
      }
    } else {
      final unprefixed = skuId.substring('store.'.length);
      if (_effectsConfig.containsKey(unprefixed)) {
        return unprefixed;
      }
    }

    return skuId;
  }

  @override
  Future<void> cleanupExpiredBuffs() async {
    final currentState = _gameStateService.currentState;
    final currentBuffs = currentState.buffs;

    if (currentBuffs == null) return;

    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
    final cleanedBuffs = currentBuffs.cleanupExpired(currentTimeMs);

    if (cleanedBuffs != currentBuffs) {
      final newState = currentState.copyWith(buffs: cleanedBuffs);
      await _gameStateService.updateGameState(newState);
      debugPrint('[EntitlementManager] 清理過期 buff');
    }
  }

  @override
  Future<void> resetPersistedData() async {
    try {
      await _storage.delete(key: _storageKey);
      _data = const EntitlementData();
      debugPrint('[EntitlementManager] 已清除權益持久化資料');
    } catch (e) {
      debugPrint('[EntitlementManager] 清除權益持久化資料失敗: $e');
    }
  }

  /// 處理商品項目
  Future<void> _processStoreItem(
    String skuId,
    StoreEffectConfig config,
    String? orderId,
  ) async {
    switch (config.type) {
      case 'permanent':
        await _grantPermanentEffects(skuId, config.effects);
        break;
      case 'timed':
        await _grantTimedBuffs(config.effects);
        break;
      case 'instant':
        await _grantInstantEffects(config.effects);
        break;
      case 'bundle':
        await _grantBundleEffects(config.effects);
        break;
      default:
        debugPrint('[EntitlementManager] 未知的商品類型: ${config.type}');
    }
  }

  /// 發放永久效果
  Future<void> _grantPermanentEffects(
    String skuId,
    Map<String, dynamic> effects,
  ) async {
    // 檢查是否已擁有
    if (_data.hasEntitlement(skuId)) {
      debugPrint('[EntitlementManager] 永久權益已擁有，跳過: $skuId');
      return;
    }

    // 設定永久權益
    _data = _data.setEntitlement(skuId, true);

    // 更新遊戲狀態中的永久 buff
    final currentState = _gameStateService.currentState;
    final currentBuffs = currentState.buffs ?? const BuffState();

    var newPermanent = currentBuffs.permanent;

    // 根據效果類型更新永久權益
    if (effects.containsKey('clickBoost')) {
      final clickValue = effects['clickBoost'];
      if (clickValue is num && clickValue > 1.0) {
        newPermanent = newPermanent.copyWith(clickBoost: clickValue.toDouble());
      }
    }

    if (effects.containsKey('idleBoost')) {
      final idleValue = effects['idleBoost'];
      if (idleValue is num && idleValue > 1.0) {
        newPermanent = newPermanent.copyWith(idleBoost: idleValue.toDouble());
      }
    }

    if (effects.containsKey('offlineExtended') &&
        effects['offlineExtended'] == true) {
      newPermanent = newPermanent.copyWith(offlineExtended: true);
    }

    if (effects.containsKey('capIncreased') &&
        effects['capIncreased'] == true) {
      newPermanent = newPermanent.copyWith(capIncreased: true);
    }

    final newBuffs = currentBuffs.copyWith(permanent: newPermanent);
    final newState = currentState.copyWith(buffs: newBuffs);

    await _gameStateService.updateGameState(newState);
    debugPrint('[EntitlementManager] 發放永久效果: $skuId, 效果: $effects');
  }

  /// 發放限時 buff
  Future<void> _grantTimedBuffs(Map<String, dynamic> effects) async {
    final currentState = _gameStateService.currentState;
    final currentBuffs = currentState.buffs ?? const BuffState();
    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;

    var newBuffs = currentBuffs;

    // 處理各種限時 buff
    for (final entry in effects.entries) {
      final buffType = entry.key;
      final buffData = entry.value as Map<String, dynamic>;
      final multiplier = (buffData['multiplier'] as num).toDouble();
      final durationMinutes = (buffData['durationMinutes'] as num).toInt();
      final durationMs = durationMinutes * 60 * 1000;

      newBuffs = newBuffs.addOrExtendBuff(
        type: buffType,
        multiplier: multiplier,
        durationMs: durationMs,
        currentTimeMs: currentTimeMs,
      );
    }

    final newState = currentState.copyWith(buffs: newBuffs);
    await _gameStateService.updateGameState(newState);
    debugPrint('[EntitlementManager] 發放限時 buff: $effects');
  }

  /// 發放即時效果
  Future<void> _grantInstantEffects(Map<String, dynamic> effects) async {
    final currentState = _gameStateService.currentState;
    var newState = currentState;

    // 處理各種即時效果
    if (effects.containsKey('memePoints')) {
      final points = (effects['memePoints'] as num).toInt();
      newState = newState.copyWith(memePoints: newState.memePoints + points);
    }

    if (effects.containsKey('petTickets')) {
      final tickets = (effects['petTickets'] as num).toInt();
      newState = newState.copyWith(petTickets: newState.petTickets + tickets);
    }

    await _gameStateService.updateGameState(newState);
    debugPrint('[EntitlementManager] 發放即時效果: $effects');
  }

  /// 發放組合包效果
  Future<void> _grantBundleEffects(Map<String, dynamic> effects) async {
    // 組合包包含多種效果類型
    if (effects.containsKey('permanent')) {
      await _grantPermanentEffects(
        'bundle_permanent',
        effects['permanent'] as Map<String, dynamic>,
      );
    }

    if (effects.containsKey('timed')) {
      await _grantTimedBuffs(effects['timed'] as Map<String, dynamic>);
    }

    if (effects.containsKey('instant')) {
      await _grantInstantEffects(effects['instant'] as Map<String, dynamic>);
    }

    debugPrint('[EntitlementManager] 發放組合包效果: $effects');
  }
}

/// Mock 權益管理器（用於測試）
class MockEntitlementManager implements EntitlementManager {
  final List<String> grantedEntitlements = []; // 改為 List 以支援重複發放
  final Set<String> processedOrders = {};
  final Set<String> permanentEntitlements = {}; // 追蹤永久權益

  /// 向後兼容的 getter
  List<String> get granted => grantedEntitlements;

  @override
  Future<void> init() async {
    // Mock 不需要初始化
  }

  @override
  Future<void> grant({required String skuId, String? orderId}) async {
    // 冪等檢查：如果有 orderId 且已處理過，則跳過
    if (orderId != null && processedOrders.contains(orderId)) {
      return;
    }

    // 判斷是否為 non-consumable（永久商品）
    final isNonConsumable = _isNonConsumableProduct(skuId);

    if (isNonConsumable) {
      // non-consumable: 檢查是否已擁有
      if (permanentEntitlements.contains(skuId)) {
        return; // 已擁有，跳過
      }
      permanentEntitlements.add(skuId);
    }

    // 發放權益
    grantedEntitlements.add(skuId);

    // 記錄訂單
    if (orderId != null) {
      processedOrders.add(orderId);
    }
  }

  @override
  bool hasEntitlement(String skuId) {
    return permanentEntitlements.contains(skuId);
  }

  /// 判斷是否為 non-consumable 商品
  bool _isNonConsumableProduct(String skuId) {
    // 根據 SKU 命名規則判斷
    return skuId.contains('_perm') ||
        skuId.contains('_permanent') ||
        skuId.startsWith('card_') && skuId.contains('_perm');
  }

  @override
  Future<void> cleanupExpiredBuffs() async {
    // Mock 不需要清理
  }

  @override
  Future<void> resetPersistedData() async {
    grantedEntitlements.clear();
    processedOrders.clear();
    permanentEntitlements.clear();
  }

  @override
  bool hasGrantedOrder(String orderId) {
    return processedOrders.contains(orderId);
  }
}
