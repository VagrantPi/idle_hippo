/// 交易日誌模型
class EntitlementData {
  /// 已處理的訂單記錄 (orderId -> OrderGrant)
  final Map<String, OrderGrant> orders;
  
  /// 永久權益旗標 (skuId -> bool)
  final Map<String, bool> entitlements;

  const EntitlementData({
    this.orders = const {},
    this.entitlements = const {},
  });

  /// 從 JSON 建立實例
  factory EntitlementData.fromJson(Map<String, dynamic> json) {
    final ordersJson = json['orders'] as Map<String, dynamic>? ?? {};
    final orders = <String, OrderGrant>{};
    for (final entry in ordersJson.entries) {
      orders[entry.key] = OrderGrant.fromJson(entry.value as Map<String, dynamic>);
    }

    final entitlementsJson = json['entitlements'] as Map<String, dynamic>? ?? {};
    final entitlements = <String, bool>{};
    for (final entry in entitlementsJson.entries) {
      entitlements[entry.key] = entry.value as bool? ?? false;
    }

    return EntitlementData(
      orders: orders,
      entitlements: entitlements,
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    final ordersJson = <String, dynamic>{};
    for (final entry in orders.entries) {
      ordersJson[entry.key] = entry.value.toJson();
    }

    return {
      'orders': ordersJson,
      'entitlements': entitlements,
    };
  }

  /// 建立副本並更新指定欄位
  EntitlementData copyWith({
    Map<String, OrderGrant>? orders,
    Map<String, bool>? entitlements,
  }) {
    return EntitlementData(
      orders: orders ?? this.orders,
      entitlements: entitlements ?? this.entitlements,
    );
  }

  /// 檢查訂單是否已處理
  bool hasGrantedOrder(String orderId) {
    return orders.containsKey(orderId);
  }

  /// 檢查是否擁有永久權益
  bool hasEntitlement(String skuId) {
    return entitlements[skuId] == true;
  }

  /// 新增訂單記錄
  EntitlementData addOrder(String orderId, String skuId, int grantedAt) {
    final newOrders = Map<String, OrderGrant>.from(orders);
    newOrders[orderId] = OrderGrant(
      skuId: skuId,
      grantedAt: grantedAt,
    );
    return copyWith(orders: newOrders);
  }

  /// 設定永久權益
  EntitlementData setEntitlement(String skuId, bool value) {
    final newEntitlements = Map<String, bool>.from(entitlements);
    newEntitlements[skuId] = value;
    return copyWith(entitlements: newEntitlements);
  }
}

/// 單筆訂單授權記錄
class OrderGrant {
  /// SKU ID
  final String skuId;
  
  /// 授權時間戳記
  final int grantedAt;

  const OrderGrant({
    required this.skuId,
    required this.grantedAt,
  });

  /// 從 JSON 建立實例
  factory OrderGrant.fromJson(Map<String, dynamic> json) {
    return OrderGrant(
      skuId: json['skuId'] as String? ?? '',
      grantedAt: json['grantedAt'] as int? ?? 0,
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'skuId': skuId,
      'grantedAt': grantedAt,
    };
  }
}
