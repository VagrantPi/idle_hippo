---
trigger: always_on
---

---
trigger: always_on
---

# CI 測試配置更新規則

## 🎯 核心原則

每次實作完測試檔案後，**必須**檢查並更新 [.github/workflows/flutter_test.yml](cci:7://file:///Users/kais/WS/idle_hippo/.github/workflows/flutter_test.yml:0:0-0:0) 中的測試分組配置。

## 📋 執行步驟

### 1. 測試檔案分類判斷

根據測試檔案的性質，判斷應歸類到哪個 `test-group`：

#### **core** 組別
- 配置服務測試（`config_service_*.dart`）
- 數值計算測試（`decimal_*.dart`、`meme_points_*.dart`）
- 持久化核心測試（[persistence_test.dart](cci:7://file:///Users/kais/WS/idle_hippo/test/persistence_test.dart:0:0-0:0)、`secure_save_*.dart`）
- 遊戲時鐘測試（[game_clock_test.dart](cci:7://file:///Users/kais/WS/idle_hippo/test/game_clock_test.dart:0:0-0:0)）

#### **services** 組別
- 各種遊戲服務測試（`*_service_test.dart`）
- 功能邏輯測試（`checkin_*.dart`、`daily_*.dart`、`gacha_*.dart` 等）
- 模型測試（`*_model_test.dart`）
- 任務相關測試（`quest_*.dart`、`main_quest_*.dart`）

### **step-tests** 組別 - 自動匹配
- `test/step*` ✅ **完全自動化**
- 所有 `step` 開頭的檔案或目錄都會自動包含

#### **ui-widgets** 組別
- Widget 測試（`*_widget_test.dart`）
- UI 頁面測試（`*_page_test.dart`、`*_screen_*.dart`）
- `test/ui/` 目錄下的所有測試

## 🔍 何時需要手動更新 CI？

### ✅ 不需要更新的情況
- 新增 `test/stepXX*/` 任何檔案或目錄

### ⚠️ 需要手動更新的情況

在對應的測試組別中新增測試檔案路徑：

```yaml
- name: Run [GROUP_NAME] tests
  if: matrix.test-group == '[GROUP_NAME]'
  run: |
    flutter test \
      [existing_tests...] \
      [NEW_TEST_FILE_PATH]