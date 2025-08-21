# 📄 Step 9 規格書（裝備系：放置系 / Tiktok・BTC・DOGE）

## 1. 階段目標
- 在「裝備」頁新增 **Tab 分流**：`點擊` / `放置`，本階段實作 **放置系**。
- 新增 3 件放置裝備：**Youtube / BTC / DOGE**，並依解鎖條件逐步開啟。
- 以資料驅動方式定義 **等級 1~10** 的升級成本與「被動迷因收入（/s）」。
- 升級後立即影響 `idle_per_sec`（僅前台累積，承接 Step 8）。
- UI 清楚顯示：名稱 / 等級 / 當前加成 / 下一級加成 / 升級消耗 / 鎖定條件。

---

## 2. 功能需求

### 2.1 Tab 分流
- 入口：**裝備**頁（Step 7 已建立）。
- 於裝備頁上方加入 **Tab**：
  - `點擊`（維持既有點擊系裝備清單）
  - `放置`（本階段新清單）
- Tab 切換需保留各自捲動位置與展開狀態。

### 2.2 放置裝備資料（資料驅動）
- 檔案：`assets/config/equipments.json`（與點擊系共用檔）
- 結構（節錄放置系）：
  ```json
  {
    "idle_equipments": [
      {
        "id": "youtube",
        "icon": "assets/images/equipment/Youtube.png",
        "name_key": "equip.youtube.name",
        "desc_key": "equip.youtube.desc",
        "type": "idle",
        "unlock": null,
        "max_level": 10,
        "levels": [
          { "level": 1,  "cost": 10,  "bonus_per_sec": 0.1 },
          { "level": 2,  "cost": 20,  "bonus_per_sec": 0.2 },
          { "level": 3,  "cost": 30,  "bonus_per_sec": 0.3 },
          { "level": 4,  "cost": 50,  "bonus_per_sec": 0.4 },
          { "level": 5,  "cost": 80,  "bonus_per_sec": 0.5 },
          { "level": 6,  "cost": 130, "bonus_per_sec": 0.6 },
          { "level": 7,  "cost": 210, "bonus_per_sec": 0.7 },
          { "level": 8,  "cost": 340, "bonus_per_sec": 0.8 },
          { "level": 9,  "cost": 550, "bonus_per_sec": 0.9 },
          { "level": 10, "cost": 890, "bonus_per_sec": 1.0 }
        ]
      },
      {
        "id": "btc",
        "icon": "assets/images/equipment/BTC.png",
        "name_key": "equip.btc.name",
        "desc_key": "equip.btc.desc",
        "type": "idle",
        "unlock": { "type": "equip_level", "id": "youtube", "level": 3 },
        "max_level": 10,
        "levels": [ /* 同上成本表與 0.1~1.0 */ ]
      },
      {
        "id": "doge",
        "icon": "assets/images/equipment/DOGE.png",
        "name_key": "equip.doge.name",
        "desc_key": "equip.doge.desc",
        "type": "idle",
        "unlock": { "type": "equip_level", "id": "btc", "level": 3 },
        "max_level": 10,
        "levels": [ /* 同上成本表與 0.1~1.0 */ ]
      }
    ]
  }
````

### 2.3 多國語系（最少鍵）

* `assets/lang/{en,zh,jp,ko}.json`：

  ```json
  {
    "equip.youtube.name": {"en":"YouTube","zh":"Youtube","jp":"YouTube","ko":"틱톡"},
    "equip.youtube.desc": {"en":"Generates idle meme energy.","zh":"產生被動迷因能量。","jp":"放置ミームエネルギーを生成。","ko":"방치 미믹 에너지를 생성."},
    "equip.btc.name": {"en":"BTC","zh":"BTC","jp":"BTC","ko":"BTC"},
    "equip.btc.desc": {"en":"Stacks crypto clout for idle gain.","zh":"幣圈熱度加持，放置收益提高。","jp":"仮想通貨の勢いで放置収益UP。","ko":"코인 열기로 방치 수익 UP."},
    "equip.doge.name": {"en":"DOGE","zh":"DOGE","jp":"DOGE","ko":"DOGE"},
    "equip.doge.desc": {"en":"Such idle, much wow.","zh":"如此放置，非常哇。","jp":"そんな放置、すごいワオ。","ko":"이런 방치, 대단 Wow."},
    "equip.lock.need_level": {
      "en":"Unlock after {name} Lv.{level}",
      "zh":"需要 {name} 達到 Lv.{level} 解鎖",
      "jp":"{name} を Lv.{level} で解放",
      "ko":"{name} Lv.{level} 달성 시 해제"
    },
    "tab.equip.tap": {"en":"Tap","zh":"點擊","jp":"タップ","ko":"탭"},
    "tab.equip.idle": {"en":"Idle","zh":"放置","jp":"放置","ko":"방치"}
  }
  ```

### 2.4 UI 與互動

* **卡片資訊**：icon、名稱(i18n)、`Lv.x/10`、當前加成 `+y/s`、下一級 `→ +y2/s`（未滿級時）、升級消耗 `cost`、狀態（可升級/資源不足/滿級/鎖定）。
* **鎖定顯示**：

  * 被鎖定裝備置灰、顯示鎖頭疊圖或文案 `需要 Youtube 達到 Lv.3 解鎖`（i18n）。
  * 點擊鎖定卡片時彈出同文案，無升級按鈕。
* **升級按鈕**：

  * 可升級：`memePoints >= cost` 且 `level < max_level` 且 `已解鎖`。
  * 不可升級：顯示灰階並提示原因（資源不足 / 已滿級 / 未解鎖）。
  * 動效沿用 Step 4 壓感（X1.08/Y0.98, 0.12s）。
* **即時刷新**：升級後卡片、右上 `memePoints`、與放置速率展示 `+X/s` 立即更新。

### 2.5 數值計算

* 放置速率公式（在 Step 8 的 `idle_per_sec` 中整合）：

  ```
  idle_per_sec =
      idle.base_per_sec * idle.multiplier
    + Σ(levelBonus_per_sec for all idle_equipments)
    + 其他來源（寵物/BUFF/活動，未實裝時=0）
  ```
* 本階段 `levelBonus_per_sec` 直接取裝備等級對應 `bonus_per_sec`；為\*\*疊加（相加）\*\*關係。
* 升級流程：

  1. 檢查解鎖條件。
  2. 檢查等級上限與資源。
  3. 扣 `memePoints` → `level += 1`。
  4. 重新計算並更新 `idle_per_sec`。
  5. UI 更新（加成/下一級/資源/`+X/s`）。

### 2.6 存檔結構（沿用 Step 2）

* 在 Blob 的 `equipments` 內加入每件裝備等級（初始 0）：

  ```json
  {
    "equipments": {
      "youtube": 0,
      "btc": 0,
      "doge": 0,
      "...": 0
    }
  }
  ```
* 讀檔時依等級套用加成；寫檔於升級成功後原子更新。

### 2.7 Debug 面板

* 顯示：`idle.base_per_sec`、`ΣidleEquipBonus/s`、`idle_per_sec(effective)`、各裝備等級與下一級成本。
* 快捷：`給資源+1000`、`一鍵解鎖條件`（僅 Debug）。

---

## 3. 驗收標準

* ✅ **Tab 分流**：裝備頁可在 `點擊/放置` 兩個 Tab 來回切換，狀態與捲動不互相干擾。
* ✅ **解鎖邏輯**：

  * BTC 在 Youtube 未達 Lv.3 時顯示鎖定文案；Tiktok 升至 Lv.3 後，BTC 立即解鎖。
  * DOGE 在 BTC 未達 Lv.3 時鎖定；BTC 升至 Lv.3 後，DOGE 立即解鎖。
* ✅ **升級與計算**：升級任一放置裝備之後，`idle_per_sec` 立即增加其對應 `bonus_per_sec`。
* ✅ **30 秒驗證**：升級前後各在前台靜置 30 秒，後者的資源累積明顯高於前者，且與 `30 × idle_per_sec` 的理論值誤差 ≤ 1%。
* ✅ **UI 完整**：卡片清楚展示名稱、等級、當前/下一級加成、成本與狀態；資源不足時按鈕禁用；滿級顯示 MAX。
* ✅ **持久化**：重啟 App 後，裝備等級與 `idle_per_sec` 計算結果一致恢復。

---

## 4. 實例化需求測試案例

### 案例 1：Tiktok 升級影響放置速率

* **Given** `idle.base_per_sec=0.0`、`youtube.level=0`
* **When** 依序升到 Lv.3（成本 10+20+30），累計 `bonus_per_sec=0.6`
* **Then** Debug `idle_per_sec` 顯示 `0.6/s`；前台 10 秒後資源 ≈ `6.0 ± 0.06`

---

### 案例 2：BTC 鎖定與解鎖

* **Given** `youtube.level=2`、`btc.level=0`
* **When** 打開放置 Tab
* **Then** BTC 卡片顯示鎖定與文案「需要 Youtube 達到 Lv.3 解鎖」
* **When** 升 Youtube 至 Lv.3 後返回放置 Tab
* **Then** BTC 解除鎖定、可升級

---

### 案例 3：DOGE 鎖定鏈

* **Given** `btc.level=2`、`doge.level=0`
* **When** 打開放置 Tab
* **Then** DOGE 顯示鎖定「需要 BTC 達到 Lv.3 解鎖」
* **When** 升 BTC 至 Lv.3
* **Then** DOGE 即時解鎖

---

### 案例 4：升級扣費與上限

* **Given** `memePoints=50`、`youtube.level=1`（下一級成本 20）
* **When** 連升兩級（Lv.1→Lv.3：20 + 30）
* **Then** `memePoints=0`，第三次升級按鈕灰階（資源不足）；`idle_per_sec` 累加 0.2+0.3

---

### 案例 5：30 秒收益提升驗證

* **Given** 初始 `idle_per_sec=0.6`（Tiktok Lv.3），前台等 30 秒記錄 A
* **When** 升 BTC Lv.2（+0.3/s），新 `idle_per_sec=0.9`
* **Then** 再等 30 秒記錄 B；`B - A ≈ (0.9 - 0.6) * 30 = 9 ± 0.09`

---

### 案例 6：持久化驗證

* **Given** Youtube Lv.4、BTC Lv.3、DOGE Lv.0
* **When** 關閉並重啟 App
* **Then** 裝備等級正確、放置速率顯示 `0.4 + 0.3 = 0.7/s`（若 base=0），與實際累積相符

---

### 案例 7：多國語系

* **Given** 當前語言為 ZH
* **When** 切換 EN / JP / KO
* **Then** 卡片名稱與鎖定文案即時切換對應語系，不需重啟

---

## 5. 限制與備註

* 所有成本與加成 **不得硬編**，需來自 `equipments.json`；後續新增裝備只要擴充 JSON 即可。
* 解鎖條件以資料宣告（`unlock`），程式以泛型規則解析（`equip_level`），便於未來擴充。
* `idle_per_sec` 與 Step 8 的更新管線一致；只改變「速率輸入」，不變更累積機制。
* 升級流程需與存檔寫入**原子**一致：扣費成功→升級→重算→寫檔；任何一步失敗需回滾。
* UI 適配窄螢幕：卡片允許換行；icon 最小 64px；鎖定提示優先只顯示一行（長文加 `…`）。
