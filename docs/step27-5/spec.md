# 階段 27-5｜UI 狀態機與錯誤處理

## 目標

統一商店按鈕狀態、錯誤彈窗、成功提示，不嵌到業務層。

### 規格

* 定義按鈕狀態列舉（UI 層使用）：
  `idle`, `loadingPrice`, `ready`, `purchasing`, `verifying`, `owned`, `soldOut`, `limitedReached`, `disabled`
* 狀態轉換規則：
  * 進入頁面 → `loadingPrice` → 有價 → `ready`
  * `purchase` 按下 → `purchasing` → `verifying` → `success`（toast）→ 根據限購進入 `owned/limitedReached`
* 錯誤對應（顯示文案 key，不寫死文字）：
  * `store_unavailable`, `network_error`, `verify_failed`, `sku_not_allowed`, `limit_reached`

## 驗收實例化需求

1. **價格載入**
   * Given：`preloadCatalogPrices` 完成
   * Then：所有可售商品顯示官方/Mock 價格，狀態為 `ready`
2. **購買流**
   * Given：點擊可售商品
   * When：模擬成功
   * Then：按鈕依序顯示 `purchasing → verifying → owned/limitedReached`，並彈出 `success` 提示
3. **錯誤流**
   * Given：驗證返回 `ok=false, reason='sku_not_allowed'`
   * Then：顯示錯誤（對應 key），保留按鈕在 `ready`（可重試）或 `disabled`（依規則）