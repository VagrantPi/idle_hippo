# 📄 Step 1 規格書

## 1. 階段目標
- 建立遊戲設定檔結構，並集中於 `assets/config/`。
- 建立 `ConfigService`，負責讀取 JSON 設定並快取於記憶體。
- 支援修改設定檔後的熱重載（hot reload）並即時反映在遊戲內。

---

## 2. 功能需求
1. 在 `assets/config/` 目錄下建立以下檔案：
   - `game.json`：遊戲全域設定（基礎點擊收益、基礎放置收益、每日點擊上限等）。
   - `equipments.json`：裝備資料（裝備 ID、名稱、加成類型、升級消耗與倍率）。
   - `pets.json`：寵物資料（寵物 ID、稀有度、初始放置收益、升級規則）。
   - `titles.json`：稱號資料（稱號 ID、解鎖條件、展示文字）。
   - `quests.json`：任務資料（任務 ID、目標條件、獎勵內容）。
2. `pubspec.yaml` 中正確註冊 `assets/config/` 以確保檔案可載入。
3. 建立 `ConfigService`：
   - 提供 `loadConfig()` 方法讀取所有 JSON 並快取於記憶體。
   - 提供 `getValue(path)` API，例如：`getValue("game.tap.base") → 1`。
   - 支援 hot reload 重新載入 JSON，並即時更新記憶體中的值。
4. Debug 面板（可簡易 UI 或 console 輸出）需顯示至少三個設定值：
   - `tap.base`
   - `idle.base_per_sec`
   - `dailyTapCap`

---

## 3. 驗收標準
- ✅ 啟動遊戲後，`ConfigService` 成功載入所有配置檔案，無錯誤訊息。
- ✅ Debug 面板顯示 `tap.base=1`、`idle.base_per_sec=0.1`、`dailyTapCap=200`。
- ✅ 修改 `game.json` 中任一數值，重新 hot reload 後 Debug 面板立即反映更新。
- ✅ 載入不存在的 key 時，回傳錯誤訊息或安全預設值（不閃退）。

---

## 4. 實例化需求測試案例

### 測試案例 1：載入配置檔案
- **Given** `assets/config/game.json` 設定 `"tap.base": 1`  
- **When** 遊戲啟動並呼叫 `ConfigService.getValue("game.tap.base")`  
- **Then** 應回傳 `1`  

---

### 測試案例 2：Debug 面板輸出
- **Given** 遊戲已成功載入配置  
- **When** 打開 Debug 面板  
- **Then** 應看到 `tap.base=1, idle.base_per_sec=0.1, dailyTapCap=200`  

---

### 測試案例 3：Hot reload 更新
- **Given** `game.json` 中 `"tap.base": 1`  
- **When** 修改為 `"tap.base": 10` 並重新 hot reload  
- **Then** Debug 面板應顯示 `tap.base=10`  

---

### 測試案例 4：錯誤 key 安全性
- **Given** `ConfigService` 嘗試讀取 `"game.unknownKey"`  
- **When** 呼叫 `getValue("game.unknownKey")`  
- **Then** 應回傳錯誤提示或 `null`，遊戲不應閃退  

---

## 5. 限制與備註
- 使用 Flutter 3.22+ 與 Flame ^1.17+
- 本階段僅需讀取靜態 JSON 配置，不需連接後端
- Debug 面板 UI 可簡易（文字顯示即可）
- 所有數值需由 JSON 驅動，程式碼內禁止硬編固定值
