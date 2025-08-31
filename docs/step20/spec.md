# 📄 Step 20 規格書（稱號系統）

## 1. 階段目標
- 實作「稱號圖鑑」：分為 **未取得** / **已取得** 兩個 Tab，皆為**兩欄網格**排列（MVP）。
- 稱號具備三種狀態：`locked(鎖定/隱藏)`、`claimable(可領取)`、`claimed(已領取)`。
- 有可領取稱號時，在**主畫面底下 Navbar 的「稱號」入口**與稱號頁內的 **未取得** Tab 上顯示**小紅點**（動畫沿用任務頁按鈕效果）。
- 稱號需**按下「領取」**才會從「未取得」移到「已取得」。
- 支援「隱藏型」：若 `type=hidden`，在鎖定時描述以 **`????`** 顯示（名稱不隱藏）。
- 稱號頁面具**整頁鎖定機制**：主線未超過第二章完成（`stage <= 2`）時，整頁灰階並顯示解鎖提示。
- 當 **未取得** 分頁所有稱號都取得完畢時，顯示「已取得所有稱號」提示。

---

## 2. 功能需求

### 2.1 UI/UX
- 入口：主畫面右側功能列「稱號」圖示。
- 稱號頁：
  - **Tab**：`未取得`、`已取得`（預設顯示「未取得」）。
  - **列表樣式**：兩欄網格卡片；卡片內容：
    - 圖示（可用占位圖示）/稱號名稱/簡短描述或提示。
    - 鎖定時（`type=hidden`）描述以 `????` 顯示；名稱仍顯示本地化名稱。
    - **領取按鈕**：僅在 `claimable` 狀態顯示；點擊後移入「已取得」Tab。
- **小紅點**：
  - 規則：當任一稱號 `claimable=true` → 在主畫面 navbar 功能列入口與「未取得」Tab 標籤上顯示紅點；無可領取則隱藏。
  - 動畫：沿用任務頁按鈕紅點的縮放/閃爍參數（共用一份 `PulseDotAnim`）。
- 整頁鎖定時顯示半透明遮罩與提示文案。

