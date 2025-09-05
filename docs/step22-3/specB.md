# 📄 Step 22-3B 規格書（Flame 幾何判定版）

> 目的：用 Flame 的碰撞系統（`CollisionDetection` + `Hitbox`）改寫輸入與命中邏輯。**音符位置**用「音訊時間 → 位置函式」計算（零漂移），**命中判定**用「音符矩形 vs 判定帶矩形」的**空間重疊**：
>
> * PERFECT：音符**完全**落在判定帶內
> * GREAT：音符**部分重疊**判定帶
> * MISS：音符**完全不在**判定帶內（含已通過帶下緣）

---

## 1. 階段目標

* 使用 Flame 元件化：每條軌道一組 `JudgeBand`（判定帶）、多個 `Note`（音符）。
* **音符位置 = f(音訊時間)**（單向函式，不累加 delta），避免 FPS/掉幀造成時間漂移。
* 以**幾何重疊**決定 PERFECT / GREAT / MISS；保留**前排優先**與**多指輸入**。
* Debug Overlay 顯示 `[L#] geom=PERFECT/GREAT/MISS` 與當下交疊比例。

---

## 2. Flame 元件與參數

### 2.1 參數（`assets/config/game.json`）

```json
{
  "ktv": {
    "lanes": { "easy": 3, "hard": 5 },
    "approachMs": 1100,          // 音符從生成點到判定帶中心的飛行時間
    "judgeBand": {
      "heightPx": 64,           // 橘色帶的可視高度（幾何判定以此為準）
      "yPx": 1080               // 帶中心或上緣/下緣的基準（視設計，以下採中心對齊）
    },
    "note": {
      "widthPx": 120,
      "heightPx": 28
    },
    "lateGraceMs": 150,          // 超過帶下緣後的自動 MISS 緩衝時間（防剛好卡線）
    "containmentEpsilonPx": 1.0  // 幾何完全包含時的誤差容忍
  }
}
```

> 若軌道有透視，請用「**y 軸幾何判定**」：只看與判定帶在 **y 向**的重疊；x 只用來決定落在哪一條 lane。

### 2.2 Flame Components

* `JudgeBand extends RectangleComponent with CollisionCallbacks`

  * 位置：固定於各 lane 的判定線（建議用**中心 y** + 高度 `heightPx`）。
  * Hitbox：`RectangleHitbox(isSolid: false, isSensor: true)`（感測器，不推擠）。

* `Note extends RectangleComponent with CollisionCallbacks`

  * 屬性：`laneIndex`、`spawnTimeMs`、`hitTimeMs`（譜面時間）、`isJudged`。
  * Hitbox：`RectangleHitbox()`。
  * **update(positionByAudioTime())**：每幀用音訊時間計算位置（見 3.1）。

* `GameWorld / RhythmScene with HasCollisionDetection, HasTappables & MultiTouch`

  * 提供 lane 區域映射 `x → laneIndex`。
  * 維護**每 lane 的待判隊列**（依 y 或 `hitTimeMs` 排序）。

---

## 3. 位置與時間

### 3.1 音符位置函式（以音訊為權威）

令：

* `t = audioPositionMs()`（音訊播放時間，暫停時不前進）
* `T = hitTimeMs`（音符應命中時間）
* `A = approachMs`
* `yJudgeline`：判定帶中心 y
* `ySpawn`：音符生成起點 y（螢幕上方，負值或 0）

則**位置插值**：

```
progress = clamp01( (t - (T - A)) / A )   // 0→1
y(t) = lerp(ySpawn, yJudgeline, progress)
```

> 這樣不靠逐幀累加 delta，所以**無 FPS 漂移**。x 由 lane 決定（可有透視變形但不影響 y 判定）。

---

## 4. 幾何判定與輸入

### 4.1 幾何定義（以 y 為主）

* `bandTop = yJudgeline - bandHeight/2`
* `bandBottom = yJudgeline + bandHeight/2`
* `noteTop = note.y - note.height/2`
* `noteBottom = note.y + note.height/2`

**分類：**

* **PERFECT（完全包含）**
  `noteTop >= bandTop - eps && noteBottom <= bandBottom + eps`
* **GREAT（部分重疊但非完全包含）**
  `noteBottom > bandTop && noteTop < bandBottom` 且**不滿足 PERFECT**
* **MISS（完全不重疊）**
  `noteBottom <= bandTop || noteTop >= bandBottom`

> `eps = containmentEpsilonPx`：避免像素捨入或縮放誤差。

### 4.2 前排優先（同一軌）

* 維護每 lane 的**待判隊列**（依 **y 接近判定帶**或 `hitTimeMs` 升序）。
* 取**隊首**音符 `note0` 作為唯一候選；輸入僅檢查 `note0` 的幾何關係。
* 命中／MISS 後 `note0.isJudged = true` 並出隊。

### 4.3 多指與輸入時機

* 採 Flame 的 `MultiTap` / `onTapDown(pointerId, info)`（或手勢Overlay）。
* **Down 觸發**：

  1. 由 `info.eventPosition.widget.x` 映射 `laneIndex`
  2. 取該 lane 的 `note0`，用**當下幾何**分類（4.1）
  3. 回報 `geomJudge=PERFECT/GREAT/MISS`，疊加 Log/浮字
