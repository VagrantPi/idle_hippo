# 📄 Step 3 規格書（時間系統與前台 Tick）

## 1. 階段目標
- 建立可配置的 `GameClock`（目標 10~30fps 範圍內自動調節），作為全域時間驅動來源。
- 接上前/後台偵測（僅前台時驅動），並提供統一的 `onTick(deltaSeconds)` 廣播給各系統（放置、任務條、Buff…）。
- 確保前台連續停留 10 秒時，放置收益以「每秒速率」累積之總量誤差 < 1%。

---

## 2. 功能需求
1. **時間來源與節流**
   - `GameClock` 每幀計算 `deltaSeconds`（雙精度浮點，單位：秒）。
   - 目標更新頻率介於 10~30fps：  
     - 預設採 **變動步長（variable timestep）**，並以 `fpsTarget=30` 作為節流上限。  
     - 若主迴圈更新頻率過高，需節流（例如使用 `Timer`/`Ticker` 或 Flame 的 `update(dt)` 內做累積判斷）。
   - **Delta 夾制（clamp）**：當單幀 `deltaSeconds > 0.2` 時，以 0.2 取代（避免掛起/掉禎導致爆量）。

2. **前/後台偵測**
   - 使用 Flutter `WidgetsBindingObserver` 監控 `AppLifecycleState`：  
     - `resumed` / `inactive` / `paused` / `detached`。  
   - 僅在 `resumed`（前台）狀態下推進 `GameClock`；其餘狀態暫停 tick 廣播。  
   - 進入前台的第一幀，將上一次時間基準重設（避免長時間背景造成超大 delta）。

3. **訂閱/退訂介面**
   - `GameClock.subscribe(String id, void Function(double deltaSeconds) handler)`：加入訂閱者。  
   - `GameClock.unsubscribe(String id)`：移除訂閱者。  
   - 訂閱者以 `id` 唯一識別；重複 `id` 會覆蓋舊 handler。  
   - 廣播順序不保證；**單幀內至少一次**對所有訂閱者呼叫。

4. **Delta 平滑處理（抗抖）**
   - 對外提供「原始 delta」與「平滑 delta」兩種：  
     - 平滑使用 **指數移動平均（EMA）**：`ema = alpha * raw + (1 - alpha) * ema_prev`，預設 `alpha=0.2`。  
     - 訂閱者預設收到 **原始 delta**；可選擇取用平滑值（供 UI 動畫/顯示）。

5. **放置收益整合（驗收用簡實作）**
   - 放置系統在此階段僅需支援：`idle_per_sec` 從 `ConfigService` 讀取（例如 `0.1`）。  
   - 每幀 `onTick` 時，透過回調函數將 `idle_per_sec * deltaSeconds` 直接加到 GameState.memePoints。  
   - IdleIncomeService 負責統計追蹤（totalIdleTime、totalIdleIncome），不負責數值存儲。

6. **Debug 面板（最小可視化）**
   - 顯示：`fps（近1秒估計）`、`avgDelta(ms)`、`state: foreground/background`、`subscribersCount`。  
   - 可切換 **固定步長測試模式**：`fixedDelta=0.0166667`（60fps 模擬）以便誤差驗證。

7. **錯誤處理與安全性**
   - 禁止在背景狀態累積 delta。  
   - 若 `deltaSeconds` 出現 NaN / Infinity，丟棄該幀。  
   - 在 Hot Reload 發生時，`GameClock` 需能重新掛載並恢復訂閱（允許使用服務定位 or 單例）。

---

## 3. 驗收標準
- ✅ **前台累積誤差**：在 `idle_per_sec = 1.0` 情境下，連續前台停留 10 秒，累積增加量介於 `9.9 ~ 10.1`（誤差 < 1%）。
- ✅ **背景不累積**：切至背景 5 秒後回前台，能量不因背景時間增加（首幀 delta 已重置）。
- ✅ **Delta 安全**：單幀 delta 超過 0.2s 時，實際套用 0.2s；無異常爆量。
- ✅ **訂閱機制**：可註冊/移除訂閱者；移除後不再收到 `onTick` 回呼。
- ✅ **Debug 面板**：能顯示 fps、avgDelta、state、subscribersCount；切換固定步長測試模式可生效。

---

## 4. 實例化需求測試案例

### 測試案例 1：前台 10 秒累積
- **Given** `idle_per_sec = 1.0`，當前能量 `0.0`，App 前台  
- **When** 不操作連續等待 10 秒  
- **Then** 能量在 `9.9 ~ 10.1` 之間（誤差 < 1%）

---

### 測試案例 2：背景暫停累積
- **Given** `idle_per_sec = 2.0`，能量 `0.0`  
- **When** 前台等待 3 秒（應得 ≈ 6）→ 切到背景 5 秒 → 回前台再等 2 秒  
- **Then** 總累積 ≈ `3*2 + 2*2 = 10`；背景 5 秒期間不增加

---

### 測試案例 3：Delta 夾制
- **Given** 模擬主迴圈單幀卡頓 1 秒（暫停 debugger）  
- **When** 回到前台的第一幀  
- **Then** `deltaSeconds` 套用 0.2s 夾制；能量不會瞬間暴增 > `idle_per_sec * 0.2`

---

### 測試案例 4：訂閱/退訂
- **Given** 兩個系統 `A/B` 訂閱 `GameClock`  
- **When** 移除 `B` 的訂閱後再等待 1 秒  
- **Then** 只有 `A` 的 `onTick` 計數增加；`B` 不再收到回呼

---

### 測試案例 5：固定步長測試
- **Given** 開啟固定步長 `fixedDelta=0.05`（20fps），`idle_per_sec=3.0`，能量 `0`  
- **When** 前台連續 10 秒  
- **Then** 累積值 **精確接近** `3.0 * 10 = 30.0`（允許 ±0.3，1% 誤差）

---

## 5. 限制與備註
- 版本需求：Flutter 3.22+、Flame ^1.17+。  
- `GameClock` 可封裝在 Flame `Game` 的 `update(dt)` 之上（建議），或使用 `Ticker` 驅動；但**對外只暴露** `subscribe/unsubscribe/onTick` 介面。  
- 本階段不實作持久化；`memePoints` 僅為記憶體變數（存檔納入 Step 2）。  
- 所有時間以**秒**為單位（double）；避免混用毫秒。  
- Hot Reload 需保持服務單例與訂閱列表（或在重載後自動恢復）。  
- 之後若加入後台離線收益，將由「離線收益模組」透過**時間戳差**計算，不依賴 `GameClock`。
