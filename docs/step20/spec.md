# 📄 Step 20 規格書（稱號系統）

## 1. 階段目標
- 實作「稱號圖鑑」：分為 **未取得** / **已取得** 兩個 Tab，皆為**三欄網格**排列。
- 稱號具備三種狀態：`locked(鎖定/隱藏)`、`claimable(可領取)`、`claimed(已領取)`。
- 有可領取稱號時，在**主畫面右側功能列的「稱號」入口**與稱號頁 Tab 上顯示**小紅點**（動畫沿用任務頁按鈕效果）。
- 稱號需**按下「領取」**才會從「未取得」移到「已取得」。
- 支援「條件隱藏」：部分稱號在未達條件前僅顯示 **`????`**；達成後才揭露實際條件文案。
- （跨頁關聯）**任務頁面**：完成主線【梗圖河馬階段】後解鎖「裝備任務」Tab；解鎖前該 Tab 顯示鎖定與提示 **「寵物系統需要完成主線第二章解鎖」**。

---

## 2. 功能需求

### 2.1 UI/UX
- 入口：主畫面右側功能列「稱號」圖示。
- 稱號頁：
  - **Tab**：`未取得`、`已取得`（預設顯示「未取得」）。
  - **列表樣式**：三欄網格卡片；卡片內容：
    - 圖示（可共用占位圖或對應主題圖）/稱號名稱/簡短描述或條件提示。
    - 狀態徽記：`????`（未揭露）、`可領取`、`已取得`。
    - **領取按鈕**：僅在 `claimable` 狀態顯示；點擊後移入「已取得」Tab。
- **小紅點**：
  - 規則：當任一稱號 `claimable=true` → 在功能列入口與「未取得」Tab 標籤上顯示紅點；無可領取則隱藏。
  - 動畫：沿用任務頁按鈕紅點的縮放/閃爍參數（共用一份 `PulseDotAnim`）。

### 2.2 稱號資料（資料化）
- 檔案：`assets/config/titles.json`，欄位建議：
```json
[
  {
    "id": "title.rookie",
    "name_key": "title.rookie.name",
    "desc_key": "title.rookie.desc",
    "reveal": true,
    "condition": { "type": "mainline_completed", "value": "stage2" }
  },
  {
    "id": "title.ssr_collector",
    "name_key": "title.ssr_collector.name",
    "desc_key": "title.ssr_collector.desc",
    "reveal": true,
    "condition": { "type": "own_any_pet_rarity_at_least", "value": "SSR" }
  },
  {
    "id": "title.title_114514",
    "name_key": "title.title_114514.name",
    "desc_key": "title.title_114514.desc",
    "reveal": true,
    "condition": { "type": "equip_level_reach", "equip_id": "equip.title_114514", "level": 10 }
  },
  {
    "id": "title.crypto_expert",
    "name_key": "title.crypto_expert.name",
    "desc_key": "title.crypto_expert.desc",
    "reveal": false,
    "hidden_hint_key": "title.crypto_expert.hint_hidden",
    "reveal_desc_key": "title.crypto_expert.hint_reveal",
    "condition": { "type": "equip_multi_level_and", "rules": [
      { "equip_id": "equip.BTC", "level": 10 },
      { "equip_id": "equip.DOGE", "level": 10 }
    ]}
  },
  {
    "id": "title.king_of_meme",
    "name_key": "title.king_of_meme.name",
    "desc_key": "title.king_of_meme.desc",
    "reveal": true,
    "condition": { "type": "all_titles_claimed_except", "exclude": ["title.king_of_meme"] }
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

  * `locked`：條件未達；若 `reveal=false`，名稱顯示 `????`，描述顯示 `????` 或 `hidden_hint_key`。
  * `claimable`：達成條件，顯示真實名稱與條件說明，顯示【領取】。
  * `claimed`：已領取，顯示於「已取得」Tab。
* 領取流程：

  1. 玩家點擊【領取】 → 將該稱號狀態標記為 `claimed`。
  2. 觸發 UI 提示與音效；移動到「已取得」Tab。
  3. 檢查是否觸發「迷因之王」條件（全稱號已領取）。

### 2.5 排序規則

* 「未取得」：`claimable` 在最前（按可領取時間由新到舊），其後 `locked`（按配置順序）。
* 「已取得」：依領取時間由新到舊。
* 皆維持三欄網格，行高自適應多語長度（至少 2 行）。

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
  "title.rookie.desc":  {"zh":"完成主線『迷因小菜鳥階段』","en":"Finish Mainline: Meme Rookie"},
  "title.ssr_collector.name":{"zh":"專業迷因收藏者","en":"Pro Meme Collector"},
  "title.ssr_collector.desc":{"zh":"至少獲得 1 個 SSR 寵物","en":"Obtain ≥1 SSR Pet"},
  "title.title_114514.name":  {"zh":"いいよ！ こいよ！","en":"Iiyo! Koiyo!"},
  "title.title_114514.desc":  {"zh":"裝備 114514 等級達 10","en":"Equip 114514 reaches Lv.10"},
  "title.crypto_expert.name":{"zh":"虛擬貨幣專家","en":"Crypto Expert"},
  "title.crypto_expert.hint_hidden":{"zh":"????","en":"????"},
  "title.crypto_expert.hint_reveal":{"zh":"裝備 BTC Lv10 + DOGE Lv10","en":"BTC Lv10 + DOGE Lv10"},
  "title.king_of_meme.name":{"zh":"迷因之王","en":"King of Meme"},
  "title.king_of_meme.desc":{"zh":"收集所有其他稱號","en":"Collect all other titles"}
}
```

