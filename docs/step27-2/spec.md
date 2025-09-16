# 階段 27-2｜IAP 流程協調器（Orchestrator）

## 目標

在 `PurchaseService` 之上新增一層 **PurchaseOrchestrator**，集中處理：
查價快取、購買流程、驗證 API 呼叫（先串 mock endpoint）、權益發放呼叫、冪等。

### 規格

* 介面（無需程式碼，只定義行為）
  * `preloadCatalogPrices(List<String> storeIds)`
    * 轉 `skuId` 後統一呼叫 `PurchaseService.queryProducts`
    * 緩存結果，存活至 app 關閉或手動清除
  * `purchase(String storeId)`
    * 取得 `skuId` → 呼叫 `PurchaseService.buy`
    * 監聽 `purchaseStream` 成功事件 → 呼叫「驗證 API」（mock endpoint URL 由 Config 注入）
    * `ok=true` 時才呼叫 **EntitlementManager.grant**（階段 27-3）
    * 冪等（見 階段 27-3）
  * `restoreNonConsumables()`
    * 代理 `PurchaseService.restore` 行為
    * 對於回來的 event：只針對 **non-consumable** 嘗試套用權益（階段 27-3 冪等保護）
* Orchestrator 必須發出 UI 可用的狀態事件（Stream）：
  * `loading`, `purchasing(productId)`, `verifying(orderId?)`, `success(storeId)`, `error(code,message)`

## 驗收實例化需求

1. **查價快取**
   * Given：同一批 `storeIds` 連續呼叫 `preloadCatalogPrices` 兩次
   * Then：第二次不得再次呼叫底層 `PurchaseService.queryProducts`
2. **購買成功流程**
   * Given：`store.card_click_perm`
   * When：`purchase` → Mock 購買成功 → Mock 驗證 API `ok=true`
   * Then：觸發 `EntitlementManager.grant('card_click_perm')`，Orchestrator 推播 `success`
3. **購買失敗（驗證失敗）**
   * Given：`store.card_click_perm`
   * When：`purchase` → Mock 購買成功 → Mock 驗證回 `ok=false, reason='sku_not_allowed'`
   * Then：不呼叫 `grant`、Orchestrator 推播 `error('verify_failed')`
4. **恢復流程（non-consumable）**
   * Given：`restoreNonConsumables()`
   * When：`PurchaseService.restore` 推回 `card_click_perm` 成功事件
   * Then：呼叫 `grant('card_click_perm')` 並推播 `success`（冪等保護由 階段 27-3）
