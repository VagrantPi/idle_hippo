# 📄 Step 0 規格書

## 1. 階段目標
- 建立 Flutter + Flame 專案基本骨架
- 規劃並建立專案資源目錄（images / audio / lang / config）
- 設定 `pubspec.yaml` 資源引用
- 放入暫用素材（placeholder）與簡易啟動畫面

---

## 2. 功能需求
1. 專案結構應包含以下目錄：
   - `lib/`：主要程式碼
   - `assets/images/`：遊戲圖片資產
   - `assets/audio/`：遊戲音效與音樂
   - `assets/lang/`：多語系 JSON 檔
   - `assets/config/`：數值與設定檔
2. `pubspec.yaml` 應正確註冊上述資源路徑
3. 遊戲啟動後顯示一個主畫面
4. 主畫面包含：
   - 標題文字：「Idle Hippo」
   - 數字顯示：初始值為 `0`

---

## 3. 驗收標準
- ✅ App 成功啟動且不閃退
- ✅ 首次進入遊戲能看到「Idle Hippo」標題
- ✅ 畫面中央顯示數字 `0`
- ✅ 修改 `pubspec.yaml` 後可正常載入 placeholder 資源
- ✅ App 在 Android / iOS 模擬器均能啟動並顯示相同結果

---

## 4. 實例化需求測試案例

### 測試案例 1：專案啟動
- **Given** 玩家安裝並啟動遊戲  
- **When** App 成功載入  
- **Then** 畫面顯示標題「Idle Hippo」與數字 `0`  

---

### 測試案例 2：資源目錄驗證
- **Given** 專案中已建立 `assets/images/placeholder.png`  
- **When** 修改 `pubspec.yaml` 加入該路徑並啟動遊戲  
- **Then** 遊戲啟動過程中不應發生資源載入錯誤  

---

### 測試案例 3：跨平台驗證
- **Given** 遊戲專案在 Android 與 iOS 環境  
- **When** 分別啟動遊戲  
- **Then** 主畫面應顯示一致內容（Idle Hippo + 數字 0）  

---

## 5. 限制與備註
- 使用 Flutter 3.22+ 與 Flame ^1.17+
- 本階段僅需顯示靜態畫面，無需遊戲邏輯
- 資產允許使用暫時 placeholder（文字/圖片均可）
- 不需後端或外部 API 支援
