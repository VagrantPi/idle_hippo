# 階段 27-3｜權益發放 & 冪等

## 目標

集中管理「發獎」與「冪等處理」。

* non-consumable：設永久旗標
* consumable：加資源 & 記錄交易
* 任一交易 **同一 `orderId`/`purchaseToken` 只處理一次**

### 規格

* 新增 `EntitlementManager`（純前端、本地持久化）
  * `Future<void> grant({required String skuId, String? orderId})`
  * `bool hasGrantedOrder(String orderId)`
  * non-consumable 永久旗標：`entitlement_$skuId = true`
  * consumable：**加資源**（呼叫你現有的加值 API，如：加票、加 buff 時間），再記錄 `orderId → granted`
  * 若 `orderId` 為 `null`（Mock 恢復、或非 Android 平台），以 `skuId` 為冪等鍵（僅 non-consumable 可接受）
* 交易日誌（本地存檔）結構（示意）
  ```json
  {
    "orders": {
      "GPA.XXXX": { "skuId": "card_click_2x_30m", "grantedAt": 1737xxxx }
    },
    "entitlements": {
      "card_click_perm": true,
      "card_idle_perm": true
    }
  }
  ```

## 驗收實例化需求

1. **non-consumable 冪等**
   * Given：連續兩次 `grant(skuId='card_click_perm', orderId='A')`
   * Then：只會寫入一次 `entitlements.card_click_perm=true`（不重複觸發副作用）
2. **consumable 冪等**
   * Given：`grant(skuId='card_click_2x_30m', orderId='B')` 呼叫兩次
   * Then：資源僅被加一次，`orders.B` 僅一筆
3. **缺 orderId（恢復 non-consumable）**
   * Given：`grant(skuId='card_idle_perm', orderId=null)`
   * Then：仍能設置 entitlement 並具備冪等（重複呼叫不再觸發）
