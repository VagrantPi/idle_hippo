# 📄 Step 7 規格書（裝備系統：點擊系 / RGB 電競鍵盤）

## 1. 階段目標
- 建立「裝備清單 UI」（名稱 / 等級 / 加成 / 升級消耗 / 可升級狀態）。
- 實作 **點擊加成裝備** 計算：`tap_gain = base + (Σ裝備加成)`。
- 先上線 1 件裝備：**RGB 電競鍵盤**（多國語系、可升級 1~10 級）。
- 升級消耗與加成固定表（見下），扣費正確、超出等級上限時禁用。

---

## 2. 功能需求

### 2.1 裝備資料（資料驅動）
- 檔案：`assets/config/equipments.json`
- 結構（範例，僅點擊系）：
  ```json
  {
    "tap_equipments": [
      {
        "id": "rgbKeyboard",
        "icon": "assets/images/equipment/RGBKeyboard.png",
        "name_key": "equip.rgbKeyboard.name",
        "desc_key": "equip.rgbKeyboard.desc",
        "type": "tap", 
        "max_level": 10,
        "levels": [
          { "level": 1,  "cost": 10,  "bonus": 1 },
          { "level": 2,  "cost": 20,  "bonus": 2 },
          { "level": 3,  "cost": 30,  "bonus": 3 },
          { "level": 4,  "cost": 50,  "bonus": 4 },
          { "level": 5,  "cost": 80,  "bonus": 5 },
          { "level": 6,  "cost": 130, "bonus": 6 },
          { "level": 7,  "cost": 210, "bonus": 7 },
          { "level": 8,  "cost": 340, "bonus": 8 },
          { "level": 9,  "cost": 550, "bonus": 9 },
          { "level": 10, "cost": 890, "bonus": 10 }
        ]
      }
    ]
  }
  ```

* 多國語系（新增至 `assets/lang/{en,zh,jp,ko}.json`）：

  ```json
  {
    "equip.rgbKeyboard.name": {
      "en": "RGB Gaming Keyboard",
      "zh": "RGB 電競鍵盤",
      "jp": "RGBゲーミングキーボード",
      "ko": "RGB 게이밍 키보드"
    },
    "equip.rgbKeyboard.desc": {
      "en": "Add tap power with a dazzling keyboard.",
      "zh": "絢爛鍵盤讓你的點擊更有力！",
      "jp": "まばゆいキーボードでタップ力アップ！",
      "ko": "화려한 키보드로 탭 파워 업!"
    }
  }
  ```

### 2.2 UI 與互動

* 入口：主畫面**下方導航 → 裝備**（已於 Step 4）。
* 裝備清單（本階段僅 1 件，但 UI 以清單呈現，預留擴充）：

  * 卡片元素：icon / 名稱(i18n) / 等級 `Lv.x / 10` / 當前加成 `+x` / 下一級加成 `→ +y`（若未滿級） / 升級消耗 `cost`。
  * 升級按鈕：

    * **可升級**：當 `memePoints >= nextLevel.cost` 且 `currentLevel < max_level`。
    * **不可升級**：顯示灰階並附提示（資源不足或已達上限）。
  * 互動動效：按鈕點擊使用 Step 4 的壓感動畫（X1.08/Y0.98，0.12s）。
* 右上角顯示當前資源 `memePoints`（即時刷新）。

### 2.3 數值規則

* 單件裝備 **每級加成 = 等級對應的 `bonus`**（見表）。
* 點擊收益公式（與 Step 5 串接）：

  * `tap_gain = base + sum(all tap_equipments bonuses)`
  * `base` 來自 `assets/config/game.json` 的 `tap.base`（例如 1）。
* 升級時流程：

  1. 讀取當前 `memePoints` 與 `currentLevel`。
  2. 若 `currentLevel == max_level` → 禁用；提示已滿級。
  3. 取得 `nextLevel.cost`；若 `memePoints < cost` → 禁用；提示資源不足。
  4. 扣除 `cost` → `memePoints -= cost`（不可為負，失敗即回滾）。
  5. `currentLevel += 1`；即時計算並更新 `tap_gain`。
  6. UI 即時更新（等級、加成、下一級消耗、資源）。