* 若該 lane 無 `note0` → **忽略輸入**（防幽靈點）。

### 4.4 自動 MISS（逾時回收）

* 若 `t > T + lateGraceMs` 或 `noteTop > bandBottom + margin`（音符完全穿過帶下緣），
  將 `note0` 設為 `MISS` 並出隊，觸發回收動畫。

### 4.5 碰撞回呼（可選的輔助）

* 也可讓 Note 與 Band 都掛 `RectangleHitbox` 並監聽 `onCollisionStart/End`：

  * `onCollisionStart` → 記錄「開始重疊」時間與覆蓋比例（debug）
  * `onCollisionEnd` → 若期間未被擊中，且結束於下緣 → 自動 MISS
* **實際判定**仍在**輸入當下**做 4.1 幾何檢查，避免單靠碰撞事件帶來的時序不確定。

---

## 5. 安全與邊界

* **單次判定**：`note.isJudged` 防重入。
* **同幀多點同軌**：第一個點處理後出隊，其餘點會拿到新的隊首，自然防抖。
* **暫停一致**：暫停時 `audioPositionMs` 不前進 → `y(t)`靜止，輸入無效（可直接忽略 onTap）。
* **透視/非線性軌道**：只要 `y(t)` 是**音訊時間的單調函式**，幾何判定即成立。
* **長音（Hold）**（預留）：以長條 note 與 band 重疊長度百分比 + 按住時間檢查；本階段先不做。

---

## 6. 驗收標準

* ✅ **幀率獨立**：把渲染降到 20–30 FPS，命中結果不變（位置來自音訊時間）。
* ✅ **幾何一致**：當畫面上音符「完全在帶內」時點擊，**100% 得到 PERFECT**；僅部分重疊必為 **GREAT**；完全外部必為 **MISS**。
* ✅ **前排優先**：同軌雙 note（相隔 150ms），在第二顆到線時狂點，只會先判第一顆。
* ✅ **多指同擊**：不同軌同時點擊，互不影響。
* ✅ **逾時 MISS**：音符穿過帶下緣且超過 `lateGraceMs` 未擊中，會自動 MISS 並回收。
* ✅ **Debug Overlay** 顯示：`[L2] overlap=1.00 PERFECT` / `0.42 GREAT` / `0.00 MISS`。

---

## 7. 測試案例（幾何版）

1. **完全包含 → PERFECT**

* 給 `bandHeight=64, noteHeight=28`；使 `noteTop >= bandTop+1` 且 `noteBottom <= bandBottom-1`
* 點擊 → `PERFECT`

2. **部分重疊 → GREAT**

* 讓 `noteBottom = bandTop + 10` 且 `noteTop < bandTop`
* 點擊 → `GREAT`

3. **完全外部 → MISS**

* 讓 `noteBottom <= bandTop`（在帶上方）或 `noteTop >= bandBottom`（在帶下方）
* 點擊 → `MISS`

4. **自動 MISS**

* 不點擊，推進 `t ≥ T + lateGraceMs` 或 note 明顯在帶下方
* → 自動 MISS

5. **前排優先**

* 同軌兩顆：`T1=5000ms, T2=5150ms`；在 5150 附近連點
* 先對 `note(T1)` 出判定，再輪到 `note(T2)`

6. **幀率變動**

* 模擬 20FPS 與 60FPS，各點同一幀畫面位置
* 判定一致

---

## 8. 風險與對策

* **風險：音訊回報抖動** → 導致 y(t) 微跳

  * 對策：對 `audioPositionMs()`做輕微平滑或取平台提供的高精度 position；但**嚴禁**用幀累加代替音訊時間。
* **風險：像素捨入導致「剛好卡線」**

  * 對策：`containmentEpsilonPx` 容忍 1px；UI 上建議把判定帶設計略厚於視覺描邊。
* **風險：碰撞回呼時序不穩**

  * 對策：**以輸入當下的幾何檢查為主**，碰撞事件僅做輔助（顯示/自動 MISS）。

---

## 9. 介面草稿（僅示意）

```dart
class JudgeBand extends RectangleComponent with CollisionCallbacks {
  final int laneIndex;
  JudgeBand(this.laneIndex, {required super.position, required super.size}) {
    add(RectangleHitbox(isSolid: false)..collisionType = CollisionType.passive);
  }
}

class Note extends RectangleComponent with CollisionCallbacks {
  final int laneIndex;
  final double hitTimeMs;
  bool isJudged = false;

  @override
  void update(double dt) {
    final t = audioPositionMs();
    final progress = ((t - (hitTimeMs - approachMs)) / approachMs).clamp(0, 1);
    final y = lerpDouble(ySpawn, yJudge, progress)!;
    position.y = y; // x 由 lane 定義或透視座標函式給定
  }
}

JudgeResult judgeByGeometry(Note n, Rect band, double eps) {
  final noteRect = n.toRect(); // 或用 n.position/size 自算
  if (band.containsRect(noteRect, eps)) return JudgeResult.perfect;
  if (noteRect.overlaps(band)) return JudgeResult.great;
  return JudgeResult.miss;
}
```

> `containsRect` 可自寫：`noteTop >= bandTop-eps && noteBottom <= bandBottom+eps`。
