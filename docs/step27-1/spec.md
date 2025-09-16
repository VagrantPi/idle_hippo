# 階段 27-1｜Google 審核前 SKU 對照層（StoreId ↔ SkuId）

## 目標

建立一個純前端的「字串鍵位對照層」，把 **商店資料用的 `storeId`**（如 `store.card_click_perm`）按規則轉為 **IAP 用的 `skuId`**（如 `card_click_perm`）。

* 單向最低限度：`storeId -> skuId`
* 若 `storeId` 無對應，回傳明確錯誤（不可 fallback）。

### 規格

* 新增 `SkuMapper`（純同步函式，不做 IO）：
  * `String getSkuId(String storeId)`
* 對應表來源：你現有的 store JSON（`items` 的 key → 去掉 `store.` 前綴即為 `skuId`）
  * 例：`store.card_click_perm` → `card_click_perm`

## 驗收實例化需求

1. **對照成功**
   * Given：`store.card_click_perm`
   * When：呼叫 `getSkuId`
   * Then：回傳 `card_click_perm`
2. **對照失敗（不存在）**
   * Given：`store.not_exists`
   * When：呼叫 `getSkuId`
   * Then：丟出錯誤 `SkuMappingNotFound(storeId)`
3. **全域一致性檢查（靜態）**
   * 遍歷 `tabs.*[].items` 所有 `storeId`，皆能 `getSkuId` 成功。