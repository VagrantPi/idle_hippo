# 📄 Step 14 規格書（主線階段任務：解鎖系統）

## 1. 階段目標

- 主線任務於既有的任務頁面分頁
- 實作主線任務系統，共 6 個階段（新生階段→宇宙級迷因之神）。
- 任務以「累積點擊數 / 累積能量」為條件，完成後依序解鎖對應系統或獎勵。
- UI：主畫面右側功能列（Step 4 預留）中新增「主線任務」入口，點開後可看到進度與下一個目標。
- 完成時播放特效並提示解鎖內容。

---

## 2. 功能需求

### 2.1 任務資料（固定 6 段）
以 JSON 配置（`assets/config/quests.json`）：
```json
{
  "mainline": [
    {
      "id": "stage1",
      "title_key": "quest.stage1.title",
      "requirement": { "type": "tap_count", "value": 10 },
      "reward": { "unlock": "equip.youtube" }
    },
    {
      "id": "stage2",
      "title_key": "quest.stage2.title",
      "requirement": { "type": "meme_points", "value": 100 },
      "reward": { "unlock": "system.title" }
    },
    {
      "id": "stage3",
      "title_key": "quest.stage3.title",
      "requirement": { "type": "meme_points", "value": 1000 },
      "reward": { "unlock": "system.pet" }
    },
    {
      "id": "stage4",
      "title_key": "quest.stage4.title",
      "requirement": { "type": "meme_points", "value": 50000 },
      "reward": { "unlock": "hippo.skin1" }
    },
    {
      "id": "stage5",
      "title_key": "quest.stage5.title",
      "requirement": { "type": "meme_points", "value": 100000 },
      "reward": { "unlock": "hippo.skin2" }
    },
    {
      "id": "stage6",
      "title_key": "quest.stage6.title",
      "requirement": { "type": "meme_points", "value": 500000 },
      "reward": { "unlock": "hippo.skin3" }
    }
  ]
}
````

### 2.2 任務判定條件

* **tap\_count**：監聽 Step 5 點擊玩法事件，統計有效點擊次數（不受每日上限限制）。
* **meme\_points**：判斷「歷史累積獲得的總能量」（包含 tap / idle / 離線 / 任務獎勵），不受升級扣費影響。

### 2.3 解鎖效果

* **equip.youtube**：裝備系統（Step 7/9 已有基礎），新增一件「YouTube」裝備到清單，圖示 `assets/images/equipment/YouTube.png`。
* **system.title**：解鎖稱號系統入口（右側功能列 icon 啟用）。
* **system.pet**：解鎖寵物系統入口（右側功能列 icon 啟用）。
* **hippo.skin1/2/3**：新增河馬寶寶進化造型，顯示於角色造型選單。

### 2.4 UI 流程

* 主線任務入口（右側欄）顯示當前階段標題。
* 點開 → 顯示：

  * 當前階段名稱（i18n）
  * 當前進度 / 目標值
  * 解鎖預覽（icon + 文案）
* 完成任務時：

  * 彈出提示彈窗：「完成【新生階段】，解鎖 YouTube 裝備！」（i18n）
  * 音效 + 特效
  * 自動切換到下一階段顯示

### 2.5 存檔資料

在 `game_state_v{save_version}` 中新增：

```json
{
  "mainQuest": {
    "currentStage": 1,
    "tapCountProgress": 0,
    "memePointsEarned": 0
  }
}
```

* `tapCountProgress`：統計有效點擊累計（不因跨日清零）。
* `memePointsEarned`：統計歷史累計獲得點數（不可回退）。

### 2.6 i18n 文案

```json
{
  "quest.stage1.title": {"en":"Newborn Stage","zh":"新生階段","jp":"新生ステージ","ko":"신생 단계"},
  "quest.stage2.title": {"en":"Meme Rookie","zh":"迷因小菜鳥階段","jp":"ミーム初心者","ko":"밈 루키 단계"},
  "quest.stage3.title": {"en":"Animal Meme Stage","zh":"動物迷因階段","jp":"動物ミームステージ","ko":"동물 밈 단계"},
  "quest.stage4.title": {"en":"Hippo Meme Stage","zh":"梗圖河馬階段","jp":"ミームカバステージ","ko":"밈 하마 단계"},
  "quest.stage5.title": {"en":"Meme Superstar","zh":"迷因巨星階段","jp":"ミームスーパースター","ko":"밈 슈퍼스타"},
  "quest.stage6.title": {"en":"Cosmic Meme God","zh":"宇宙級迷因之神","jp":"宇宙級ミーム神","ko":"우주급 밈 신"}
}
```

---

## 3. 驗收標準

* ✅ **階段輪替**：完成一階段任務後，自動解鎖獎勵並切換到下一階段。
* ✅ **tap\_count 任務**：點擊 10 次後，彈窗提示「完成 新生階段，解鎖 YouTube 裝備」，裝備清單中出現 YouTube。
* ✅ **meme\_points 任務**：達到指定能量後觸發，扣費升級不影響累積；完成後彈窗提示正確。
* ✅ **解鎖寵物**：走到「動物迷因階段」時，右側「寵物」入口啟用可進入。
* ✅ **持久化**：重啟 App 仍保留當前階段進度與已解鎖內容。
* ✅ **完成宇宙級迷因之神**：到達 50 萬能量，解鎖最終造型並任務條顯示「已全部完成」。

---

## 4. 實例化需求測試案例

### 案例 1：新生階段

* **Given** `tapCountProgress=9`，`currentStage=1`
* **When** 點擊一次角色
* **Then** `tapCountProgress=10`，完成任務，彈窗提示「解鎖 YouTube 裝備」，`currentStage=2`

---

### 案例 2：迷因小菜鳥階段

* **Given** `memePointsEarned=95`，`currentStage=2`
* **When** 再獲得 10 點數
* **Then** 累計 =105 ≥100，完成任務，彈窗提示「開啟稱號系統」，稱號入口啟用，`currentStage=3`

---

### 案例 3：動物迷因階段

* **Given** `memePointsEarned=995`，`currentStage=3`
* **When** 再獲得 20 點數
* **Then** 完成「動物迷因階段」，彈窗提示「開啟寵物系統」，寵物入口可進，`currentStage=4`

---

### 案例 4：造型解鎖

* **Given** `memePointsEarned=50000`，`currentStage=4`
* **When** 任務觸發完成
* **Then** 新造型出現在造型列表，角色可切換，`currentStage=5`

---

### 案例 5：最終階段

* **Given** `memePointsEarned=499000`，`currentStage=6`
* **When** 再獲得 2000 點數
* **Then** 彈窗提示「解鎖最終造型」，任務列表顯示「全部完成」

---

## 5. 限制與備註

* 本系統僅限主線任務，與 Step 13 每日任務條分開運作。
* 任務條 UI：若主線任務未完成 → 優先顯示主線進度；完成全部 → 顯示「全部完成」靜態文字。
* 任務進度以「歷史總獲得」計算，避免扣費造成玩家誤解。
* 每階段獎勵僅能觸發一次，不可重複領取。

