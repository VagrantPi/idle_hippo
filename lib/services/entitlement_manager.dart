import 'package:flutter/foundation.dart';

/// 權益管理器介面
///
/// 實際授予玩家購買後的權益（例如解鎖功能、加值道具）。
/// 冪等性建議在實作層處理：重複授權同一權益不應造成副作用。
abstract class EntitlementManager {
  Future<void> grant(String entitlementKey);
}

/// 簡易的記憶體 Mock 版本（測試用）
class MockEntitlementManager implements EntitlementManager {
  final List<String> granted = <String>[];

  @override
  Future<void> grant(String entitlementKey) async {
    // 冪等保護：避免重複插入
    if (!granted.contains(entitlementKey)) {
      granted.add(entitlementKey);
      debugPrint('[Entitlement] grant => $entitlementKey');
    }
  }
}
