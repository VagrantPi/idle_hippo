# 📄 Step 10 規格書（離線收益：6 小時上限｜回前台自動入帳）

## 1. 階段目標
- 記錄玩家離線時間（App 不在前台/被關閉）。
- 回到前台時計算本次離線收益：`min(離線時長, 6h) * idle_rate_snapshot`。
- 直接自動入帳至 `memePoints`（不需要玩家點擊）。
- 顯示通知彈窗（**不含廣告翻倍**，廣告翻倍留到 Step 11）。
- 不再有「待領取」流程，`pendingReward` 僅作相容用途（見 2.1/2.5）。
- 最大可領取離線時間上限為 **6 小時**。

---

## 2. 功能需求

### 2.1 生命週期偵測與記錄
- 依 Step 3 的 `AppLifecycleState` 實作：
  - 進入背景/關閉時（`paused`/`detached`）：
    - 寫入 `offline.lastExitUtcMs = nowUTCms`。
    - 寫入 `offline.idle_rate_snapshot = idle_per_sec(effective)`（**速率快照**，見 2.3）。
  - 回到前台（`resumed`）：
    - 若 `offline.pendingReward > 0`（舊版本遺留）→ 直接自動入帳並清 0，仍顯示通知彈窗（顯示本次金額），不重算。
    - 否則使用 `lastExitUtcMs` 計算離線時長，依快照算出金額，並立即自動入帳；顯示通知彈窗。

> **備註**：若 App 在前台閃退未觸發 `paused`，則以最後一次寫入的 `lastExitUtcMs` 與 `idle_rate_snapshot` 為準；若不存在則不發生離線收益。

### 2.2 離線時長計算
- 以 **UTC 時戳**（毫秒）計算：  
  `offlineDurationSec = max(0, (nowUTCms - lastExitUtcMs) / 1000)`
- **上限**：`effectiveDurationSec = min(offlineDurationSec, 6*3600)`。
- 若 `offlineDurationSec < 1`（小於 1 秒），可視為 0，不產生收益。
- 若系統時鐘被往回調（負值），視為 0。

### 2.3 速率快照（anti-cheat/一致性）
- 於離線前記錄：`idle_rate_snapshot = idle_per_sec`（含 base、放置裝備、寵物/BUFF 若已實作；本階段至少含 base 與放置裝備）。
- 回前台時計算離線收益 **只使用快照值**（避免回來後調整裝備/設定影響既有離線段收益）。
- 公式：  
  `reward = idle_rate_snapshot * effectiveDurationSec`
- 小數保留：內部以 double 精度保存，顯示時四捨五入到 1 位小數（UI）。

### 2.4 彈窗（通知型，最小版本）
- **內容**：
  - 標題：`離線收益`（i18n）。
  - 文字：`你離線了 {H:MM:SS}，共累積 ≈ {reward} 迷因點數`（顯示四捨五入）。
  - 按鈕：`確認/OK`（單一按鈕，僅關閉彈窗，與入帳無關）。
- **行為**：
  - 回前台時已自動入帳；按下 `確認` 只關閉彈窗。
- 不提供廣告翻倍（下一階段加入）。
- **觸發**：
  - 每次回前台若成功計算出本次金額，都顯示通知彈窗。
  - 若為舊版本遺留 `pendingReward > 0`，自動入帳並顯示本次金額。

