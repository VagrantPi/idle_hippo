import 'dart:async';
import '../models/purchase_models.dart';
import 'purchase_service.dart';

/// Mock 購買服務實作
/// 
/// 提供測試與開發階段使用的模擬購買功能
class MockPurchaseService implements PurchaseService {
  final StreamController<PurchaseEvent> _purchaseController =
      StreamController<PurchaseEvent>.broadcast(sync: true);

  @override
  Stream<PurchaseEvent> get purchaseStream => _purchaseController.stream;

  @override
  Future<List<ProductInfo>> queryProducts(List<String> ids) async {
    // 模擬網路延遲
    await Future.delayed(const Duration(milliseconds: 500));
    
    return ids.map((id) => ProductInfo(
      id: id,
      name: 'Mock Product $id',
      desc: 'Mock description for $id',
      image: 'assets/images/store/mock_$id.png',
      price: 1.99,
      currency: 'USD',
    )).toList();
  }

  @override
  Future<void> buy(String productId) async {
    // 模擬購買處理時間
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock 購買一律成功
    _purchaseController.add(PurchaseEvent(
      productId: productId,
      status: PurchaseStatus.success,
    ));
  }

  @override
  Future<void> restore() async {
    // 模擬恢復購買延遲
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock 恢復一筆 card_click_perm 購買
    _purchaseController.add(const PurchaseEvent(
      productId: 'card_click_perm',
      status: PurchaseStatus.success,
      message: 'Restored purchase',
    ));
  }

  @override
  void dispose() {
    _purchaseController.close();
  }
}

/// IAP 購買服務佔位實作
/// 
/// 未來接入真實 IAP SDK 時實作
class IapPurchaseService implements PurchaseService {
  final StreamController<PurchaseEvent> _purchaseController =
      StreamController<PurchaseEvent>.broadcast(sync: true);

  @override
  Stream<PurchaseEvent> get purchaseStream => _purchaseController.stream;

  @override
  Future<List<ProductInfo>> queryProducts(List<String> ids) async {
    throw UnimplementedError('IAP service not implemented yet');
  }

  @override
  Future<void> buy(String productId) async {
    // 回傳未實作錯誤事件
    _purchaseController.add(PurchaseEvent(
      productId: productId,
      status: PurchaseStatus.error,
      message: 'IAP service not implemented yet',
    ));
  }

  @override
  Future<void> restore() async {
    // 回傳未實作錯誤事件
    _purchaseController.add(const PurchaseEvent(
      productId: 'unknown',
      status: PurchaseStatus.error,
      message: 'IAP restore not implemented yet',
    ));
  }

  @override
  void dispose() {
    _purchaseController.close();
  }
}
