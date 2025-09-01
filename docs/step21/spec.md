# 📄 Step 21 規格書（每日打卡系統）

## 1. 階段目標
- 實作每日打卡簽到系統（**以週為單位呈現**），提供每日 **1 項小任務**，**完成才算簽到**。
- 每逢 **7 的倍數**（依規則）完成簽到時，**發放半日放置迷因點數**獎勵。
- 支援 **廣告跳過**：觀看（假流程）即可將當日任務標記完成並簽到。
- **Duolingo 式達成特效**；**未完成當日任務前，主畫面設定入口顯示紅點**。
- **儲存結構常數級**：以**位元遮罩**保存「本週完成情況」，不隨天數成長。

---

## 2. 功能需求

### 2.1 UI/UX
- **入口**
  - 主畫面右側「設定」圖示；**當日未完成**時在設定圖示顯示紅點（與任務頁紅點動畫一致）。
  - 設定頁→「打卡紀錄」區塊（預設縮合），點擊展開 **週打卡 7 格**（Mon~Sun）。
- **今日任務（兩種其一，隨機指派）**
  1) **點擊**：點擊角色 `n` 次（`n ∈ [minTap, maxTap]`，預設 20~50，可配置）。
  2) **收集**：今日累積 `m` 迷因點數（**自今日首次進入 App 起開始計算**，`m = floor(idlePerSecSnapshot * 8h)`）。
  - 任務卡顯示：任務類型、目標數、當前進度、**「看廣告跳過」**按鈕、**「完成簽到」**特效。
- **達成後**
  - 觸發 **Duolingo 式動畫**；本日週曆格亮起；入口紅點消失。

