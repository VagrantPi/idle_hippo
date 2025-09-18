# 階段 27-3｜權益發放 & 冪等

## 目標

集中管理「發獎」與「冪等處理」。

* non-consumable：設永久旗標
* consumable：加資源 & 記錄交易
* 任一交易 **同一 `orderId`/`purchaseToken` 只處理一次**
* 實現目前 store.json 中所有商品的購買後效益

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
* 實現目前 store.json 中所有商品的購買後效益
  * 下面每個商品效益或是數字要參數化，且互相獨立
* `store.card_click_perm`：購買成功時，每次點擊或獲得迷因點數額外 +50%
* `store.card_idle_perm`：購買成功時，idlePerSec 累積額外 +20%
* `store.card_click_2x_30m`：購買成功時，點擊收益乘以 2，並開始 30 分鐘倒數（重複購買延長 30 分鐘）
* `store.card_idle_2x_1h`：購買成功時，idlePerSec 乘以 2，並開始 1 小時倒數（重複購買延長 1 小時）
* `store.card_offline_perm_6h`：購買成功時，離線獎勵永久 +6 小時（由 6h → 12h）
* `store.card_offline_once_6h`：購買成功時，離線獎勵暫時 +6 小時，並開始 24 小時倒數（重複購買延長 24 小時）
* `store.card_cap_perm`：購買成功時，每日點擊上限永久 +50%（200 → 300）
* `store.ticket_pet_single`：購買成功時，寵物抽獎券 +1
* `store.ticket_pet_10plus1`：購買成功時，寵物抽獎券 +11
* `store.pack_daily`：立即獲得迷因點數 +300、寵物抽獎券 +2，並啟動 idle 2x（30 分鐘，重複購買延長 30 分鐘）
* `store.pack_monthly`：立即獲得迷因點數 +3000、寵物抽獎券 +22，並啟動 idle 2x（24 小時，重複購買延長 24 小時）
* `store.pack_7n_starter`：立即獲得迷因點數 +1000、寵物抽獎券 +11，並啟動 idle 2x（24 小時）
* `store.pack_30n_starter`：立即獲得迷因點數 +5000、寵物抽獎券 +33，並啟動 idle 2x（120 小時）


## 驗收實例化需求

1. **non-consumable 冪等**
   * Given：連續兩次 `grant(skuId='store.card_click_perm', orderId='A')`
   * Then：只會寫入一次 `entitlements.card_click_perm=true`（不重複觸發副作用）
2. **consumable 冪等**
   * Given：`grant(skuId='store.card_click_2x_30m', orderId='B')` 呼叫兩次
   * Then：資源僅被加一次，`orders.B` 僅一筆
3. **缺 orderId（恢復 non-consumable）**
   * Given：`grant(skuId='store.card_idle_perm', orderId=null)`
   * Then：仍能設置 entitlement 並具備冪等（重複呼叫不再觸發）
4. **store.card_click_perm：點擊加成 50%**
   * Given：原本點擊一次獲得 10 點迷因
   * When：`grant(skuId='store.card_click_perm')`
   * Then：點擊一次應獲得 `10 * 1.5 = 15 點`
5. **store.card_idle_perm：Idle 加成 20%**
   * Given：原本 idle 每秒 +5 點迷因
   * When：`grant(skuId='store.card_idle_perm')`
   * Then：idle 每秒應獲得 `5 * 1.2 = 6 點`
6. **store.card_click_2x_30m：點擊加倍限時 30 分鐘**
   * Given：原本點擊一次獲得 10 點迷因
   * When：`grant(skuId='store.card_click_2x_30m')`
   * Then：點擊一次應獲得 `10 * 2 = 20 點`，並建立一個 30 分鐘的倒數計時
   * When：再次購買
   * Then：倒數時間延長為 60 分鐘
7. **store.card_idle_2x_1h：Idle 加倍限時 1 小時**
   * Given：原本 idle 每秒 +5 點迷因
   * When：`grant(skuId='store.card_idle_2x_1h')`
   * Then：idle 每秒應獲得 `5 * 2 = 10 點`，並建立一個 1 小時的倒數計時
   * When：再次購買
   * Then：倒數時間延長為 2 小時
8. **store.card_offline_perm_6h：離線獎勵永久 +6 小時**
   * Given：原本離線可領取時間上限 = 6 小時
   * When：`grant(skuId='store.card_offline_perm_6h')`
   * Then：離線時間上限應為 `12 小時`
9. **store.card_offline_once_6h：離線獎勵暫時 +6 小時（24h 倒數）**
   * Given：原本離線時間上限 = 6 小時
   * When：`grant(skuId='store.card_offline_once_6h')`
   * Then：離線時間上限應為 `12 小時`，並建立一個 24 小時的倒數計時
   * When：再次購買
   * Then：倒數時間延長為 48 小時
10. **store.card_cap_perm：每日上限永久 +50%**
    * Given：原本每日上限 = 200 點
   * When：`grant(skuId='store.card_cap_perm')`
    * Then：每日上限應為 `200 * 1.5 = 300 點`
11. **store.ticket_pet_single：寵物抽獎券 +1**
    * Given：原本抽獎券數量 = 0
   * When：`grant(skuId='store.ticket_pet_single')`
    * Then：抽獎券數量 = 1
12. **store.ticket_pet_10plus1：寵物抽獎券 +11**
    * Given：原本抽獎券數量 = 0
   * When：`grant(skuId='store.ticket_pet_10plus1')`
    * Then：抽獎券數量 = 11
13. **store.pack_daily：每日禮包**
    * When：`grant(skuId='store.pack_daily')`
    * Then：
      * 迷因點數立即增加 300
      * 抽獎券數量 +2
      * idle 每秒累積翻倍（2x），並建立 30 分鐘倒數
    * When：再次購買
    * Then：倒數時間延長為 60 分鐘
14. **store.pack_monthly：每月禮包**
    * When：`grant(skuId='store.pack_monthly')`
    * Then：
      * 迷因點數立即增加 3000
      * 抽獎券數量 +22
      * idle 每秒累積翻倍（2x），並建立 24 小時倒數
    * When：再次購買
    * Then：倒數時間延長為 48 小時
15. **store.pack_7n_starter：新手 7 日禮包**
    * When：`grant(skuId='store.pack_7n_starter')`
    * Then：
      * 迷因點數立即增加 1000
      * 抽獎券數量 +11
      * idle 每秒累積翻倍（2x），並建立 24 小時倒數
16. **store.pack_30n_starter：新手 30 日禮包**
    * When：`grant(skuId='store.pack_30n_starter')`
    * Then：
      * 迷因點數立即增加 5000
      * 抽獎券數量 +33
      * idle 每秒累積翻倍（2x），並建立 120 小時倒數
