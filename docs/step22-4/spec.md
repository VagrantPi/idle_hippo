# 📄 Step 22-4 規格書（分數、COMBO、UI 與結算／入帳）

> 承接 22-2（音符生成）與 22-3（輸入與判定）。本階段加入 **分數規則、COMBO、即時 UI、結算畫面**，並在結算時計算**最終迷因點數**並**直接入帳**。不處理「每日次數限制」與「觀看廣告加次」——留待後續階段。

---

## 1. 階段目標
- 依判定輸出（PERFECT/GREAT/MISS）累計**分數**與**連擊 COMBO**。
- 採用 **Combo 乘算加成**：`finalMemePoints = baseScoreSum × comboMultiplier`。
- 顯示遊玩中 HUD（分數、剩餘時間、當前/歷史最大 COMBO、即時判定字樣）。
- 音樂結束自動彈出**結算畫面**，展示各項統計並**直接入帳**迷因點數；確認後回歌曲選單。

---

## 2. 規則定義

### 2.1 基礎分數（每 Hit）
- PERFECT：`+1.0`
- GREAT：`+0.5`
- MISS：`+0.0`（不加分）

> **注意**：一顆音符只會被判定一次（延續 22-3）。

### 2.2 COMBO 規則
- **累積條件**：PERFECT 或 GREAT → `combo += 1`
- **斷裂條件**：MISS → `combo = 0`
- **歷史最大**：`maxCombo = max(maxCombo, combo)`（本次遊玩期間的最高值）

### 2.3 Combo 乘算加成
- 公式：  
  `comboMultiplier = 1 + 0.1 × floor(maxCombo / 10)`
- **最終迷因點數**：  
  `finalMemePoints = roundDown(baseScoreSum × comboMultiplier, 2)`  
  - `baseScoreSum`：全曲分數規則的總和（浮點）  
  - `roundDown(x, 2)`：**向下取 2 位小數**（避免四捨五入帶來超付）

> 範例：`maxCombo=123` → `floor(123/10)=12` → 乘算 `×(1+1.2)=×2.2`

---

## 3. UI/UX

### 3.1 遊玩中 HUD（固定置於全螢幕頁）
- **分數**：`Score: {baseScoreSum}`（向下取 2 位小數顯示）
- **剩餘時間**：顯示 `mm:ss` 倒數（或正計時亦可；需與曲長一致）
- **COMBO**：`{combo} COMBO`（當前值）＋**最高**：`MAX {maxCombo}`
- **即時判定彈字**：在判定線上方短暫顯示（200~350ms）：
  - PERFECT（綠/金） / GREAT（藍） / MISS（紅，且震動可選）
  - 文案多語：`"Perfect" | "Great" | "Miss"`

> 暫停時 HUD 停止計時；恢復時對齊音訊時間（沿用 22-2 時鐘策略）。

### 3.2 結算畫面（樂曲播放完畢自動彈出）
- **統計**：
  - PERFECT 次數 `perfectCount`
  - GREAT 次數 `greatCount`
  - MISS 次數 `missCount`
  - 歷史最大 COMBO：`maxCombo`
  - Combo 加成：`×{comboMultiplier}`
  - 基礎分數（未乘算）：`baseScoreSum`
  - **總迷因點數**（乘算且向下取 2 位）`finalMemePoints`
- **流程**：
  1) 計算 `finalMemePoints`
  2) **直接入帳**（寫回 `game_state.memePoints += finalMemePoints`）
  3) 顯示結算畫面（含一顆【確認】）
  4) 按【確認】→ 返回歌曲選單頁
- **提示**：入帳已完成（避免玩家以為需按確認才領）

---

## 4. 事件銜接

