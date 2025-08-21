# 📄 Step 2 規格書（存檔與版本化）

## 1. 階段目標
- 建立安全存檔服務 `SecureSaveService`（基於 `flutter_secure_storage`）。
- 採用單一 JSON Blob 儲存核心狀態，Key 命名：`game_state_v{save_version}`。
- 內含 `save_version` 與 Migration Stub（可平滑升版）。
- 提供「重置存檔」功能（雙重確認）。
- 異常/破損資料可安全回退至初始狀態（不中斷執行）。

---

## 2. 功能需求
1. **資料存放與 Key 命名**
   - 使用 `flutter_secure_storage`（AES/Keystore/Keychain）保存單一 JSON Blob。
   - 主 Key：`game_state_v{save_version}`（例如 `game_state_v1`）。
   - 備份 Key：`game_state_v{save_version}_bak`（寫入前先備份）。
   - 版本索引 Key：`save_version`（純數字字串，例：`"1"`）。

2. **資料結構（JSON Blob）**
   - 必含欄位：
     - `save_version`: number（與當前 Schema 版本一致）
     - `memePoints`: number（玩家迷因點數）
     - `equipments`: object（`{ [equipId]: level:number }`）
     - `lastTs`: number（上次有效寫檔時間戳，毫秒 UTC）
   - 範例：
     ```json
     {
       "save_version": 1,
       "memePoints": 0,
       "equipments": { "youtube": 1, "idle_chip": 0 },
       "lastTs": 1724000000000
     }
     ```

3. **服務介面（`SecureSaveService`）**
   - `Future<void> init({required int currentVersion})`
     - 設定目前 `save_version`，嘗試讀取現有存檔，必要時觸發遷移或回退初始。
   - `Future<GameState> load()`
     - 讀取主 Key；若不存在→回傳初始狀態；若破損→嘗試讀備份→仍失敗則回退初始。
   - `Future<void> save(GameState state)`
     - 寫入流程：先寫備份 Key（覆蓋）、再原子寫入主 Key，最後校驗成功後更新 `lastTs`。
   - `Future<void> resetWithDoubleConfirm({required String confirmA, required String confirmB})`
     - 僅在 `confirmA == "RESET"` 且 `confirmB == "RESET"` 時執行；清除所有相關 Key。
   - `Future<void> migrateIfNeeded(int fromVersion, int toVersion)`
     - 預留遷移流程（stub）；逐版遞增遷移，確保資料不丟失。
   - `bool validate(GameState state)`
     - 基本驗證（類型/欄位存在/數值非負）；驗證失敗不可崩潰，需回退初始。

4. **版本化與遷移（Migration Stub）**
   - 若 `stored_version < currentVersion`：
     - 依序呼叫 `migrate(from, from+1)`，直到與 `currentVersion` 一致。
     - 每步遷移後立即 `save()` 與 `validate()`。
   - 若 `stored_version > currentVersion`：
     - 視為不可逆（降版），提示「版本過新」→回退初始並保留原始 Blob 於 `_bak`。

5. **寫入安全（原子性保護）**
   - 寫主 Key 前，先把舊主 Key 複製到備份 Key。
   - 寫主 Key 完成後，立即讀回驗證 JSON 可解析且 `validate()` 通過。
   - 任一階段失敗→回復備份 Key 內容，再回傳錯誤（不中斷遊戲主循環）。

6. **時鐘與時間戳**
   - `lastTs` 使用 `DateTime.now().toUtc().millisecondsSinceEpoch`。
   - 僅作為離線收益與資料新舊判定參考；不得用於安全風險判定。

7. **初始狀態（Fallback）**
   - 當主/備份皆不可用或驗證失敗→回傳：
     ```json
     {
       "save_version": <currentVersion>,
       "memePoints": 0,
       "equipments": {},
       "lastTs": <nowUTCms>
     }
     ```

---

## 3. 驗收標準
- ✅ 關閉 App 後重開，`memePoints` / `equipments` / `lastTs` 正確恢復。
- ✅ 提升 `save_version` 後，觸發 `migrateIfNeeded` 且資料不丟失。
- ✅ 觸發「重置存檔」（雙重確認）後，Secure Storage 中 `game_state_v*` / `*_bak` / `save_version` 相關 Key 皆被清空，進遊戲為初始狀態。
- ✅ 讀到非法/破損資料時不閃退、不中斷遊戲流程，自動回退初始並可繼續遊玩。
- ✅ 寫入過程任一環節出錯時，會透過備份回復，最終可成功讀取有效狀態。

---

## 4. 實例化需求測試案例

### 測試案例 1：基本保存與恢復
- **Given** 玩家當前 `memePoints = 123`、`equipments = {"youtube": 2}`  
- **When** 關閉 App 並重開  
- **Then** 讀取到 `memePoints = 123`、`equipments = {"youtube": 2}`、`lastTs` 為關閉前所寫入之 UTC 毫秒

---

### 測試案例 2：版本提升觸發遷移
- **Given** 既有存檔 `save_version = 1`，App `currentVersion = 2`  
- **When** 啟動 `SecureSaveService.init(currentVersion: 2)`  
- **Then** 觸發 `migrateIfNeeded(1→2)`，完成後 `save_version = 2` 並且 `memePoints`、`equipments` 值維持不變

---

### 測試案例 3：重置存檔（雙重確認）
- **Given** 目前 Secure Storage 內存在 `game_state_v2` / `game_state_v2_bak` / `save_version=2`  
- **When** 呼叫 `resetWithDoubleConfirm(confirmA: "RESET", confirmB: "RESET")`  
- **Then** 以上 Key 全部刪除；再次啟動 `load()` 回傳初始狀態（`memePoints=0`、空 `equipments`）

---

### 測試案例 4：破損資料回退
- **Given** 手動寫入主 Key 為無法解析之字串（如 `"{"not json"`）  
- **When** 呼叫 `load()`  
- **Then** 先嘗試讀 `_bak`；若 `_bak` 也破損，回退初始狀態；App 不崩潰、可正常進入遊戲

---

### 測試案例 5：原子寫入保護
- **Given** 正常已存在 `game_state_v2`，準備 `save()` 新狀態  
- **When** 模擬在寫主 Key 完成前發生例外  
- **Then** 重啟後 `load()` 會優先恢復 `_bak`，最終讀到有效且通過 `validate()` 的狀態

---

## 5. 限制與備註
- 版本需求：Flutter 3.22+、`flutter_secure_storage`（iOS Keychain / Android Keystore）。
- 本階段僅本機安全存檔，不涉及雲端/伺服器同步。
- **嚴禁** 在程式碼硬編初始數值；若需預設值請集中於 `GameState.initial(currentVersion)`。
- `validate()` 至少檢查：欄位存在、型別正確、數值非負；避免玩家因錯誤資料造成閃退。
- 如未來需要加密完整性校驗，可加 `checksum` 欄位（HMAC-SHA256）在不影響本階段行為下逐步導入。
