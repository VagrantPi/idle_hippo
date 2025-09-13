# 📄 Step 26 規格書（商城基礎 - 規則與購買）

---

## 1. 階段目標
- 實作商城頁面 UI 與基本購買規則（含次數限制與持久化）。
- 兩個 Tab：
  1) **常駐資源**（單欄橫幅清單，含分組標題與卡片項目）
  2) **限時優惠包**（單欄橫幅清單，含分組標題與卡片項目）
- 介面文案全面支援 **i18n**。
- 圖資由設定檔載入（提供占位 fallback），可直觀捲動瀏覽。

> 註：需求敘述中「臨時加成卡」重複了 `card_click_2x_30m`；以提供的 JSON 為準，第二張為 **`card_idle_2x_1h`**。

---

## 2. 功能需求

### 2.1 導覽與結構
- 入口：主畫面右側功能列「商城」圖示。
- 商城場景：
  - 頂部 **Segmented Tab**：`常駐資源` / `限時優惠包`
  - 內容區：垂直捲動；每個 Tab 內為 **單欄橫幅卡**清單，卡片依「分組標題」區塊化顯示。
  - 返回按鈕：左上角返回（回主畫面）。

### 2.2 清單分組與項目（由設定檔渲染）
**Tab：常駐資源**
- 分組一《迷因點數加成卡》
  - `store.card_click_perm`
  - `store.card_idle_perm`
- 分組二《臨時加成卡》
  - `store.card_click_2x_30m`
  - `store.card_idle_2x_1h`
- 分組三《離線掛機時間加成》
  - `store.card_offline_perm_6h`
  - `store.card_offline_once_6h`
- 分組四《點擊上限提升》
  - `store.card_cap_perm`
- 分組五《寵物抽獎券》
  - `store.ticket_pet_single`
  - `store.ticket_pet_10plus1`

**Tab：限時優惠包**
- 分組一《每日限購禮包》
  - `store.pack_daily`
- 分組二《每月限購禮包》
  - `store.pack_monthly`
- 分組三《新手成長包》
  - `store.pack_7n_starter`
  - `store.pack_30n_starter`

### 2.3 卡片樣式（通用）
- 版型：橫幅卡（全寬，卡內左右排列）
  - 左：商品圖片（方形或 4:3，固定尺寸，超出裁切，支援圓角）
  - 右：文案堆疊
    - **名稱**（粗體，單行溢出省略）
    - **描述**（至多 2 行，溢出省略）
    - 底部輔助列：
      - 「購買」按鈕（實際執行購買，受限於規則）
      - 若 `ads_pay=true`，在右側再顯示「看廣告購買」按鈕（觀看完成才執行購買）
      - 限制標籤（依 `purchase_limit_type` 顯示不同樣式）：
        - `limited`：`一次性`
        - `unlimited`：`可重複`
        - `daily`：`每日限購`
        - `monthly`：`每月限購`
        - `first7`：`前 7 天`
        - `first30`：`前 30 天`
      - 若 `ads_pay=true`，在卡片右上角顯示「🎬」小角標
- 互動：
  - 點擊卡片：僅做 **波紋/縮放回饋**；不彈出購買／詳情（本階段不實作邏輯）
- i18n：
  - 名稱、描述與分組標題皆走多語鍵值
- 圖片：
  - 來源 `store.*.image`；若載入失敗顯示 placeholder：`/assets/images/store/placeholder.png`