* 任何計算都以**整數**成本、**整數**加成處理；`tap_gain` 可為整數或浮點（基礎值可能非整數）。

### 2.4 存檔與恢復（沿用 Step 2）

* `SecureSaveService` 的 `equipments` 結構新增：

  ```json
  {
    "equipments": {
      "rgbKeyboard": 0  // 初始 0 等（尚未購買/升級）
    }
  }
  ```
* 載入時將此等級套入計算總加成。

### 2.5 Debug 面板

* 顯示：`tap.base`、`sumTapBonus`、`tap_gain`、`rgbKeyboard.level`、`rgbKeyboard.nextCost`。
* 提供「+資源100」測試按鈕（僅 Debug）以驗證升級流程。

### 2.6 資產

* 圖示：`assets/images/equipment/RGBKeyboard.png`（預載）。
* 若缺圖：以灰框佔位並記錄 console 警告。

---

## 3. 驗收標準

* ✅ **數值即時性**：升級後，再次單擊角色之有效點擊，`tap_gain` 立即反映更高（`base + Σbonus`）。
* ✅ **扣費正確**：升級扣除對應 `cost`，`memePoints` 不得為負；資源不足時按鈕禁用。
* ✅ **等級邏輯**：等級上限 10；到達 10 後升級按鈕顯示已滿級且不可點。
* ✅ **UI 完整**：卡片清楚顯示名稱(i18n)、等級、當前加成、下一級加成與消耗、按鈕狀態。
* ✅ **持久化**：關閉重開 App，裝備等級、`memePoints` 正確恢復；`tap_gain` 計算正確。

---

## 4. 實例化需求測試案例

### 案例 1：首次升級成功

* **Given** `memePoints=15`、`rgbKeyboard.level=0`、`tap.base=1`
* **When** 點擊「升級」
* **Then** `memePoints=5`、`rgbKeyboard.level=1`、`sumTapBonus=1`、`tap_gain=1+1=2`

---

### 案例 2：連續升級至 Lv.3

* **Given** `memePoints=100`、`rgbKeyboard.level=0`、成本表（10,20,30）
* **When** 連續升到 Lv.3
* **Then** 最終 `memePoints = 100 - (10+20+30) = 40`、`sumTapBonus=1+2+3=6`、`tap_gain=base+6`

---

### 案例 3：資源不足禁用

* **Given** `memePoints=19`、當前 Lv.1 → 下一級成本 20
* **When** 開啟裝備頁
* **Then** 升級按鈕顯示灰階（不可點），提示「資源不足」

---

### 案例 4：滿級狀態

* **Given** `rgbKeyboard.level=10`
* **When** 進入裝備頁
* **Then** 顯示 `Lv.10/10`、`下一級`欄位隱藏或標記「MAX」，按鈕禁用

---

### 案例 5：點擊收益即時更新

* **Given** `tap.base=1`、`rgbKeyboard.level=1`（bonus=1）、有效點擊間隔通過（Step 5）
* **When** 先點擊一次 → 應得 2；升級到 Lv.2（bonus=2）後再點擊一次
* **Then** 第二次點擊應得 3（`1 + 2`），數值即時反映

---

### 案例 6：持久化驗證

* **Given** 已升到 Lv.4（cost 累計 10+20+30+50=110），`memePoints` 已扣除
* **When** 關閉並重啟 App
* **Then** 裝備仍為 Lv.4；進入主頁點擊一次，`tap_gain = base + (1+2+3+4)=base+10`

---

### 案例 7：多國語系顯示

* **Given** 目前語言為 ZH
* **When** 切換到 EN / JP / KO
* **Then** 裝備名稱與描述即時切換對應語系文字，無需重啟

---

## 5. 限制與備註

* 數值表固定寫於 `equipments.json`，**不得硬編**於程式碼；後續支援多件裝備直接擴增清單。
* Tap 公式與 Step 5 的冷卻判定相容：只有通過冷卻的「有效點擊」才套用 `tap_gain`。
* 升級扣費與狀態更新需**原子化**處理（扣費成功才升級），寫檔失敗需回滾（依 Step 2 備份策略）。
* UI 適配小螢幕：卡片可折行顯示；icon 最小寬高 64px。
* 若未載入到語系字串，回退 EN；若圖檔缺失，顯示佔位符並輸出警告。

