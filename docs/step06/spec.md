# 📄 Step 6 規格書（每日點擊上限＋廣告臨時翻倍）

## 1. 階段目標
- 實作「每日點擊可得分上限」機制，預設 **200**，採 **Asia/Taipei** 為日界線，跨日自動重置。
- 當日可透過「看廣告」將**當日上限翻倍至 400**（本階段以**假廣告流程**實作）。
- 於主畫面顯示「今日上限剩餘」提示，達上限時不再加分（但保留點擊動效）。

---

## 2. 功能需求
1. **設定與資料來源**
   - 從 `assets/config/game.json` 讀取：
     - `tap.daily_cap_base`（預設 200）
     - `tap.daily_cap_ad_multiplier`（預設 2）  
     > 本階段依規格驗收 200 → 400；未來可改為參數化（例：+50% 永久上限等）。
   - 透過 `ConfigService.getValue()` 取得上述數值（支援熱重載）。

2. **日界線與重置規則**
   - 使用 **Asia/Taipei**（UTC+8）計算「當日日期字串」，格式 `YYYY-MM-DD`。
   - 每次有效點擊或啟動 App 時，若偵測到**當日日期 ≠ 存檔日期**：
     - 重置「今日已得分量」與「今日廣告翻倍已使用」旗標。
     - 更新存檔日期為今日。
   - 不允許背景期間累積或誤判跨日（切回前台應立即校正）。

3. **上限計算**
   - 定義：
     - `dailyCapBase = tap.daily_cap_base`（預設 200）
     - `adMultiplier = tap.daily_cap_ad_multiplier`（預設 2）
     - `adDoubledToday`（布林，當日是否已啟用翻倍）
     - `dailyCapEffective = adDoubledToday ? dailyCapBase * adMultiplier : dailyCapBase`  
       > 本階段驗收：200 與 400。
   - **判斷可得分量**：
     - `todayGained`：當日已累積之「點擊可得分量」（僅計入**由點擊產生的得分**）。
     - 每次點擊結算前：若 `todayGained >= dailyCapEffective` → 本次不加分（但仍播壓感與粒子）。
     - 若尚未達上限：只可加到「距上限的剩餘量」（避免超出）。

4. **互動行為**
   - **點擊角色**：
     - 先走 **Step 5** 的點擊間隔判斷（cooldown）。
     - 通過後檢查當日上限；達上限則不加分、但播放壓感與 `plusMemePoint` 粒子（可減少粒子數或特效強度以提示接近上限，選配）。
   - **廣告翻倍（假流程）**：
     - 主畫面或設定入口提供「今日點擊上限翻倍 ×2」按鈕。
     - 假流程：顯示 3 秒 Loading → 設定 `adDoubledToday = true`。
     - **限制**：一天僅可啟用一次；跨日自動清除旗標並恢復為未翻倍。
     - 啟用後立即更新 UI 上限顯示（200 → 400）。

5. **UI/UX**
   - 主畫面資源區域顯示「今日點擊上限：`todayGained` / `dailyCapEffective`」。
   - 當達上限時，顯示提示（例：`今日點擊加分已達上限`），翻倍尚未使用時引導去點「翻倍」。
   - 啟用翻倍後，按鈕需變為不可再次點擊（灰階）並顯示「已翻倍」。

6. **存檔（SecureSaveService）鍵值**
   - 存於單一 Blob（`game_state_v{save_version}`）的 `dailyTap` 區塊：
     ```json
     {
       "dailyTap": {
         "date": "2025-08-21",
         "todayGained": 0,
         "adDoubledToday": false
       }
     }
     ```
   - 初始化：若無 `dailyTap`，建立預設（`date`=今日、`todayGained`=0、`adDoubledToday`=false）。
   - 跨日檢測：若 `saved.date != today(Asia/Taipei)` → 重置 `todayGained` 與 `adDoubledToday`，更新 `date`。

