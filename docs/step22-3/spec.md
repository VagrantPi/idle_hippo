# 📄 Step 22-3 規格書（輸入與判定窗）

> 承接 Step 22-2：已有軌道與音符移動。本階段加入 **多指輸入、判定窗（PERFECT/GREAT/MISS）** 與「前排優先」判定規則。先以 **Log/Debug Overlay** 顯示判定結果，不做分數與連擊（下一步）。

---

## 1. 階段目標
- 每條軌道有對應觸控區，支援 **multi-touch**（多軌同時擊）。
- 以 **音訊時軸**（audio position）為權威時間，進行命中判定。
- 可參數化判定窗（預設）：PERFECT ±40ms、GREAT ±90ms（且 >±40ms）、MISS：>±90ms 或逾時未擊中。
- **前排優先**：同一軌僅可對「**最接近判定線且尚未被判定**」的音符做判定（避免後排搶拍）。
- 命中後以 **Log/Debug UI** 顯示：`[lane=#][Δms=+12] PERFECT` 等。

---

## 2. 功能需求

### 2.1 參數（`assets/config/game.json`）
```json
{
  "ktv": {
    "judge": {
      "perfectMs": 40,
      "greatMs": 90,
      "lateGraceMs": 120,      // 逾時 MISS 回收前的最長等待（避免剛好卡在線上）
    }
  }
}
```

### 2.2 觸控區域（Touch Lanes）

* 依當前 **keyCount**（3/5）將判定線（judgeline 位置）水平切成等寬區域作為 **觸控熱區**。
* 觸控事件：

  * **Down/Up** 皆視為「擊鍵」觸發（擇一即可，預設 Down）。
  * 取得事件座標 `(x,y)` → 映射為 `laneIndex`（1..keyCount）。
  * 同幀多指：**逐指**各自映射 lane，允許同時多軌命中。
* 開發期顯示**橘色判定帶**（judgeline±greatMs 對應的垂直可視區，便於校準）。

### 2.3 音訊時間源

* 每幀讀取 `t_audio = audioPositionSec()*1000`（ms）。
* 暫停時 `t_audio` 不前進；恢復時與音符時序對齊（沿用 Step 22-2 策略）。

### 2.4 前排優先的音符選取

* 對應軌道維護一個 **待判隊列**（已生成、尚未判定、尚未逾時回收的音符）。
* 每次擊鍵於該軌 **只檢查隊首音符** `note0`（時間最早）。

  * 若 `abs(t_audio - note0.timeMs) <= greatMs` → 命中（再細分 PERFECT/GREAT）。
  * 否則若 `t_audio < note0.timeMs - greatMs` → 時間尚早，**不判定**（忽略輸入，不影響後排）。
  * 否則（過晚且 >greatMs）→ MISS 該音符（立即判定 MISS）。
* 命中或 MISS 後，標記 `note0` 為已判定並出隊（回收或進下一階段）。

### 2.5 判定規則

* 定義 `Δ = t_audio - note0.timeMs`（ms，提前為負、延後為正）：

  * `|Δ| <= perfectMs` → **PERFECT**
  * `perfectMs < |Δ| <= greatMs` → **GREAT**
  * `|Δ| > greatMs` → **MISS**
* **逾時 MISS**（未擊中）：當 `t_audio - note0.timeMs > lateGraceMs`，自動將 note0 判為 MISS 並出隊。
* 顯示（Log 或 Overlay）：

  * 例：`[L2] Δ=+18ms PERFECT`、`[L5] Δ=-65ms GREAT`、`[L1] Δ=+131ms MISS(too late)`

### 2.6 安全與邊界

* 同一音符**只可被判定一次**（命中或 MISS 後標記、回收）。
* 防止**幽靈點擊**：若該軌道當前隊列為空，輸入直接忽略。
* 當幀多次擊鍵打在同一軌道：

  * 僅第一個擊鍵對當前隊首生效；其餘因隊列已變化需再取新隊首重新計算（自然防抖）。
* FPS 波動不影響判定：判定基於 `t_audio`，與幀率解耦。

---

## 3. 驗收標準

* ✅ **時間精度**（自動測試/QA 工具注入）：

  * 於 `time±20ms` 輸入 ⇒ 判定 **PERFECT**
  * 於 `time±70ms` 輸入 ⇒ 判定 **GREAT**
  * 於 `time±120ms` 輸入 ⇒ 判定 **MISS**
* ✅ **前排優先**：同一軌道快速連點，不會擊中後排音符；始終只對「最早未判定」音符做判定。
* ✅ **暫停一致**：暫停時任何輸入不會使音符前進；恢復後再依 `t_audio` 正確判定。
* ✅ **多指同時**：兩條以上軌道於同一時刻輸入，均可獨立命中其各自前排音符。
* ✅ **逾時 MISS**：超過 `lateGraceMs` 未擊中之音符自動 MISS 並回收。

---

## 4. 實例化需求測試案例

### 案例 1：PERFECT/GREAT/MISS 規則

* **Given** 一顆音符 `t=10,000ms`（L2）
* **When** 於 9,980ms/10,020ms 點擊
* **Then** Log 顯示 `PERFECT`；Δ≈±20ms
* **When** 於 9,930ms/10,070ms 點擊
* **Then** Log 顯示 `GREAT`；Δ≈±70ms
* **When** 於 9,880ms/10,120ms 點擊
* **Then** Log 顯示 `MISS`

### 案例 2：前排優先防搶拍

* **Given** 同一軌 L3 有兩顆音符 t1=5000ms、t2=5200ms
* **When** 在 \~5200ms 連點兩下
* **Then** 第一擊作用於 t1（判定 MISS 或 GREAT 依時間），第二擊才輪到 t2；**不會**先命中 t2

### 案例 3：過早輸入忽略

* **Given** L1 隊首音符 t=8000ms
* **When** 在 7800ms（早於 greatMs 界外）連點
* **Then** 無任何判定產生（Log 不輸出），不影響後續正常命中

### 案例 4：逾時 MISS 自動回收

* **Given** L5 音符 t=6000ms，未輸入
* **When** 時間到 6140ms（lateGraceMs=120）
* **Then** 自動判定 MISS 並從隊列回收

### 案例 5：暫停恢復

* **Given** 正在接近判定，`t_audio=9500ms` 時暫停 2 秒後恢復
* **Then** 期間音符不移動且不產生判定；恢復後以新的 `t_audio` 正確計算 Δ 與判定

### 案例 6：多指同擊

* **Given** L1/L4 各有音符同時到線
* **When** 兩指同時分別點在 L1 與 L4
* **Then** 各自產生判定（PERFECT/GREAT），互不干擾
