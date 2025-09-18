# 階段 27-4｜購買限制規則（limited/daily/monthly/first7/first30）

## 目標

將你 JSON 的購買限制在前端落地：

* `purchase_limit_type` ∈ `limited|unlimited|daily|monthly|first7|first30`
* `purchase_max_count`（對 `limited` 使用；其他型別視為當期上限=1）

### 規格

* 新增 `PurchaseLimitPolicy`
  * `bool canPurchase(String storeId, DateTime now)`
  * `void recordPurchase(String storeId, DateTime now)`
  * `int remainingQuota(String storeId, DateTime now)`（UI 顯示用）
* 時區：**Asia/Taipei**（沿用你 RewardedAdService 的策略）
* 雜湊鍵建議：
  * daily：`limit:daily:<YYYY-MM-DD>:<storeId>`
  * monthly：`limit:monthly:<YYYY-MM>:<storeId>`
  * first7/first30：以「首次啟動日」為基準，若 `now - firstLaunchDate > N 天`，返回不可購
  * limited：`limit:once:<storeId>` + 計數

## 驗收實例化需求

1. **limited**
   * Given：`purchase_limit_type=limited`, `purchase_max_count=1`
   * When：首次購買 → `canPurchase=true`；`recordPurchase` 後
   * Then：再次檢查 `canPurchase=false`
2. **daily**
   * Given：`purchase_limit_type=daily`
   * When：今日購買一次 → `canPurchase=false`；跨日 → `canPurchase=true`
3. **monthly**
   * Given：`purchase_limit_type=monthly`
   * When：本月已購 → `canPurchase=false`；下個月 → `canPurchase=true`
4. **first7**
   * Given：首次啟動日起第 8 天
   * Then：`canPurchase=false`
5. **remainingQuota**
   * 應能正確反映各型別剩餘次數（`limited=0/1`, `daily=0/1`, `monthly=0/1`）