7. **Debug/測試輔助**
   - Debug 面板顯示：`date(tz=Asia/Taipei)`、`todayGained`、`dailyCapEffective`、`adDoubledToday`。
   - 提供「模擬跨日」按鈕（僅 Debug）：手動將 `date` 往前一天，觸發重置流程驗證。
   - 支援在 Debug 面板直接切換 `adDoubledToday`（便於測試 UI 與上限）。

8. **錯誤處理**
   - 任何讀寫失敗或資料遺失時，**不得阻斷點擊流程**；以當前日預設狀態重建 `dailyTap`。
   - `todayGained` 只增不減（除跨日重置）；若讀到負值或 NaN → 重置為 0。

---

## 3. 驗收標準
- ✅ **基本上限**：未使用翻倍，當日連續有效點擊至 200 後，後續點擊不再增加資源（但仍播動效）。
- ✅ **翻倍生效**：啟用當日翻倍（假廣告）後，上限變為 400，繼續點擊可累積到 400。
- ✅ **單日一次**：當日翻倍功能只能啟用一次；按鈕二次點擊不再生效。
- ✅ **跨日重置**：跨越 Asia/Taipei 日界線後，`todayGained` 重置為 0，`adDoubledToday=false`、上限回到 200。
- ✅ **UI 一致**：主畫面上限顯示與實際計算一致，翻倍後即時顯示 400，達上限顯示提示。
- ✅ **熱更新**：修改 `tap.daily_cap_base` 或 `tap.daily_cap_ad_multiplier` 後（熱載），新值在下一次計算即生效（不回溯已累積量）。

---

## 4. 實例化需求測試案例

### 案例 1：未翻倍達上限
- **Given** `tap.daily_cap_base=200`、`adDoubledToday=false`  
- **When** 觸發有效點擊直至 `todayGained=200`  
- **Then** 後續點擊資源不再增加，UI 顯示「200/200」與上限提示  

---

### 案例 2：翻倍到 400
- **Given** `todayGained=200`、尚未翻倍  
- **When** 點擊「翻倍 ×2（假廣告）」成功  
- **Then** `dailyCapEffective=400`，繼續點擊可累積至 `400/400`  

---

### 案例 3：翻倍僅一次
- **Given** 今日已啟用翻倍  
- **When** 再次點擊翻倍按鈕  
- **Then** 按鈕無效（灰階/提示已使用），上限維持 400，不再變化  

---

### 案例 4：跨日自動重置
- **Given** 今日 `todayGained=400`、`adDoubledToday=true`  
- **When** 時間跨到隔日（Asia/Taipei），或使用 Debug 模擬跨日  
- **Then** `todayGained=0`、`adDoubledToday=false`，`dailyCapEffective=200`，UI 顯示「0/200」  

---

### 案例 5：熱載配置
- **Given** 目前 `tap.daily_cap_base=200`、`adMultiplier=2`  
- **When** 將 `tap.daily_cap_base` 改為 300 並熱載  
- **Then** 當日未翻倍上限即變為 300；若已翻倍則變為 600（本階段驗收聚焦 200→400，但系統需可承接參數化）  

---

### 案例 6：異常資料回復
- **Given** 存檔中 `todayGained = -999`（或 NaN）  
- **When** 啟動遊戲  
- **Then** 系統自動更正為 0，流程不中斷  

---

## 5. 限制與備註
- **時區嚴格固定**為 `Asia/Taipei` 進行日期判定；避免使用裝置系統時區造成誤差。
- 本階段「翻倍」為**假廣告流程**；待後續接真 SDK 時僅需替換流程，不變更資料結構。
- 達上限後仍應回饋手感（壓感動畫/粒子），避免玩家誤以為未點擊成功。
- `todayGained` 僅統計**點擊得分**；放置收益不受影響（依企劃）。
- 之後若上線「永久上限 +50%」等商城能力，計算公式可擴充為  
  `dailyCapEffective = floor(dailyCapBase * (1 + permBonus)) * (adDoubledToday ? adMultiplier : 1)`；本階段僅驗收 200/400。
