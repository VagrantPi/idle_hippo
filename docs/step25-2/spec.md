# 📄 Step 25-2 規格書（寵物系統引導）

---

## 1. 階段目標
- 新增「寵物系統引導」：逐步高亮並限制點擊範圍。
- 引導流程需持久化，支援中途退出後重開 App 從斷點繼續。
- 完成後不再觸發（除非玩家手動重置存檔）。
- 所有提示文字需支援 **i18n**。
- 完成引導後，給予玩家 10 張寵物抽獎券並跳出通知。

---

## 2. 功能需求

### 2.1 教學流程控制
- 教學狀態存於 `tutorial_pet_step`。
- 每步包含：
  - `focusTarget`（UI 元件 ID）
  - `overlay`（高亮＋遮罩）
  - `instruction_key`（多語文字）
  - `action`（觸發條件）
- 步驟完成 → 更新 `tutorial_pet_step = nextStep`。
- 完成全部 → 記錄 `tutorial_pet_completed=true`。

### 2.2 教學步驟（完整 4 步）
1. **寵物頁面**  
   - Focus：nav 寵物按鈕。  
   - Instruction：`pet_intro`。  
   - 等待 1 秒後顯示【下一步】。  
2. **返回首頁**  
   - Focus：nav 首頁按鈕。  
   - Instruction：`back_home`。  
3. **首頁顯示抽獎券**  
   - Focus：首頁寵物抽獎券顯示區域。  
   - Instruction：`pet_ticket_info`。  
   - 等待 1 秒後顯示【下一步】。  
4. **結束引導**  
   - 結束教學 → 彈窗提示「獲得 10 張寵物抽獎券」→ 更新玩家狀態，實際新增 10 張。

### 2.3 UI/UX
- 遮罩：半透明黑，僅允許 focus 元件可操作。
- 說明文字：顯示於 focus 區域附近；多語系切換。
- 按鈕：【下一步】淡入動畫。

### 2.4 狀態儲存
```json
{
  "tutorial_pet": {
    "step": 0,
    "completed": false,
    "rewardGiven": false
  }
}
````

* `step=0`：未開始；完成第 N 步 → 記錄 `step=N`。
* `completed=true`：流程完成，App 重啟不再觸發。
* `rewardGiven=true`：已發放 10 張抽獎券，避免重複。

### 2.5 i18n（示例）

```json
{
  "tutorial.pet_intro": {
    "zh": "寵物可以靠抽卡獲取，寵物是你最強力的夥伴",
    "en": "Pets can be obtained through gacha, they are your strongest allies"
  },
  "tutorial.back_home": {
    "zh": "返回首頁",
    "en": "Return to Home"
  },
  "tutorial.pet_ticket_info": {
    "zh": "現在開始可以通過每日任務獲得抽獎券",
    "en": "You can now earn gacha tickets from daily quests"
  },
  "tutorial.pet_ticket_reward": {
    "zh": "獲得 10 張寵物抽獎券！",
    "en": "You received 10 Pet Gacha Tickets!"
  }
}
```

---

## 3. 驗收標準

* ✅ 完成主線第三章 → 自動觸發寵物引導流程。
* ✅ 引導進度可持久化：退出 App 後重開 → 從中斷步驟繼續。
* ✅ 流程完成後，`tutorial_pet.completed=true`，重啟不再觸發。
* ✅ 每個步驟僅允許操作指定 focus 元件，其他區域無效。
* ✅ 引導結束時彈窗通知並正確發放 10 張抽獎券。
* ✅ i18n 正常顯示：不同語言模式下文字正確。

---

## 4. 實例化需求測試案例

### 測試案例 1：完整流程

* **Given** 完成主線第三章
* **When** 依指示走完 4 步
* **Then** 教學結束並領取 10 張寵物抽獎券

### 測試案例 2：中途退出

* **Given** 進行到步驟 2
* **When** 關閉 App 再次打開
* **Then** 教學從步驟 2 繼續

### 測試案例 3：重置存檔

* **Given** 教學已完成
* **When** 重置存檔
* **Then** 教學重新觸發，從步驟 0 開始

### 測試案例 4：重複領取防護

* **Given** 教學完成並已領取獎勵
* **When** 再次啟動 App
* **Then** 不會重複給予抽獎券