### 2.2 狀態資料（常數級；含位元遮罩）
- 保存於 `game_state_v{save_version}.checkin`：
```json
{
  "checkin": {
    "tz": "Asia/Taipei",
    "config": {
      "weekStartDow": 1,                 // 週起始：1=周一（可配置）
      "tapRange": [20, 50]               // 點擊任務目標範圍
    },

    "streak": {
      "current": 6,                      // 連續簽到天數（以連續日計）
      "best": 18,                        // 歷史最長連續
      "total": 127,                      // 累計簽到天數
      "lastDate": "2025-08-29"           // 上次簽到日期（local, YYYY-MM-DD）
    },

    "week": {
      "weekStart": "2025-08-25",         // 本週起始日（local, YYYY-MM-DD），依 weekStartDow 算
      "mask": 41,                        // 7-bit 完成遮罩（bit0=週起日，bit6=週末；例：0b0101001）
      "weeklyBonusClaimed": false        // 若使用「每週一次」週獎勵策略可用；或保留作 UI 標記
    },

    "today": {
      "date": "2025-08-29",              // 今日日期（local, YYYY-MM-DD）
      "task": {
        "type": "tap",                    // "tap" | "collect"
        "target": 35,                     // tap：n；collect：m（取今日進入時 idlePerSecSnapshot * 8h）
        "progress": 12                    // 即時進度（collect 自今日首進 App 起累加）
      },
      "status": "pending",                // "pending" | "done" | "skipped"
      "skipViaAdUsed": false,             // 今日是否已用廣告跳過
      "idlePerSecSnapshot": 1.25          // 生成今日任務時拍的 idlePerSec 快照（供 m 計算追溯用）
    }
  }
}
````

> **位元遮罩說明**
>
> * `mask` 使用 **7-bit** 整數表示本週 7 天完成狀態：
>
>   * `bitIndex = 0..6`，`0` 代表 `weekStart` 這一天，`6` 代表 `weekStart+6`。
>   * 完成當天：`mask |= (1 << bitIndex)`。
>   * 是否完成：`(mask & (1 << bitIndex)) != 0`。

### 2.3 任務生成與時間規則

* **本地時區**固定：`Asia/Taipei`。
* **跨日檢測**（App 啟動 / 回前台 / 整點 tick 皆可觸發）：

  1. 若 `today.date != localToday`：

     * 若前一日 `status == "pending"` → 未簽到（不計 done；可選是否標記 miss，不儲存歷史即可）。
     * **建立新任務**：

       * 依 `config.weekStartDow` 計算 `weekStart`；若 `localToday` 超出 `weekStart+6` → 觸發**跨週**（見下）。
       * 隨機 `task.type`（tap/collect）。
       * `tap.target = randomInt(tapRange)`。
       * `collect.target = floor(idlePerSecNow * 8 * 3600)`；同時保存 `idlePerSecSnapshot = idlePerSecNow`。
       * `progress = 0`、`status = "pending"`、`skipViaAdUsed = false`、`today.date = localToday`。
* **跨週**：若 `localToday` 不在 `weekStart..weekStart+6`：

  * `week.weekStart = 本週週起日`；`mask = 0`；`weeklyBonusClaimed = false`。

### 2.4 簽到、連續邏輯與紅點

* **達成條件**：`task.progress >= task.target` → 可簽到。或按 \*\*「看廣告跳過」\*\*直接簽到。
* **簽到時（含跳過）**：

  * `today.status = "done" | "skipped"`；`skipViaAdUsed=true`（僅跳過時）。
  * 以 `localToday` 計算 `bitIndex`，**設置位元**：`mask |= (1 << bitIndex)`。
  * **連續計算**：

    * 若 `streak.lastDate` 與 `localToday` 為**連續日**（差 1 天），`streak.current += 1`；
    * 否則 `streak.current = 1`。
    * `streak.best = max(best, current)`；`streak.total += 1`；`streak.lastDate = localToday`。
  * **紅點**：簽到後主畫面設定入口紅點**消失**。
* **週獎勵觸發**（兩種策略擇一，預設 **A**）：

  * **A. 每逢 7 的倍數**（依**累計簽到**）：`if (streak.total % 7 == 0) → 發放半日 idle 獎勵`。
  * **B. 週內一次**：當週 mask 達到某條件（如本週簽到滿 7 天）且 `weeklyBonusClaimed == false` 時發放，並設 `weeklyBonusClaimed=true`。

### 2.5 廣告跳過（假流程）

* 今日任務卡顯示「看廣告跳過」按鈕（3s 模擬流程）。
* 完成後即等同簽到：`status="skipped"`，其他簽到流程相同（位元、連續、紅點、週獎勵）。

### 2.6 i18n（最少鍵）

```json
{
  "checkin.title": {"zh":"每日打卡","en":"Daily Check-in","jp":"毎日ログイン","ko":"일일 출석"},
  "checkin.weekly": {"zh":"本週","en":"This Week"},
  "checkin.task.tap": {"zh":"點擊角色 {n} 次","en":"Tap the hippo {n} times"},
  "checkin.task.collect": {"zh":"今日累積 {m} 迷因點數","en":"Collect {m} meme points today"},
  "checkin.btn.skip_ad": {"zh":"看廣告跳過","en":"Watch Ad to Skip"},
  "checkin.status.done": {"zh":"已簽到","en":"Checked-in"},
  "checkin.status.pending": {"zh":"未完成","en":"Pending"},
  "checkin.reward.week": {"zh":"週獎勵已領取","en":"Weekly bonus claimed"},
  "checkin.toast.bonus_halfday": {"zh":"獲得半日放置獎勵！","en":"Half-day idle bonus received!"},
  "checkin.hint.open": {"zh":"完成今日任務即可簽到","en":"Complete today's task to check in"}
}
```

### 2.7 Telemetry（預留至 Step 33）

* `daily_checkin_assigned { type, target }`
* `daily_checkin_progress { type, progress, target }`（可選）
* `daily_checkin_complete { type, skipped:bool }`
* `daily_checkin_streak { current, best, total }`
* `daily_checkin_week_mask { mask }`（可選）

---

## 3. 驗收標準

* ✅ **任務生成**：以 Asia/Taipei 計時，跨日後自動生成新任務；tap 目標在配置範圍內、collect 目標等於當下 `idlePerSecSnapshot * 8h`（向下取整）。
* ✅ **週顯示**：設定頁週曆僅顯示本週 7 格；完成的格子對應 `mask` 之已設位 bit。
* ✅ **紅點**：當日 `status="pending"` 時，主畫面設定入口顯示紅點；簽到後紅點消失。
* ✅ **簽到**：達標或看廣告跳過後，`today.status` 變為 `done|skipped`、`mask` 正確設位、週曆對應格點亮。
* ✅ **連續計算**：連續簽到日 `streak.current` 正確累加；非連續日重置為 1；`best` 與 `total` 正確更新。
* ✅ **週獎勵**：採策略 A（預設）時，`streak.total` 逢 7 的倍數立即發放**半日放置獎勵**，並彈出提示。
* ✅ **持久化**：重啟 App 後，週曆、今日任務、紅點、連續統計完全還原。
* ✅ **常數級存儲**：連續簽到 100 天以上，`checkin` 區塊大小不隨天數成長（僅 `week.mask`、`streak`、`today` 更新）。

---

## 4. 實例化需求測試案例

### 案例 1：當日任務生成（tap）

* **Given** 08/28 首次進入 App
* **When** 產生今日任務
* **Then** `task.type="tap"`；`target ∈ [20,50]`；設定入口顯示紅點；週曆當天格未亮

### 案例 2：當日任務生成（collect）

* **Given** 08/29 首次進入 App，當下 `idlePerSec=2.0`
* **When** 產生今日任務
* **Then** `task.type="collect"`；`target = floor(2.0 * 8 * 3600) = 57600`；`idlePerSecSnapshot=2.0`

### 案例 3：完成簽到（正常達標）

* **Given** 今日 tap 目標 30，progress=29
* **When** 再點擊 1 次
* **Then** `today.status="done"`；`mask` 對應 bit 被設 1；週曆當天格亮起；入口紅點消失

### 案例 4：廣告跳過簽到

* **Given** 今日 collect 目標 50000，progress=800
* **When** 點擊「看廣告跳過」（假流程 3s）
* **Then** `today.status="skipped"`；`skipViaAdUsed=true`；mask 設位；紅點消失

### 案例 5：跨日與跨週輪轉

* **Given** 週起為周一，`week.weekStart=08/25`，目前是 08/31（日）
* **When** 進入 09/01（一）
* **Then** 觸發跨週：`week.weekStart=09/01`；`mask=0`；`today` 生成新任務

### 案例 6：連續與最佳

* **Given** `streak.current=3`，`streak.lastDate=08/28`
* **When** 08/29 完成簽到
* **Then** `streak.current=4`、`best` 取最大、`total += 1`、`lastDate=08/29`

### 案例 7：週獎勵（策略 A）

* **Given** `streak.total=6`
* **When** 完成今日簽到
* **Then** `streak.total=7` 觸發週獎勵：發放**半日放置迷因點數**並顯示提示

### 案例 8：持久化與紅點

* **Given** 今日未完成
* **When** 重啟 App
* **Then** 設定入口紅點仍顯示；今日任務仍為 `pending`；數值未丟失

---

## 5. 限制與備註

* **collect 任務**之目標 `m` 以**今日首次進入**時的 `idlePerSec` 快照計算，之後升級不回溯調整（公平、可重現）。
* **時區**與**週起始日**務必統一（預設 `Asia/Taipei`、週一起算 `weekStartDow=1`），避免邊界錯誤。
* **週獎勵策略**如需改為「當週滿 7 天才發」→ 改用 `weeklyBonusClaimed`，並檢查 `mask == 0b1111111`。
* **儲存遷移**：如舊版保存了逐日清單，遷移時只需推導出**本週 `week.mask`**、**`streak` 統計**與 **`today`**，丟棄歷史陣列即可。
