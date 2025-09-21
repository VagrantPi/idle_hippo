# 階段 27-8｜測試與健全性檢查

## 目標

為前述各層提供單元與整合測試規格（不需寫測試碼，只列出案例）。

### 規格（測試清單）

* `SkuMapper`：
  * 所有 `tabs.*[].items` → `getSkuId` 皆成功
  * 異常鍵位回錯誤
* `PurchaseOrchestrator`：
  * 成功/失敗/重試/restore 流程
  * 查價快取命中
* `EntitlementManager`：
  * non-consumable/consumable 冪等
  * 遺失 orderId 的 non-consumable 恢復
* `PurchaseLimitPolicy`：
  * `limited/daily/monthly/first7/first30` 規則
* UI 狀態機：
  * 全主要分支的狀態轉移
  * 錯誤碼對文案 key 映射

## 驗收實例化需求

* 建立一組 mock 資料：
  * `storeIds`：取你 JSON 裡 permanent/limited 的若干項
  * 模擬：`buy` 成功、驗證 `ok=true` → 應觸發 `grant`
  * 模擬：`verify ok=false` → 不觸發 `grant`、UI 顯示錯誤
  * 模擬：每日/月限制 → UI 正確顯示 `limitedReached/owned`
