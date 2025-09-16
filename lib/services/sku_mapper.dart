import 'dart:convert';
import 'package:flutter/services.dart';

/// 自定義例外：當 storeId 無法對應到 skuId 時拋出
class SkuMappingNotFound implements Exception {
  final String storeId;
  
  const SkuMappingNotFound(this.storeId);
  
  @override
  String toString() => 'SkuMappingNotFound: $storeId';
}

/// SKU 對照服務：將 storeId 轉換為 skuId
class SkuMapper {
  static SkuMapper? _instance;
  static SkuMapper get instance => _instance ??= SkuMapper._();
  
  SkuMapper._();
  
  Map<String, dynamic>? _storeData;
  bool _initialized = false;
  
  /// 初始化：載入 store.json 配置
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/config/store.json');
      _storeData = json.decode(jsonString);
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to load store.json: $e');
    }
  }
  
  /// 將 storeId 轉換為 skuId
  /// 規則：去掉 "store." 前綴
  /// 例：store.card_click_perm -> card_click_perm
  String getSkuId(String storeId) {
    if (!_initialized) {
      throw StateError('SkuMapper not initialized. Call init() first.');
    }
    
    // 檢查 storeId 是否存在於 store.json 的 items 中
    final items = _storeData?['items'] as Map<String, dynamic>?;
    if (items == null || !items.containsKey(storeId)) {
      throw SkuMappingNotFound(storeId);
    }
    
    // 去掉 "store." 前綴
    if (storeId.startsWith('store.')) {
      return storeId.substring(6); // 移除 "store." (6 個字元)
    }
    
    // 如果不是以 "store." 開頭，也視為無效
    throw SkuMappingNotFound(storeId);
  }
  
  /// 取得所有有效的 storeId 列表
  List<String> getAllStoreIds() {
    if (!_initialized) {
      throw StateError('SkuMapper not initialized. Call init() first.');
    }
    
    final items = _storeData?['items'] as Map<String, dynamic>?;
    return items?.keys.toList() ?? [];
  }
  
  /// 驗證所有 tabs 中的 storeId 都能成功轉換
  bool validateAllTabsStoreIds() {
    if (!_initialized) {
      throw StateError('SkuMapper not initialized. Call init() first.');
    }
    
    final tabs = _storeData?['tabs'] as Map<String, dynamic>?;
    if (tabs == null) return false;
    
    try {
      // 遍歷所有 tabs
      for (final tabEntry in tabs.entries) {
        final tabSections = tabEntry.value as List<dynamic>;
        for (final section in tabSections) {
          final items = section['items'] as List<dynamic>?;
          if (items != null) {
            for (final storeId in items) {
              getSkuId(storeId as String); // 會拋出例外如果轉換失敗
            }
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
