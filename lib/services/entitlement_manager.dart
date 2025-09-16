import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/entitlement_models.dart';
import '../models/game_state.dart';
import 'config_service.dart';
import 'game_state_service.dart';

/// 權益管理器介面
///
/// 實際授予玩家購買後的權益（例如解鎖功能、加值道具）。
/// 冪等性建議在實作層處理：重複授權同一權益不應造成副作用。
abstract class EntitlementManager {
  /// 發放權益
  /// 
  /// [skuId] 商品 SKU ID
  /// [orderId] 訂單 ID，可為 null（用於恢復 non-consumable）
  Future<void> grant({required String skuId, String? orderId});
  
  /// 檢查訂單是否已處理
  bool hasGrantedOrder(String orderId);
}

/// 完整的權益管理器實作
class EntitlementManagerImpl implements EntitlementManager {
  static const String _storageKey = 'entitlement_data';
  
  final ConfigService _configService;
  final GameStateService _gameStateService;
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  EntitlementData _data = const EntitlementData();
  bool _initialized = false;

  EntitlementManagerImpl({
    required ConfigService configService,
    required GameStateService gameStateService,
  }) : _configService = configService,
       _gameStateService = gameStateService;

  /// 初始化服務
  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadData();
    _initialized = true;
  }

  @override
  Future<void> grant({required String skuId, String? orderId}) async {
    if (!_initialized) {
      await initialize();
    }

    // 冪等處理邏輯
    
    // 檢查是否為 non-consumable
    final isNonConsumable = _isNonConsumable(skuId);
    
    if (isNonConsumable) {
      // non-consumable: 檢查永久權益是否已設定
      if (_data.hasEntitlement(skuId)) {
        debugPrint('[EntitlementManager] 永久權益已存在，跳過: $skuId');
        return;
      }
      
      // 若有 orderId，也檢查是否已處理過
      if (orderId != null && _data.hasGrantedOrder(orderId)) {
        debugPrint('[EntitlementManager] 訂單已處理，跳過: $orderId');
        return;
      }
      
      // 設定永久權益
      _data = _data.setEntitlement(skuId, true);
      
      // 記錄訂單（如果有 orderId）
      if (orderId != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _data = _data.addOrder(orderId, skuId, now);
      }
      
      debugPrint('[EntitlementManager] 發放永久權益: $skuId');
    } else {
      // consumable: 檢查訂單是否已處理
      if (orderId != null && _data.hasGrantedOrder(orderId)) {
        debugPrint('[EntitlementManager] 消耗品訂單已處理，跳過: $orderId');
        return;
      }
      
      // 發放消耗品資源
      await _grantConsumableResources(skuId);
      
      // 記錄訂單
      if (orderId != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _data = _data.addOrder(orderId, skuId, now);
      }
      
      debugPrint('[EntitlementManager] 發放消耗品: $skuId');
    }
    
    // 保存資料
    await _saveData();
  }

  @override
  bool hasGrantedOrder(String orderId) {
    return _data.hasGrantedOrder(orderId);
  }

  /// 檢查是否為 non-consumable 商品
  bool _isNonConsumable(String skuId) {
    final storeConfig = _configService.getStoreConfig();
    
    // 移除 store. 前綴來查找配置
    final configKey = skuId.startsWith('store.') ? skuId : 'store.$skuId';
    final itemConfig = storeConfig['items']?[configKey] as Map<String, dynamic>?;
    
    if (itemConfig == null) {
      debugPrint('[EntitlementManager] 找不到商品配置: $configKey');
      return false;
    }
    
    final limitType = itemConfig['purchase_limit_type'] as String?;
    final maxCount = itemConfig['purchase_max_count'] as int?;
    
    // limited 且 max_count 為 1 的視為 non-consumable
    return limitType == 'limited' && maxCount == 1;
  }

  /// 發放消耗品資源
  Future<void> _grantConsumableResources(String skuId) async {
    // 根據 skuId 發放對應資源
    switch (skuId) {
      case 'card_click_2x_30m':
      case 'store.card_click_2x_30m':
        // 加 30 分鐘點擊 2x buff
        await _addBuffTime('click_2x', 30 * 60);
        break;
        
      case 'card_idle_2x_1h':
      case 'store.card_idle_2x_1h':
        // 加 1 小時掛機 2x buff
        await _addBuffTime('idle_2x', 60 * 60);
        break;
        
      case 'card_offline_once_6h':
      case 'store.card_offline_once_6h':
        // 加 6 小時離線收益
        await _addOfflineTime(6 * 60 * 60);
        break;
        
      case 'ticket_pet_single':
      case 'store.ticket_pet_single':
        // 加 1 張寵物抽獎券
        await _addTickets('pet', 1);
        break;
        
      case 'ticket_pet_10plus1':
      case 'store.ticket_pet_10plus1':
        // 加 11 張寵物抽獎券
        await _addTickets('pet', 11);
        break;
        
      default:
        debugPrint('[EntitlementManager] 未知的消耗品類型: $skuId');
    }
  }

  /// 增加 buff 時間
  Future<void> _addBuffTime(String buffType, int seconds) async {
    // 透過 GameStateService 更新狀態
    final currentState = _gameStateService.currentState;
    final stateData = jsonDecode(currentState.toJson()) as Map<String, dynamic>;
    final buffs = Map<String, dynamic>.from(stateData['buffs'] ?? {});
    final currentEndTime = buffs[buffType] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // 如果 buff 還在生效，延長時間；否則從現在開始
    final newEndTime = currentEndTime > now 
        ? currentEndTime + seconds
        : now + seconds;
    
    buffs[buffType] = newEndTime;
    stateData['buffs'] = buffs;
    
    // 建立新的狀態
    final newState = GameState.fromJson(jsonEncode(stateData));
    await _gameStateService.updateGameState(newState);
  }

  /// 增加離線時間
  Future<void> _addOfflineTime(int seconds) async {
    final currentState = _gameStateService.currentState;
    final stateData = jsonDecode(currentState.toJson()) as Map<String, dynamic>;
    final currentOfflineTime = stateData['offlineTime'] as int? ?? 0;
    stateData['offlineTime'] = currentOfflineTime + seconds;
    
    final newState = GameState.fromJson(jsonEncode(stateData));
    await _gameStateService.updateGameState(newState);
  }

  /// 增加抽獎券
  Future<void> _addTickets(String ticketType, int count) async {
    final currentState = _gameStateService.currentState;
    final stateData = jsonDecode(currentState.toJson()) as Map<String, dynamic>;
    final tickets = Map<String, dynamic>.from(stateData['tickets'] ?? {});
    final currentCount = tickets[ticketType] as int? ?? 0;
    tickets[ticketType] = currentCount + count;
    stateData['tickets'] = tickets;
    
    final newState = GameState.fromJson(jsonEncode(stateData));
    await _gameStateService.updateGameState(newState);
  }

  /// 載入資料
  Future<void> _loadData() async {
    try {
      final jsonStr = await _storage.read(key: _storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _data = EntitlementData.fromJson(json);
      }
    } catch (e) {
      debugPrint('[EntitlementManager] 載入資料失敗: $e');
      _data = const EntitlementData();
    }
  }

  /// 保存資料
  Future<void> _saveData() async {
    try {
      final jsonStr = jsonEncode(_data.toJson());
      await _storage.write(key: _storageKey, value: jsonStr);
    } catch (e) {
      debugPrint('[EntitlementManager] 保存資料失敗: $e');
    }
  }
}

