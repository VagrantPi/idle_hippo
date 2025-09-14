# 📄 Step 26-2 規格書（商城基礎 - 抽象化 Service）

---

## 1. 階段目標
- **將購買邏輯抽象化**，使 UI 與實際 SDK（IAP / Rewarded Ads）**完全解耦**。
- 提供可切換的 Service：`MockPurchaseService`（可用）／`IapPurchaseService`（佔位，未實作）。
- 依商品的 **限購型別** 與 **ads_pay** 規則，決定「購買按鈕是否可用」與「購買動作走向（IAP / RewardedAds）」。
- **不改動 UI** 結構；UI 僅依介面回傳狀態渲染。

---

## 2. 功能需求

### 2.1 架構概念
- **Catalog**：由 `ConfigService` 載入 `store.*` 商品定義（id/name/desc/image/purchase_limit_type/purchase_max_count/ads_pay）。
- **PurchaseService（抽象）**：統一查詢商品、下單、恢復購買、事件串流。
- **RewardedAdService（抽象）**：處理 `ads_pay=true` 商品的「看廣告兌換」流程。
- **PurchaseLimiter**：依限購規則計算「今日/本月/一次性」可購買次數、與跨日/跨月重置。
- **PurchaseRepository**：持久化每個商品的購買累計與重置錨點（secure storage）。

> **日界線**：一律以 **Asia/Taipei**。  
> `daily` 型別以「日變更」重置；`monthly` 以「年月變更」重置。

---

### 2.2 介面定義

#### 2.2.1 購買商品與事件
```dart
class ProductInfo {
  final String id;       // 商品 ID（= store.* key）
  final String name;     // UI 端自行做 i18n 映射
  final String desc;
  final String image;
  final double? price;   // Mock 可填，IAP 由 SDK 回傳
  final String? currency;

  ProductInfo({
    required this.id,
    required this.name,
    required this.desc,
    required this.image,
    this.price,
    this.currency,
  });
}

enum PurchaseStatus { pending, success, canceled, error }

class PurchaseEvent {
  final String productId;
  final PurchaseStatus status;
  final String? message; // 錯誤訊息、取消原因等

  PurchaseEvent({
    required this.productId,
    required this.status,
    this.message,
  });
}

abstract class PurchaseService {
  Future<List<ProductInfo>> queryProducts(List<String> ids);
  Stream<PurchaseEvent> get purchaseStream;
  Future<void> buy(String productId);   // UI 僅呼叫此方法
  Future<void> restore();               // iOS 必備，Mock 可回傳一筆成功
}
````

#### 2.2.2 看廣告購買（抽象）

```dart
enum RewardedStatus { opened, rewarded, closed, error }

abstract class RewardedAdService {
  /// 觸發一次看廣告流程；成功發放回傳 rewarded
  Future<RewardedStatus> show(String placement, {String? productId});
}
```

#### 2.2.3 限購與可購買邏輯

```dart
enum LimitType { limited, unlimited, daily, monthly, first7, first30 }

class PurchaseAvailability {
  final bool canBuy;
  final String? reasonKey; // i18n key: e.g. store.unavailable.daily_cap, store.unavailable.first7_expired
  final int remaining;     // 本視窗期內剩餘次數（-1 表示無上限）

  const PurchaseAvailability(this.canBuy, {this.reasonKey, this.remaining = -1});
}

abstract class PurchaseLimiter {
  /// 依商品規則（limitType / maxCount / adsPay）與當前時間、歷史購買資料，回傳可購買狀態
  PurchaseAvailability availability(String productId, DateTime nowLocal);

  /// 成功購買後更新計數（含跨期重置）
  Future<void> markPurchased(String productId, DateTime nowLocal);