### 2.4 資料來源與鍵位
- 由 `ConfigService` 載入 `store` 節點（你提供的 JSON 結構）。
- 使用鍵：`name`、`desc`、`image`、`purchase_limit_type`、`purchase_max_count`、`ads_pay`
- Tab/分組標題 i18n 鍵（新增最小集）：
```json
{
  "store.tab.permanent": {"zh":"常駐資源","en":"Permanent"},
  "store.tab.limited":   {"zh":"限時優惠包","en":"Limited Offers"},

  "store.section.boost_permanent": {"zh":"迷因點數加成卡","en":"Meme Point Boosters"},
  "store.section.boost_temporary": {"zh":"臨時加成卡","en":"Temporary Boosters"},
  "store.section.offline":         {"zh":"離線掛機時間加成","en":"Offline Cap Boost"},
  "store.section.tap_cap":         {"zh":"點擊上限提升","en":"Tap Cap Increase"},
  "store.section.tickets":         {"zh":"寵物抽獎券","en":"Pet Gacha Tickets"},

  "store.section.daily":           {"zh":"每日限購禮包","en":"Daily Packs"},
  "store.section.monthly":         {"zh":"每月限購禮包","en":"Monthly Packs"},
  "store.section.starter":         {"zh":"新手成長包","en":"Starter Packs"},

  "store.badge.once":    {"zh":"一次性","en":"One-time"},
  "store.badge.repeat":  {"zh":"可重複","en":"Repeatable"},
  "store.badge.daily":   {"zh":"每日限購","en":"Daily Limit"},
  "store.badge.monthly": {"zh":"每月限購","en":"Monthly Limit"},
  "store.badge.first7":  {"zh":"前 7 天","en":"First 7 Days"},
  "store.badge.first30": {"zh":"前 30 天","en":"First 30 Days"},
  "store.badge.ads":     {"zh":"影片回饋","en":"Ad Reward"},

  "store.btn.buy":       {"zh":"購買","en":"Buy"},
  "store.btn.disabled":  {"zh":"未開放","en":"Disabled"}
}
````

### 2.5 購買與呈現規則

* **排序**：按上述分組順序；分組內依固定鍵順序。
* **Sticky 分組標題**：分組標題在捲動交界可吸頂 4px（若實作成本高，可先不吸頂，保持標題與列表間距）。
* **空態**：若某分組沒有項目（未來 A/B 刪除），隱藏該分組區塊。
* **適配**：中文/英文字串長度差異需保證不換行錯位（標題 1 行、描述最多 2 行，超出省略號）。

購買限制規則（以 `purchase_limit_type` 判定）：
- `unlimited`：無上限，永遠可購買。
- `limited`：終身上限；終身購買次數 < `purchase_max_count` 時可購買。
- `daily`：每日上限；當天購買次數 < `purchase_max_count` 時可購買，隔日自動歸零（時區：Asia/Taipei）。
- `monthly`：每月上限；當月購買次數 < `purchase_max_count` 時可購買，跨月自動歸零（時區：Asia/Taipei）。
- `first7`：安裝後前 7 天可購買；在視窗內且終身次數 < `purchase_max_count` 時可購買（終身累計，不重置）。
- `first30`：安裝後前 30 天可購買；在視窗內且終身次數 < `purchase_max_count` 時可購買（終身累計，不重置）。

廣告購買（`ads_pay=true`）：
- 顯示兩顆按鈕：「購買」與「看廣告購買」。
- 按下「看廣告購買」後，透過 `RewardedAdService.showAd` 播放激勵流程，完成才執行同樣的購買邏輯。

---

## 3. 驗收標準

* ✅ 進入「商城」可見 **兩個 Tab**，可切換且保留各自捲動位置。
* ✅ 「常駐資源」Tab 依 5 個分組顯示，項目對應 JSON 鍵完整渲染。
* ✅ 「限時優惠包」Tab 依 3 個分組顯示，項目對應 JSON 鍵完整渲染。
* ✅ 每張卡片呈現：圖片、名稱、描述、限制標籤、購買按鈕（受規則啟用/停用）。
* ✅ 若圖片路徑錯誤或載入失敗，顯示 placeholder。
* ✅ i18n 切換語言後，**Tab 標籤/分組標題/商品名稱/描述/標籤文案**皆即時切換。
* ✅ `ads_pay=true` 的商品於卡片右上角顯示 🎬 角標。
* ✅ `ads_pay=true` 的商品，同時顯示「購買」與「看廣告購買」兩顆按鈕，後者需觀看完成才購買。

---

## 4. 實例化需求測試案例（購買規則）

### 測試案例 1：結構與分組

* **Given** 載入提供之 `store` JSON
* **When** 進入商城
* **Then** Tab=常駐資源：5 個分組標題依序呈現且每組含指定項目；Tab=限時優惠包：3 個分組依序呈現

### 測試案例 2：卡片視覺元素

* **Given** `store.card_click_perm`
* **When** 顯示於清單
* **Then** 名稱/描述/圖片/限制標籤（一次性）/Disabled 購買按鈕 皆存在

### 測試案例 3：ads 角標

* **Given** `store.pack_daily`（`ads_pay=true`）
* **When** 顯示於清單
* **Then** 卡片右上角顯示 🎬 角標

### 測試案例 4：圖片失敗 fallback

* **Given** 暫時改壞 `image` 路徑
* **When** 重新進入商城
* **Then** 顯示 placeholder 圖而非破圖

### 測試案例 5：i18n 切換

* **Given** 進入商城
* **When** 將語言從 ZH 切換至 EN
* **Then** Tab 標籤、分組標題、卡片名稱與描述、限制標籤文字全部切換為英文

### 測試案例 6：unlimited 可重複
* Given 任一 `unlimited` 之 item
* When 連續購買 5 次
* Then 成功且終身計數 = 5

### 測試案例 7：limited 終身上限
* Given `limited` 且 `purchase_max_count=1`
* When 第 1 次購買成功，第 2 次不可購買
* Then 終身計數 = 1

### 測試案例 8：daily 每日重置
* Given `daily` 且 `purchase_max_count=1`
* When 今日購買 1 次後，第 2 次不可購買；隔日清空後可再次購買
* Then 每日計數會在新一天歸零

### 測試案例 9：monthly 每月重置
* Given `monthly` 且 `purchase_max_count=1`
* When 當月購買 1 次後，第 2 次不可購買；跨月清空後可再次購買
* Then 每月計數會在新月份歸零

### 測試案例 10：first7 首 7 天限制
* Given `first7` 且 `purchase_max_count=1`
* When 安裝後 7 天內可購買 1 次；第 8 天後不可購買
* Then 終身計數 = 1，視窗外不可購買

### 測試案例 11：first30 首 30 天限制
* Given `first30` 且 `purchase_max_count=1`
* When 安裝後 30 天內可購買 1 次；第 31 天後不可購買
* Then 終身計數 = 1，視窗外不可購買

### 測試案例 12：ads_pay 廣告購買
* Given `ads_pay=true` 之 item
* When 點擊「看廣告購買」，廣告完成
* Then 觸發購買計數 +1；若達上限則不可再購買

---

## 5. 限制與備註

* 本階段**不實作**：真實 IAP／廣告 SDK、權益發放、NO-ADS 狀態。
* 之後在「商城基礎（交易框架）」階段接手：接上 IAP/廣告 SDK、權益發放與持久化。
* 若未提供 i18n 文案，先沿用 JSON 內 `name/desc`，並在控制台警告缺失鍵值。