### 4.1 與 22-3 的判定介面
- 由 `onJudge(lane, grade, deltaMs)` 回呼觸發本階段計算：
  ```dart
  void onJudge(JudgeGrade grade) {
    switch (grade) {
      case PERFECT: baseScoreSum += 1.0; combo++; break;
      case GREAT:   baseScoreSum += 0.5; combo++; break;
      case MISS:    combo = 0; break;
    }
    if (combo > maxCombo) maxCombo = combo;
    showFloatingJudgeText(grade); // 200~350ms 消失
    refreshHUD();
  }
````

* 逾時 MISS（22-3 自動 MISS）亦會走 `onJudge(MISS, ...)`。

### 4.2 曲終（自然播放完成或提早終止）

* 自然結束：播放器 `onCompleted` 觸發 `openResult()`
* 提早終止（返回鍵）：本階段**不結算**並直接離場（若要中斷結算，需另列規則；此步先忽略）

---

## 5. 儲存／持久化

* 本次遊玩僅保存對 **迷因點數** 的入帳；其他統計不長存（可於後續做成歷史紀錄）。
* 更新點：

  * `game_state.memePoints += finalMemePoints`
  * 可附帶 Debug 記錄（songId, level, finalMemePoints）

---

## 6. i18n（最少鍵）

```json
{
  "ktv.hud.score": {"zh":"分數","en":"Score"},
  "ktv.hud.time": {"zh":"剩餘時間","en":"Time Left"},
  "ktv.hud.combo": {"zh":"COMBO","en":"COMBO"},
  "ktv.hud.max_combo": {"zh":"最高 COMBO","en":"MAX COMBO"},
  "ktv.judge.perfect": {"zh":"Perfect","en":"Perfect"},
  "ktv.judge.great": {"zh":"Great","en":"Great"},
  "ktv.judge.miss": {"zh":"Miss","en":"Miss"},

  "ktv.result.title": {"zh":"結算","en":"Results"},
  "ktv.result.perfect": {"zh":"PERFECT 次數","en":"PERFECT"},
  "ktv.result.great": {"zh":"GREAT 次數","en":"GREAT"},
  "ktv.result.miss": {"zh":"MISS 次數","en":"MISS"},
  "ktv.result.max_combo": {"zh":"歷史最大 COMBO","en":"Max Combo"},
  "ktv.result.combo_bonus": {"zh":"Combo 加成","en":"Combo Bonus"},
  "ktv.result.base_score": {"zh":"基礎分數","en":"Base Score"},
  "ktv.result.total_meme": {"zh":"總迷因點數","en":"Total Meme Points"},
  "ktv.result.ok": {"zh":"確認","en":"OK"}
}
```

---

## 7. Telemetry（預留至 Step 33）

* `karaoke_play_start {songId, level}`
* `karaoke_hit {grade}`（PERFECT/GREAT/MISS）
* `karaoke_combo_update {combo, maxCombo}`
* `karaoke_play_end {songId, level, perfect, great, miss, maxCombo, baseScore, multiplier, finalMeme}`

---

## 8. 驗收標準

* ✅ **全 PERFECT** 測試譜（固定偏移）：`baseScoreSum == noteCount × 1.0`；`maxCombo == noteCount`；`finalMemePoints = baseScoreSum × (1 + 0.1 × floor(noteCount/10))`。
* ✅ 插入 **N 次 GREAT**：僅將相應 N 顆分數由 1.0 改 0.5，其餘不變；COMBO 不中斷。
* ✅ 有 **MISS** 時，當下 `combo=0`；`maxCombo` 保持歷史最大值（不因 MISS 下降）。
* ✅ 倒數時間與曲長一致（±100ms 以內），播放結束自動進入結算。
* ✅ 結算畫面各數值（PERFECT/GREAT/MISS/MaxCombo/Combo 加成/總點數）正確，且**點確認只返回，不再重複入帳**。
* ✅ 結算一出現即已入帳；返回歌曲清單後 `memePoints` 已增加。

---

## 9. 實例化需求測試案例

### 案例 1：全 PERFECT

* **Given** 譜面 100 顆；固定點擊偏移 0ms
* **When** 完成
* **Then** `baseScoreSum=100.0`、`maxCombo=100`、`multiplier=1+0.1×floor(100/10)=2.0`、`finalMeme=200.0`

### 案例 2：含 GREAT（不斷 combo）

* **Given** 譜面 10 顆；其中 2 顆為 GREAT
* **When** 完成
* **Then** `baseScoreSum=8×1 + 2×0.5 = 9.0`；`maxCombo=10`；`multiplier=1+0.1×floor(10/10)=2.0`；`finalMeme=18.0`

### 案例 3：含 MISS（斷 combo）

* **Given** 譜面 10 顆；第 6 顆 MISS，其餘 PERFECT
* **When** 完成
* **Then** `baseScoreSum=9.0`；`combo` 於第 6 顆歸零，後續重新累積；`maxCombo` = `max(5,4)=5`；`multiplier=1+0.1×floor(5/10)=1.0`；`finalMeme=9.0`

### 案例 4：時間一致性

* **Given** 曲長 120 秒
* **When** 從 00:00 播放至結束
* **Then** HUD 倒數顯示與播放器時間一致（最大偏差 ≤ 0.1s），結束自動彈出結算

### 案例 5：入帳一次性

* **Given** 結算畫面顯示 `finalMeme=12.5`
* **When** 多次點擊【確認】或返回
* **Then** 只入帳一次（結算前已入帳）；`memePoints` 增加 12.5，無重覆

---

## 10. 實作備註

* **浮點誤差**：累計分數時用 `double`，結算前做 `roundDown(..., 2)` 後再入帳。
* **HUD 效能**：高頻更新（每幀）僅改變實際變動的數值；判定彈字使用物件池避免 GC 尖峰。
* **暫停與恢復**：倒數顯示取自音訊權威時間，與 22-2 時序對齊；暫停時凍結。
* **回到清單**：結算關閉後清除場景內狀態（分數、combo、統計）以備下次進場。
