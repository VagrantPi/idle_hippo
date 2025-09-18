% Repository Guidelines

## Project Structure & Module Organization
- `lib/core/`: 共用邏輯（`router.dart`、assets 常數、事件 bus）。
- `lib/game/`: Flame 主遊戲（`hippo_game.dart`、components、systems）。
- `lib/ui/overlays/`: Flutter UI 覆蓋層（主選單、暫停、設定）。
- `lib/services/`: 儲存、音效、網路等服務與依賴注入。
- `assets/`: `images/`, `audio/`, `fonts/`, `lang/`, `config/`。
- `test/`: 單元與整合測試，路徑需對應 `lib/` 結構。
- Pinned：`main.dart`、`lib/game/hippo_game.dart`、`lib/core/router.dart`、`pubspec.yaml`、`docs/config.md`、`lib/models/game_state.dart`（變更前請先討論）。

## Build, Test, and Development Commands
- `flutter pub get`: 安裝套件。
- `flutter analyze`: 靜態分析，PR 必須為綠燈。
- `flutter test`: 執行測試（`flutter_test`）。
- `flutter run`: 本機啟動，使用真機或模擬器。
- CI（GitHub Actions）：PR 觸發 `pub get` → `analyze` → `test`。

## Coding Style & Naming Conventions
- Dart 風格：2 空白縮排；檔名 `lower_snake_case.dart`；類別/Enum 使用 `PascalCase`；方法/變數 `camelCase`。
- 不可使用全域狀態；透過 service 或 event bus 存取。
- Overlay 切換與導覽統一經由 `lib/core/router.dart`，禁止直接呼叫 `Navigator`。
- 固定視口：`FixedResolutionViewport(Vector2(1080, 1920))`。
- 顏色透明度：請用 `withValues` 取代 `withOpacity`。
- 資產必與 `pubspec.yaml` 對齊；新增或異動 `assets/config/*` 時，務必更新 `docs/config.md`。

## Testing Guidelines
- Framework：`flutter_test`。
- 命名：對應檔案使用 `*_test.dart`；描述文字使用繁體中文。
- 結構：`test/` 路徑鏡射 `lib/`；新增功能需附最小可行測試。
- 執行：`flutter test` 必須全綠後方可合併。

## Localization & Assets
- 任何 UI 顯示需同步更新 `assets/lang/*` 多語系字串。
- 新資產放入對應資料夾並更新 `pubspec.yaml`，避免資產遺漏。

## Config Document
- **docs/**：可額外存放 PM spec、遊戲設計圖
- 每次實作需求前都需要查看 assets/config 內參數，是否新需求有可以共用的，那就不需要再新增而外變數
- 每當在 assets/config 內新增數值，則需要更新 docs/config.md 文件

## Other Flutter Guidelines
- withOpacity 都改用 withValues 方法