### 2.8 Telemetry（預留至 Step 33）

* `title_unlocked {id}`
* `title_claimed {id}`
* `title_revealed {id}`（由 `????` → 顯示真條件時）

---

## 3. 驗收標準

* ✅ **Tab 與三欄**：稱號頁分為「未取得 / 已取得」兩個 Tab，皆為三欄網格。
* ✅ **小紅點**：當任一稱號進入 `claimable` → 主功能列「稱號」入口與稱號頁 Tab 出現紅點動畫；全部領取後紅點消失。
* ✅ **隱藏顯示**：`虛擬貨幣專家` 初始顯示 `????`；當 **BTC Lv10 且 DOGE Lv10** 時，立即顯示文字 **「裝備 BTC lv10 + DOGE lv10」**，並顯示【領取】按鈕可點擊。
* ✅ **領取遷移**：點擊【領取】後，該稱號從「未取得」移至「已取得」，狀態持久化；重啟 App 仍維持。
* ✅ **關聯規則**：完成主線【梗圖河馬階段】後，任務頁面解鎖「裝備任務」Tab；解鎖前顯示鎖定與提示 **「寵物系統需要完成主線第二章解鎖」**（文案一致）。
* ✅ **迷因之王**：當除 `title.king_of_meme` 外的所有稱號皆 `claimed` 時，`title.king_of_meme` 進入 `claimable`，可領取後顯示於「已取得」。

---

## 4. 實例化需求測試案例

### 測試 1：隱藏→揭露→領取

* **Given** `BTC Lv9`、`DOGE Lv9`，`title.crypto_expert` 為 `locked(reveal=false)`，稱號卡顯示 `????`
* **When** 升級 `BTC` 至 `Lv10` 與 `DOGE` 至 `Lv10`
* **Then** `title.crypto_expert` 變為 `claimable`，描述顯示「裝備 BTC Lv10 + DOGE Lv10」，小紅點出現
* **When** 點【領取】
* **Then** 移至「已取得」Tab，小紅點若無其他可領取則隱藏

### 測試 2：主線觸發的稱號

* **Given** 尚未完成主線 `stage2(迷因小菜鳥階段)`
* **When** 完成 `stage2`
* **Then** `title.rookie` → `claimable`，可領取

### 測試 3：SSR 寵物稱號

* **Given** 尚無 SSR 寵物
* **When** 透過抽卡獲得任一 SSR
* **Then** `title.ssr_collector` → `claimable`，小紅點提示

### 測試 4：全收集稱號

* **Given** 除 `title.king_of_meme` 外所有稱號皆已 `claimed`
* **When** 進入稱號頁
* **Then** `title.king_of_meme` → `claimable`，領取後出現在「已取得」

### 測試 5：任務頁關聯提示

* **Given** 未完成【梗圖河馬階段】
* **When** 打開任務頁
* **Then** 「裝備任務」Tab 為鎖定並顯示提示文案
* **When** 完成【梗圖河馬階段】
* **Then** 該 Tab 解鎖可進入

---

## 5. 限制與備註

* 本階段**不提供能力加成**，稱號為展示/收集要素；屬性加成若日後需要，另開 Step。
* `equip.title_114514` 僅為佔位裝備 ID：若尚未實裝該裝備，稱號仍保留在 `locked`；可用 Debug 補測。
* 「迷因之王」需**所有其他稱號 `claimed`** 才可領取，避免自我依賴。
* 小紅點動畫與任務紅點共用組件，確保一致性與維護成本。
* 多語系：所有標籤、稱號名與描述、提示文案均走 i18n；長字串需自動換行不截斷。