  /// 跨日／跨月檢查與重置
  Future<void> ensureRollovers(DateTime nowLocal);
}
```

---

### 2.3 規則與流程

#### 2.3.1 按鈕是否可購買（UI 只看此結果）

* 讀取 `store.[id]`：

  * `purchase_limit_type == "limited"`：總購買次數 ≤ `purchase_max_count` 才可買。
  * `purchase_limit_type == "unlimited"`：永遠可買。
  * `purchase_limit_type == "daily"`：**當日**已購買次數 < `purchase_max_count` 才可買；跨日自動重置。
  * `purchase_limit_type == "monthly"`：**當月**已購買次數 < `purchase_max_count` 才可買；跨月自動重置。
  * `purchase_limit_type == "first7"` / `"first30"`：安裝起算第 7/30 天內才可買（逾期 `canBuy=false`）。
* **ads\_pay = true**：UI 按鈕文案顯示「看影片領取」；呼叫 `RewardedAdService.show()` → 若 `rewarded` 則視同購買成功。
* **ads\_pay = false**：呼叫 `PurchaseService.buy()`；Mock 2s 後成功；IAP 版未實作（先拋 `error` 或 `unimplemented`）。

#### 2.3.2 事件流

1. UI 點「購買」

   * `ads_pay=true` → `RewardedAdService.show("store_item", productId:id)`
   * `ads_pay=false` → `PurchaseService.buy(id)`
2. 成功（IAP 或 Ads）→ `PurchaseService.purchaseStream` 發出 `success` → `PurchaseLimiter.markPurchased(id, now)` → UI 收到成功事件僅 **顯示 Toast**（本階段不做權益下發）
3. 失敗/取消 → `PurchaseService.purchaseStream` 發出對應事件 → UI 顯示失敗/取消提示

---

### 2.4 持久化（PurchaseRepository）

* 儲存鍵：`game_state_v{save_version}.store`

```json
{
  "purchases": {
    "card_click_perm": { "total": 1 },
    "pack_daily": { "daily": { "date": "2025-09-12", "count": 2 } },
    "pack_monthly": { "monthly": { "ym": "2025-09", "count": 1 } }
  },
  "install": {
    "firstOpenDate": "2025-08-01"
  }
}
```

* 欄位說明：

  * `total`：一次性或無上限型的總次數。
  * `daily.date` / `daily.count`：今日日期（以 **Asia/Taipei**）、今日累積。
  * `monthly.ym` / `monthly.count`：本月字串 `YYYY-MM`、本月累積。
  * `firstOpenDate`：新手期限購判定的起算日（以 Asia/Taipei 轉字串）。

---

### 2.5 Mock 與 IAP 服務

#### 2.5.1 MockPurchaseService（可用）

* `queryProducts(ids)`：回傳 mock 內容（價格 `1.99`、幣別 `USD`）。
* `buy(productId)`：`await 2s` → 發出 `PurchaseStatus.success`。
* `restore()`：`await 1s` → 發出一筆 `card_click_perm` 的 `success` 事件。

> 你提供的 Mock 程式碼可直接採用。

#### 2.5.2 IapPurchaseService（佔位）

* 先保留空殼，方法丟 `UnimplementedError()` 或回 `error` 事件。
* 待「商城基礎（交易框架）」階段才串真 SDK。

#### 2.5.3 RewardedAdService（Mock）

```dart
class MockRewardedAdService implements RewardedAdService {
  @override
  Future<RewardedStatus> show(String placement, {String? productId}) async {
    await Future.delayed(const Duration(seconds: 2));
    return RewardedStatus.rewarded; // 一律成功
  }
}
```

---

### 2.6 UI 接線（不改視覺）

* UI 進入商城時：

  1. 以 `ConfigService` 讀商品清單 ids
  2. `PurchaseService.queryProducts(ids)`（若需要顯示價格；無則可略）
  3. 對每個商品呼叫 `PurchaseLimiter.availability(id, nowTaipei)` 決定按鈕 enable 與提示
* 點擊按鈕：

  * `ads_pay=true` → `RewardedAdService.show(...)`
  * `ads_pay=false` → `PurchaseService.buy(id)`
* 監聽 `purchaseStream`：

  * `success` → `PurchaseLimiter.markPurchased(id, now)` → 顯示「成功」Toast
  * `canceled/error` → 顯示「已取消／失敗」Toast

---

## 3. 驗收標準

* ✅ **可切換 Service**：以依賴注入切換 `MockPurchaseService`／`IapPurchaseService`，UI 無需修改即可運作（IAP 版回傳未實作錯誤，不當機）。
* ✅ **按鈕可用性正確**：

  * `limited`：達到 `purchase_max_count` 後按鈕禁用。
  * `unlimited`：永遠可購買（UI 永遠可按）。
  * `daily`：當日達上限後禁用；**跨日**恢復。
  * `monthly`：當月達上限後禁用；**跨月**恢復。
  * `first7/first30`：於新手期內可買，期滿禁用。
* ✅ **ads\_pay 行為**：`ads_pay=true` 的商品會呼叫 `RewardedAdService.show()`；回傳 `rewarded` → 視同購買成功。
* ✅ **事件回傳**：Mock 下單 2 秒後觸發 `success`；UI 正常接收並顯示提示。
* ✅ **持久化**：重啟 App 後，商品的已購次數／當日/當月計數仍正確；跨日/跨月後自動重置視窗計數。
* ✅ **時區一致**：日界線與月界線判定以 Asia/Taipei 為準。

---

## 4. 實例化需求測試案例

### 案例 1：limited 一次性

* **Given** `card_click_perm`（limited, max=1）
* **When** 連續購買 1 次
* **Then** 第二次按鈕禁用，`availability.canBuy=false`

### 案例 2：daily 限購 + 跨日

* **Given** `pack_daily`（daily, max=3），當前日期 D
* **When** 連買 3 次 → 第 4 次應禁用
* **Then** 將系統時區設為 Asia/Taipei 並模擬跨至 D+1
* **Then** 按鈕重新可買（remaining=3）

### 案例 3：monthly 限購 + 跨月

* **Given** `pack_monthly`（monthly, max=3），當前月份 M
* **When** 連買 3 次 → 第 4 次應禁用
* **Then** 模擬跨至月份 M+1（Asia/Taipei）
* **Then** 按鈕重新可買（remaining=3）

### 案例 4：first7 / first30 有效期

* **Given** `firstOpenDate=2025-08-01`（台北時間）
* **When** 在 8/02 ～ 8/07 期間購買 `pack_7n_starter`
* **Then** 可購買；8/08 起禁用（reasonKey=`store.unavailable.first7_expired`）

### 案例 5：ads\_pay 購買

* **Given** `pack_daily`（ads\_pay=true, daily, max=3）
* **When** 點擊按鈕 → 呼叫 `RewardedAdService.show()` → Mock 回傳 `rewarded`
* **Then** 觸發 `PurchaseEvent.success` 並累計當日次數 +1

### 案例 6：切換 Service

* **Given** 以依賴注入將 `PurchaseService` 由 Mock 換成 IAP 佔位
* **When** 點擊購買
* **Then** UI 收到 `error/unimplemented` 事件並顯示錯誤，不噴例外、不閃退

### 案例 7：重啟持久化

* **Given** `pack_daily` 當日已買 2 次
* **When** 重啟 App
* **Then** 仍顯示當日剩餘 1 次；跨日後自動回復 3 次

---

## 5. 限制與備註

* 本階段 **不發放權益**、不處理 NO-ADS、也不進行實際 IAP 驗證；僅完成 **抽象層與可買狀態**。
* 跨日/跨月判定須以 **Asia/Taipei** 建立 `Date/YearMonth` 錨點，避免裝置時區差異造成錯誤。
* `RewardedAdService` 未來可替換實際 SDK（AdMob, ironSource…）；`placement` 請固定傳 `"store_item"` 與 `productId` 方便事件追蹤。
* 後續在「商城基礎（交易框架）」步驟接：
  權益下發、去廣告態、GA4 事件、錯誤碼對應、重試策略、UI 回饋（loading/disabled/錯誤提示文案）。
