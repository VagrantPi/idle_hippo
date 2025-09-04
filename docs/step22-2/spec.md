# 📄 Step 22-2 規格書（軌道渲染與音符生成）

> 承接 Step 22-1：已能載入歌曲與進入全螢幕播放。本階段建立 **透視軌道 + 音符生成/移動/銷毀** 的時序骨架，尚未實作判定與計分（留到下一步）。

---

## 1. 階段目標
- 依選擇難度渲染 **3（easy）/ 5（hard）條透視軌道**（KeyCount）。
- 解析 beatmap（`[{time, position}]`），依 `approachTime` 在 `time-approachTime` 生成音符。
- 音符自上而下移動，於 `time` 抵達 **判定線（Judgeline）**。
- 支援 **暫停/恢復**：停止 BGM 時音符停止移動，恢復時不跳拍。

---

## 2. 功能需求

### 2.1 參數（可配置，`assets/config/game.json`）
```json
{
  "ktv": {
    "approachTimeMs": 1500,          // 音符從生成到抵達判定線所需時間（毫秒）
    "judgelineY": 0.82,              // 判定線相對螢幕高度 (0~1)，例 0.82 = 螢幕高度 82% 處
    "spawnY": 0.02,                   // 生成起點相對螢幕高度（約自頂部 2% 處開始，可視化佔滿約 4/5 高度）
    "lanePadding": 16,                // 軌道間水平留白（px）
    "perspectiveDepth": 0.60,         // 透視收斂比例（0~1，越大越陡，製造遠近差）
    "noteBaseSize": 56,               // 音符基準像素（judgeline 處）
    "enableObjectPool": true,         // 啟用物件池
    "maxActiveNotes": 256             // 安全上限
  }
}
````

### 2.2 軌道（Lane）渲染

* **KeyCount**：取自選擇難度的 `difficulties[].key_count`（easy=3、hard=5）。
* **透視效果**：整排軌道在遠端收斂為一個大梯形；各軌道為內部分段梯形：

  * 上緣較窄、下緣較寬；收斂比由 `perspectiveDepth` 控制（以畫面中心為縮放中心）。
  * 軌道間間距（`lanePadding`）與軌道本身同樣隨高度線性縮放（越靠上越窄）。
* **顏色/樣式**（暫定）：

  * 軌道底色半透明；軌道邊線略亮；Judgeline 在 `judgelineY` 畫一條強對比線。
  * Judgeline 厚度：為藍色音符高度的 2 倍（實線與半透明區域同厚）。
    - 藍色音符在判定線處的高度 = `laneWidth(judgelineY) * 0.6`。
    - 因此橘色判定線面積高度 = `noteBaseSize * 0.72`（各軌道在判定線處寬度一致）。
* **尺寸自適應**：全螢幕頁面於直/橫向都能居中鋪滿；比例以短邊為基準縮放。

### 2.3 音符（Note）生成與生命週期

* **資料來源**：`currentSong.difficulties[level].beatmap[]`，元素 `{ time: number, position: 1..keyCount }`（秒）。
* **生成時機**：

  * 以 **BGM 播放時間 `t_audio`** 為準（非動畫內部時間）。
  * 當 `t_audio >= note.time - approachTime` 時，生成對應 Note（若已生成則略過）。
* **生命週期**：`Spawn → Travel → 到達判定線（time）→ 持續下滑 → Despawn`

  * 本階段尚未進入「判定」；音符通過判定線後繼續向下移動，直到離開畫面下緣才回收。
* **座標與速度**：

  * `spawnY_px = screenH * spawnY`（通常為負值，螢幕外）
  * `judgeY_px = screenH * judgelineY`
  * **總位移** `D = judgeY_px - spawnY_px`
  * **速度** `v = D / approachTime`（px/sec），以 `delta` 線性更新 `y += v * deltaSec`
  * **透視縮放**：音符隨 y 調整，且與軌道同寬：
    - `noteWidth(y) = laneWidth(y)`；`noteHeight(y) = noteWidth(y) * 0.6`
    - 音符中心沿軌道中心線移動：`noteX(y) = laneCenterX(y)`（非固定直線）
* **水平位置**：

  * 以 `position ∈ [1..keyCount]` 對應到該軌道的**中心線** X；音符沿中心線垂直移動。

### 2.4 時序與同步

* **時間源**：採用**音訊播放進度**做為真實時間（權威時鐘），避免累積漂移。

  * 每幀讀取 `audioPositionSec()` 作為 `t_audio`。
  * 若 `pause`，音訊暫停，`t_audio`不增加；音符也停止移動。
* **生成掃描**：

  * Beatmap 以**時間排序**一次載入；用一個遞增索引 `nextIdx` 指向下一顆待生成音符。
  * 每幀檢查 `while (t_audio + epsilon >= note.time - approachTime)` 生成並 `nextIdx++`。
* **暫停/恢復**：

  * 暫停：暫停音訊；停止 `onTick` 對音符位置更新（或速度視為 0）。
  * 恢復：恢復音訊；下一幀以新的 `t_audio` 直接計算生成與位置，**無跳躍**（位置由 `y = spawnY + v*(approachTime - (note.time - t_audio))` 決定）。

### 2.5 效能與資源

* **物件池**：`enableObjectPool=true` 時，Note 與 Lane 皆使用重用機制；`maxActiveNotes` 防止溢出。
* **回收**：音符到達判定線超過 `despawnGrace=150ms` 即回收；或超出畫面下緣立即回收。
* **安全策略**：若解析到 `position` 不在 1..keyCount，忽略並記錄 warning。

### 2.6 介面與架構（建議）

* `KtvGame`：控制 BGM 時軸、生成掃描（持有 beatmap 與 `nextIdx`）。
* `LaneLayout`：根據 keyCount 與視窗大小計算每條 lane 的形狀、中心 X。
* `NoteEntity`：單一音符，持有 `targetTime`, `laneIndex`, `spawnY`, `judgeY`，提供 `update(t_audio)`。
* `NotePool`：音符物件池。
* `KtvGameScene`：全螢幕遊戲頁主組件（Step 22-1 的頁面擴充）。

---

## 3. 驗收標準

* ✅ **時序精度**：任一音符自螢幕出現至抵達判定線之 **耗時 ≈ approachTime**，誤差 < **±1 frame**（以 60fps 為準 ≈ ±16.7ms）。
* ✅ **落軌正確**：`position`=1..keyCount 之音符落在對應軌道中心線；easy=3 軌、hard=5 軌。
* ✅ **暫停/恢復**：暫停 BGM 時，音符停止移動；恢復後音符位置/生成時機與 BGM 對齊，無明顯位移跳躍或漏生。
* ✅ **效能**：同屏 100 顆音符內流暢（>50fps 目標機）；無 memory leak。

---

## 4. 實例化需求測試案例

### 案例 1：時序精度（單顆）

* **Given** `approachTime=1500ms`，beatmap 含 `{time: 10.000, position: 2}`
* **When** 觀察該音符自出現在螢幕到達判定線的時間
* **Then** 實測耗時 1500ms ± 16ms

### 案例 2：多顆連發

* **Given** beatmap 連續 6 顆：`time=[1.0,1.2,1.4,1.6,1.8,2.0]`
* **When** 播放到該區段
* **Then** 以 200ms 間隔生成與到達判定線（相對時序一致），無丟失或重複生成

### 案例 3：落軌驗證（easy/hard）

* **Given** easy(keyCount=3) 與 hard(keyCount=5)
* **When** 測 `position=1..keyCount` 的音符
* **Then** 皆落在對應軌道中心線上，未跨軌

### 案例 4：暫停/恢復

* **Given** 正在播放且場上有 3 顆進行中音符
* **When** 立即暫停 2 秒，再恢復
* **Then** 暫停期間音符靜止；恢復後音符與 BGM 節點對齊，沒有瞬移或延遲累積

### 案例 5：超界資料

* **Given** beatmap 有 `{position: 0}` 或 `{position: 6}`（hard=5）
* **When** 播放
* **Then** 啟用 warning 記錄且該音符不生成（不中斷播放）

### 案例 6：效能與回收

* **Given** 人工產生高密度譜面（同時 120 顆在場）
* **When** 播放
* **Then** 幀率維持 >50fps；離開畫面下緣/超過 grace 時間的音符已回收，活躍數不超 `maxActiveNotes`

---

## 5. 限制與備註

* 本階段不含：判定區間、Hit/Miss 判斷、分數/連擊、輸入處理（下一階段）。
* 音符大小/透明度的進場動效可先省略（僅線性位移與簡單縮放）。
* 時鐘以 **音訊播放時間** 為權威；不要用 `delta` 積分作為主時序避免飄移。
* 若裝置取不到精確的 `audioPosition`，需在下一階段提供補償策略（音訊 anchor + 本地高精度計時器混合）。