### 2.2 稱號資料（MVP 資料鍵位）
- 來源：`ConfigService().getValue('titles.titles')`（JSON 內部結構為 `{"titles": [ ... ]}`）。
- 欄位：`id`、`name_key`、`desc_key`、`hidden_desc_key`、`type`（`type` 可為 `hidden` 表示鎖定時描述使用隱藏文案）。
```json
[
  {
    "id": "title.sample_hidden",
    "type": "hidden",
    "name_key": "title.sample_hidden.name",
    "desc_key": "title.sample_hidden.desc",
    "hidden_desc_key": "title.hidden"
  },
  {
    "id": "title.sample_normal",
    "name_key": "title.sample_normal.name",
    "desc_key": "title.sample_normal.desc"
  }
]
````

> 註：`reveal=false` 之稱號，在未達成前以 `????` 顯示；達成當下改用 `reveal_desc_key` 顯示真正條件文。

### 2.3 觸發條件（事件對接）

* `mainline_completed(stageId)`：主線完成事件（Step 14）。
* `gacha_obtained(rarity, petId)`：抽卡獲得結果（Step 17）。
* `equip_level_changed(equipId, newLevel)`：裝備升級事件（Step 7/9）。
* 每次相關事件觸發 → 重新評估所有 `locked`/`claimable` 稱號。

### 2.4 狀態流與領取

* 狀態定義：

  * `locked`：條件未達；若 `type=hidden`，描述顯示 `????`（名稱不隱藏）。
  * `claimable`：可領取，顯示【領取】。
  * `claimed`：已領取，顯示於「已取得」Tab。
* 領取流程：

  1. 玩家點擊【領取】 → 將該稱號狀態標記為 `claimed`（MVP 本地狀態）。
  2. 移動到「已取得」Tab。

### 2.5 排序規則

* 「未取得」：`claimable` 在最前，其後 `locked`（按配置順序）。
* 「已取得」：依領取時間由新到舊（新領取置頂）。
* 皆維持兩欄網格，行高自適應多語長度（至少 2 行）。

### 2.6 儲存/持久化

* `game_state_v{save_version}.titles`：

```json
{
  "states": {
    "title.rookie": "claimed",
    "title.ssr_collector": "locked",
    "title.title_114514": "locked",
    "title.crypto_expert": "claimable",
    "title.king_of_meme": "locked"
  },
  "claimedAt": { "title.rookie": 1692860000000 },
  "redDot": { "hasClaimable": true }
}
```

### 2.7 i18n（最少鍵）

```json
{
  "title.tab.unlocked": {"zh":"已取得","en":"Unlocked","jp":"取得済み","ko":"획득됨"},
  "title.tab.locked":   {"zh":"未取得","en":"Locked","jp":"未取得","ko":"미획득"},
  "title.btn.claim":    {"zh":"領取","en":"Claim","jp":"受け取る","ko":"받기"},
  "title.hidden":       {"zh":"????","en":"????","jp":"????","ko":"????"},

  "title.rookie.name":  {"zh":"迷因菜鳥稱號","en":"Meme Rookie","jp":"ミームビギナー","ko":"밈 루키"},
  "title.rookie_desc":  {"zh":"完成主線『迷因小菜鳥階段』","en":"Finish Mainline: Meme Rookie"},
  "title.ssr_collector.name":{"zh":"專業迷因收藏者","en":"Pro Meme Collector"},
  "title.ssr_collector_desc":{"zh":"至少獲得 1 個 SSR 寵物","en":"Obtain ≥1 SSR Pet"},
  "title.title_114514.name":  {"zh":"いいよ！ こいよ！","en":"Iiyo! Koiyo!"},
  "title.title_114514_desc":  {"zh":"裝備 114514 等級達 10","en":"Equip 114514 reaches Lv.10"},
  "title.crypto_expert.name":{"zh":"虛擬貨幣專家","en":"Crypto Expert"},
  "title.crypto_expert.hint_hidden":{"zh":"????","en":"????"},
  "title.crypto_expert.hint_reveal":{"zh":"裝備 BTC Lv10 + DOGE Lv10","en":"BTC Lv10 + DOGE Lv10"},
  "title.king_of_meme.name":{"zh":"迷因之王","en":"King of Meme"},
  "title.king_of_meme_desc":{"zh":"收集所有其他稱號","en":"Collect all other titles"}
}
```

### 2.8 Telemetry（預留至 Step 33）

* `title_unlocked {id}`
* `title_claimed {id}`
* `title_revealed {id}`（由 `????` → 顯示真條件時）

---

好的 ✅ 我會根據你剛貼的 **Step 20 規格書（稱號系統）** 補齊

---

# 📄 Step 20 規格書（稱號系統）續篇

## 3. 驗收標準

* ✅ 主畫面右側功能列「稱號」入口存在，並能正常開啟稱號頁。
* ✅ 稱號頁分為 **未取得** / **已取得** 兩個 Tab，排列為兩欄網格。
* ✅ 未達成條件的稱號狀態正確顯示 `locked`；若 `type=hidden` 則描述顯示 `????`。
* ✅ 當條件達成後，稱號自動轉為 `claimable`，並在稱號入口與未取得 Tab 上顯示小紅點。
* ✅ 點擊「領取」後，稱號正確移至「已取得」Tab，並依照領取時間由新到舊排序。
* ✅ 「已取得」Tab 正確顯示領取過的稱號，完成度百分比會更新。
* ✅ 主線未達到 `stage > 2` 前，整個稱號頁以灰階顯示並顯示「解鎖提示」。
* ✅ 稱號狀態會正確持久化到存檔，重啟遊戲後保持一致。
* ✅ 小紅點狀態隨 `claimable` 移除而消失，動畫沿用任務頁按鈕。
* ✅ i18n 正確套用，切換語系時 UI 文字正常顯示。

---

## 4. 實例化需求測試案例

### 測試案例 1：稱號入口與鎖定狀態

* **Given** 玩家剛完成主線第一章（stage=1）
* **When** 打開稱號頁
* **Then** 整頁灰階，顯示「需完成主線第二章解鎖」提示

---

### 測試案例 2：隱藏型稱號顯示

* **Given** 玩家未達成「虛擬貨幣專家」條件
* **When** 打開稱號頁
* **Then** 「虛擬貨幣專家」顯示名稱，但描述為「????」

---

### 測試案例 3：條件達成 → 可領取

* **Given** 玩家將 BTC 裝備升至 Lv10，DOGE 裝備升至 Lv10
* **When** 重新打開稱號頁
* **Then** 「虛擬貨幣專家」變為 `claimable`，描述顯示「BTC Lv10 + DOGE Lv10」，未取得 Tab 顯示紅點

---

### 測試案例 4：領取流程

* **Given** 玩家稱號「虛擬貨幣專家」狀態為 `claimable`
* **When** 玩家點擊「領取」
* **Then** 該稱號狀態轉為 `claimed`，移至「已取得」Tab，未取得 Tab 紅點消失

---

### 測試案例 5：SSR 寵物觸發

* **Given** 玩家抽到第一隻 SSR 寵物
* **When** 稱號系統更新
* **Then** 「專業迷因收藏者」變為 `claimable`，並出現在未取得 Tab

---

### 測試案例 6：排序驗證

* **Given** 玩家同時達成兩個稱號條件（迷因菜鳥、SSR 收藏者）
* **When** 打開未取得 Tab
* **Then** 兩者皆為 `claimable`，排序按照配置順序顯示
* **And** 領取後，已取得 Tab 依領取順序，最新的在最上方

---

### 測試案例 7：持久化驗證

* **Given** 玩家已領取「迷因菜鳥稱號」
* **When** 關閉 App 再重啟
* **Then** 已取得 Tab 正確顯示「迷因菜鳥稱號」，未取得 Tab 不再顯示

---

### 測試案例 8：i18n 驗證

* **Given** 系統語言切換為日文
* **When** 打開稱號頁
* **Then** Tab、稱號名稱、描述正確顯示日文（如「取得済み」「ミームビギナー」）


---

## 5. 限制與備註

* 本階段**不提供能力加成**，稱號為展示/收集要素；屬性加成若日後需要，另開 Step。
* `equip.title_114514` 僅為佔位裝備 ID：若尚未實裝該裝備，稱號仍保留在 `locked`；可用 Debug 補測。
* 「迷因之王」需**所有其他稱號 `claimed`** 才可領取，避免自我依賴。
* 小紅點動畫與任務紅點共用組件，確保一致性與維護成本。
* 多語系：所有標籤、稱號名與描述、提示文案均走 i18n；長字串需自動換行不截斷。
