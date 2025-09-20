# 階段 27-7｜恢復購買（前端策略）

## 目標

在 **Android** 上提供恢復入口，將 non-consumable 權益套回（不依賴商店 UI）。

### 規格

* UI 提供一個「恢復購買」按鈕（商品頁 pages.shop 文字右方，可點擊時為橘色按鈕）
* `restoreNonConsumables()`：
  * 呼叫 `PurchaseService.restore`
  * 針對回傳的 non-consumable 逐筆呼叫 `EntitlementManager.grant(skuId, orderId?)`
  * 完成後統計「恢復了幾項」→ UI Toast 成功
* 當已點過「恢復購買」按鈕後且完成恢復，則按鈕會是 disabled 狀態

## 驗收實例化需求

1. **恢復成功**
   * Given：Mock 回傳 `card_click_perm`
   * When：點擊恢復
   * Then：`entitlements.card_click_perm = true`，UI 彈成功訊息
2. **冪等恢復**
   * Given：連續點兩次恢復
   * Then：權益僅保持一次（不重複副作用）
3. **已點過恢復按鈕後，按鈕會是 disabled 狀態**
   * Given：已點過恢復按鈕
   * Then：按鈕會是 disabled 狀態
