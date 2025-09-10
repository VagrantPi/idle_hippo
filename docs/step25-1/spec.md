# 📄 Step 25-1 規格書（初始遊戲故事、新手教學引導、寵物系統引導）

---

## 1. 階段目標
- 新增「新手教學」系統，逐步高亮並限制點擊範圍。
- 教學進度需持久化，支援中途退出後重開 App 可從斷點繼續。
- 完成後不再重複觸發（除非玩家手動重置存檔）。
- 所有提示文字均需支援 **i18n**。
- 漫畫式劇情開場（manga01~manga04），帶翻頁效果。

---

## 2. 功能需求

### 2.1 教學流程控制
- 教學步驟以 `tutorial_step` 狀態機管理（存於存檔）。
- 每步驟含：
  - `focusTarget`（UI 元件 ID）
  - `overlay`（深色遮罩＋高亮 focus 範圍）
  - `instruction_key`（多語文字）
  - `action`（觸發條件：點擊/領取/完成條件等）
- 教學步驟完成 → 記錄 `tutorial_step = nextStep` → 觸發下一步。
- 完成所有教學 → 記錄 `tutorial_completed=true`，不再重複。

### 2.2 教學步驟（完整 13 步）
1. **漫畫劇情**：依序播放 `manga01~04`，翻頁效果（點擊螢幕跳下一頁）。
2. **點擊河馬**：Focus 河馬，提示 `tap_hippo`。
3. **主線任務入口**：累積 10 點 → Focus 主線任務按鈕，提示 `open_mainline`。
4. **主線任務頁**：Focus 上方階段名稱，提示 `mainline_story`。
5. **主線任務領取**：Focus 領取按鈕，提示 `claim_first_mainline`。
6. **裝備升級**：自動導向裝備頁 → Focus 「YouTube」裝備升級按鈕，提示 `upgrade_youtube`。
7. **返回首頁**：Focus nav 首頁按鈕，提示 `back_home`。
8. **首頁點數解釋**：Focus 點數區塊，提示 `explain_idle_vs_tap`。
9. **每日任務**：Focus 每日任務按鈕，提示 `daily_quests`。
10. **每日打卡**：Focus 設定按鈕，提示 `daily_checkin_entry`。
11. **打卡詳解**：設定頁內 focus 打卡任務，提示 `daily_checkin_detail`。
12. **返回首頁**：Focus nav 首頁按鈕，提示 `back_home_again`。
13. **結語**：整頁遮罩顯示「接下來是河馬寶寶成為傳說的開始」，等待 1s 後顯示【下一步】；玩家點擊【下一步】即標記 `tutorial_completed=true`。

### 2.3 UI/UX
- 遮罩：半透明黑，focus 範圍（圓/矩形）高亮。
- 說明文字：顯示於 focus 區塊附近；支援多語。
- 動畫：下一步按鈕淡入；小紅點提示沿用任務頁紅點動畫。
- **漫畫劇情**：
  - 圖片資源：`assets/images/manga/manga01.png` ~ `manga04.png`
  - 翻頁：點擊螢幕觸發下一頁；帶漸淡或滑動效果。

### 2.4 狀態儲存
```json
{
  "tutorial": {
    "step": 0,
    "completed": false
  }
}
````

* `step=0`：未開始；完成第 N 步 → 記錄 `step=N`。
* `completed=true`：完成全部流程，App 重啟後不再顯示。

### 2.5 i18n（示例）

```json
{
  "tutorial.tap_hippo": {"zh":"點擊角色可以獲得迷因點數","en":"Tap the Hippo to earn Meme Points"},
  "tutorial.open_mainline": {"zh":"點擊主線任務首頁","en":"Open the Mainline Quest"},
  "tutorial.mainline_story": {"zh":"隨著主線任務發展，河馬寶寶可以成為迷因王","en":"Follow the Mainline to help Hippo become the Meme King"},
  "tutorial.claim_first_mainline": {"zh":"開啟成為迷因王的第一步吧","en":"Claim the first step towards becoming Meme King"},
  "tutorial.upgrade_youtube": {"zh":"升級 YouTube 裝備一次","en":"Upgrade the YouTube equipment once"},
  "tutorial.back_home": {"zh":"返回首頁","en":"Return to Home"},
  "tutorial.explain_idle_vs_tap": {"zh":"被動累積離線獎勵上限為 6 小時","en":"Idle accumulation has a 6-hour offline cap"},
  "tutorial.daily_quests": {"zh":"除了主線任務以外還有每日任務可以解","en":"Complete Daily Quests for extra rewards"},
  "tutorial.daily_checkin_entry": {"zh":"此外還有每日打卡任務","en":"You also have a Daily Check-in task"},
  "tutorial.daily_checkin_detail": {"zh":"連續打卡七日可獲得半日放置收益","en":"Check in 7 days to earn half a day's idle rewards"},
  "tutorial.back_home_again": {"zh":"返回首頁","en":"Back to Home"},
  "tutorial.epilogue": {"zh":"接下來是河馬寶寶成為傳說的開始","en":"This is the beginning of Hippo's legend"}
}
```

---

## 3. 驗收標準

* ✅ 新安裝 App → 會完整觸發 13 步引導流程。
* ✅ 引導進度可持久化：退出 App 後再開 → 繼續從中斷步驟。
* ✅ 引導完成後，`tutorial.completed=true`，App 重啟不再觸發。
* ✅ i18n 正常顯示：不同語言模式下說明文字正確切換。
* ✅ 漫畫式劇情可逐頁翻閱（manga01\~04），有翻頁效果。
* ✅ Focus 範圍正確：遮罩僅允許當前步驟操作，其餘 UI 鎖定。
* ✅ 領取主線、升級裝備、每日任務、每日打卡等互動皆能被正確引導並完成。

---

## 4. 實例化需求測試案例

### 測試案例 1：完整流程

* **Given** 新安裝
* **When** 按指示完成 13 步
* **Then** 教學完成，`tutorial.completed=true`

### 測試案例 2：中途退出

* **Given** 進行到步驟 6
* **When** 關閉 App 再次打開
* **Then** 教學從步驟 6 繼續，而非重置

### 測試案例 3：重置存檔

* **Given** 教學已完成
* **When** 重置存檔
* **Then** 教學流程會重新觸發，從步驟 0 開始

### 測試案例 4：語言切換

* **Given** 教學流程進行中
* **When** 切換至日文
* **Then** 下一步的提示文字為日文翻譯版本

### 測試案例 5：Focus 正確性

* **Given** 在步驟 9（每日任務引導）
* **When** 嘗試點擊非 focus 區域
* **Then** 無效操作，僅允許焦點元件可點擊
