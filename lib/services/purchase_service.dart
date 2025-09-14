import 'dart:async';
import '../models/purchase_models.dart';

/// 購買服務抽象介面
/// 
/// 提供統一的商品查詢、購買、恢復購買功能
/// 支援 Mock 與真實 IAP 實作切換
abstract class PurchaseService {
  /// 查詢商品資訊
  Future<List<ProductInfo>> queryProducts(List<String> ids);
  
  /// 購買事件串流
  Stream<PurchaseEvent> get purchaseStream;
  
  /// 購買商品（UI 僅呼叫此方法）
  Future<void> buy(String productId);
  
  /// 恢復購買（iOS 必備，Mock 可回傳一筆成功）
  Future<void> restore();
  
  /// 釋放資源
  void dispose();
}

/// 獎勵廣告服務抽象介面
/// 
/// 處理 ads_pay=true 商品的「看廣告兌換」流程
abstract class RewardedAdService {
  /// 觸發一次看廣告流程；成功發放回傳 rewarded
  Future<RewardedStatus> show(String placement, {String? productId});
}

/// 購買限制器抽象介面
/// 
/// 依商品規則與當前時間、歷史購買資料，回傳可購買狀態
abstract class PurchaseLimiter {
  /// 依商品規則（limitType / maxCount / adsPay）與當前時間、歷史購買資料，回傳可購買狀態
  Future<PurchaseAvailability> availability(String productId, DateTime nowLocal);

  /// 成功購買後更新計數（含跨期重置）
  Future<void> markPurchased(String productId, DateTime nowLocal);

  /// 跨日／跨月檢查與重置
  Future<void> ensureRollovers(DateTime nowLocal);
}