### 2.5 狀態保存（SecureSaveService Blob）
- 加入（若無則新增）：
  ```json
  {
    "offline": {
      "lastExitUtcMs": 0,
      "idle_rate_snapshot": 0.0,
      "pendingReward": 0.0,
      "capHours": 6
    }
  }
````

* 寫入時機：

  * 進入背景：更新 `lastExitUtcMs`、`idle_rate_snapshot`。
  * 回前台完成計算後：直接自動入帳並同步寫入（`memePoints`、`lastExitUtcMs`），`pendingReward` 維持 0。
  * 舊版本遺留 `pendingReward>0`：回前台即自動入帳並清空，寫回檔案。

### 2.6 與前台放置（Step 8）的關係

* **離線收益與前台累積互斥**：回前台後，前台放置由 Step 8 持續累積；離線收益僅一次性入帳。
* 回前台時 **不要** 以 `GameClock` 的大 Delta 將離線時間當作前台時間處理（避免爆量）。離線全由本模組一次性結算。

### 2.7 Debug/測試輔助

* Debug 面板顯示：

  * `lastExitUtcMs`、`idle_rate_snapshot`、`pendingReward`、`offlineDurationSec(effective)`。
* Debug 按鈕：

  * `模擬離線 +60s`：將 `lastExitUtcMs` 回推 60 秒後觸發回前台流程。
  * `清空待領取`：將 `pendingReward=0`（便於重測）。

### 2.8 多國語系（最少鍵）

* `assets/lang/{en,zh,jp,ko}.json`：

  ```json
  {
    "offline.title": {"en":"Offline Earnings","zh":"離線收益","jp":"オフライン収益","ko":"오프라인 수익"},
    "offline.message": {
      "en":"You were away for {time}, earned about {points} meme points.",
      "zh":"你離線了 {time}，共累積約 {points} 點迷因點數。",
      "jp":"{time} のあいだ離席していました。約 {points} ミームポイントを獲得。",
      "ko":"{time} 동안 오프라인이었습니다. 약 {points} 밈 포인트를 획득했습니다."
    },
    "offline.confirm": {"en":"Confirm","zh":"確認","jp":"確認","ko":"확인"}
  }
  ```

---

## 3. 驗收標準

* ✅ **1 分鐘驗證**：設定 `idle_rate_snapshot=1.0/s`，模擬離線 60 秒，回前台彈窗顯示 ≈ `60`，且 `memePoints` 立即增加 ≈ `60`（無需點擊）。
* ✅ **上限 6 小時**：模擬離線 10 小時，彈窗顯示不超過 `6h * idle_rate_snapshot`。
* ✅ **負向/極短間隔安全**：若 `nowUTCms < lastExitUtcMs` 或離線 < 1 秒，不產生收益、不中斷執行。
* ✅ **快照一致性**：離線前 `idle_rate_snapshot=0.6/s`，回前台先不動裝備即顯示 `0.6 * duration`；即便玩家在彈窗期間升級裝備，**本次**離線獎勵金額不變。
* ✅ **一次性入帳**：回前台即入帳，`pendingReward` 維持 `0`；再次回前台不重複入帳。

---

## 4. 實例化需求測試案例

### 案例 1：基本 60 秒（自動入帳）

* **Given** `idle_rate_snapshot=1.0/s`、`lastExitUtcMs = now - 60s`
* **When** 回到前台
* **Then** 彈窗顯示約 `60`，同時 `memePoints += 60`（自動入帳），`pendingReward=0`

---

### 案例 2：大於上限（自動入帳）

* **Given** `idle_rate_snapshot=2.0/s`、`lastExitUtcMs = now - 10h`
* **When** 回到前台
* **Then** 顯示金額為 `2.0 * 6h = 43200`，不超過上限；自動入帳

---

### 案例 3：負值/回撥時鐘

* **Given** `lastExitUtcMs = now + 5min`（時鐘被往回調）
* **When** 回到前台
* **Then** 視為 0 秒，`pendingReward=0`，不顯示彈窗，App 不崩潰

---

### 案例 4：快照一致性

* **Given** 離線前 `idle_rate_snapshot=0.5/s`、離線 120 秒
* **When** 回前台先彈窗顯示 `≈60`；在未領取前升級裝備使 `idle_per_sec=1.0/s`
* **Then** 本次彈窗仍顯示 `≈60`（以快照計算），領取後再以新速率繼續前台累積

---

### 案例 5：重入前台不重算（舊版本 pending 相容）

* **Given** 已計算出 `pendingReward=100` 尚未領
* **When** 連續切到背景又回前台
* **Then** 自動將 `100` 入帳並清空 `pendingReward`；顯示本次金額 `100`；不會再次基於舊 `lastExitUtcMs` 疊加

---

### 案例 6：Debug 模擬

* **Given** 於 Debug 面板點擊「模擬離線 +60s」
* **When** 觸發回前台邏輯
* **Then** 彈窗顯示約 `idle_rate_snapshot * 60`，與手動設值一致

---

## 5. 限制與備註

* 本階段 **不含** 廣告翻倍與 UI 美術完成度，僅提供最小可用彈窗，Step 11 再補「觀看廣告翻倍」。
* 計算一律使用 **UTC**，避免時區/日界線造成錯誤；與每日上限（Step 6, Asia/Taipei）分開處理。
* `idle_rate_snapshot` 建議於每次進入背景時刷新；若玩家長時間前台後直接被系統回收，使用最後一次 snapshot。
* 存檔採 Step 2 的原子寫入策略；任何寫入失敗不得阻斷進入遊戲流程。
* 顯示值四捨五入僅供 UI；實際加值使用 double 原值（避免長期誤差）。
