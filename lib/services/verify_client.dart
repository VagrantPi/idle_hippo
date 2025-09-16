/// 驗證 API 客戶端介面與簡易 Mock
///
/// 真實情境會呼叫後端伺服器驗證收據／訂單，這裡先提供可注入的抽象層。
class VerifyClient {
  final String? endpoint; // 可由 Config 注入，測試可為 null

  VerifyClient({this.endpoint});

  /// 送出驗證請求
  /// 回傳 ok=true 才視為驗證通過
  Future<VerifyResult> verify({
    required String skuId,
    required String orderId,
  }) async {
    // 預設為不實作：交由子類或測試替身處理
    throw UnimplementedError('VerifyClient.verify not implemented');
  }
}

class VerifyResult {
  final bool ok;
  final String? reason; // 例如 sku_not_allowed 等

  const VerifyResult({required this.ok, this.reason});
}

/// 測試／開發用的 Mock 驗證客戶端
class MockVerifyClient extends VerifyClient {
  VerifyResult next = const VerifyResult(ok: true);

  MockVerifyClient({super.endpoint});

  @override
  Future<VerifyResult> verify({required String skuId, required String orderId}) async {
    // 直接回傳預設結果
    return next;
  }
}