/// 簡易的記憶體 Mock 版本（測試用）
class MockEntitlementManager implements EntitlementManager {
  final List<String> granted = <String>[];
  final Set<String> processedOrders = <String>{};
  final Set<String> permanentEntitlements = <String>{};

  @override
  Future<void> grant({required String skuId, String? orderId}) async {
    // 冪等檢查：如果有 orderId 且已處理過，則跳過
    if (orderId != null && processedOrders.contains(orderId)) {
      debugPrint('[MockEntitlementManager] 訂單已處理，跳過: $orderId');
      return;
    }
    
    // 簡單的商品類型判斷（基於命名規則）
    final isNonConsumable = skuId.contains('perm') || skuId.contains('cap');
    
    if (isNonConsumable) {
      // non-consumable: 檢查是否已經擁有永久權益
      if (permanentEntitlements.contains(skuId)) {
        debugPrint('[MockEntitlementManager] 永久權益已存在，跳過: $skuId');
        return;
      }
      
      // 設定永久權益
      permanentEntitlements.add(skuId);
      granted.add(skuId);
      debugPrint('[MockEntitlementManager] grant => $skuId');
    } else {
      // consumable: 每次都發放
      granted.add(skuId);
      debugPrint('[MockEntitlementManager] grant => $skuId');
    }
    
    // 記錄訂單
    if (orderId != null) {
      processedOrders.add(orderId);
    }
  }

  @override
  bool hasGrantedOrder(String orderId) {
    return processedOrders.contains(orderId);
  }
}
