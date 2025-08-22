# 📄 Step 11 規格書（離線彈窗＋翻倍：假廣告）

## 1. 階段目標
- 維持現有邏輯：**回到前台時即刻把離線獎勵入帳**，並彈出彈窗顯示此次離線時間與入帳金額。
- 在彈窗新增「觀看影片翻倍 ×2」按鈕（**假流程 3 秒**），成功後再**加發同額一次**（總計＝原本 ×2）。
- 同一次離線回來 **僅能翻倍一次**；跨下次離線計算時重置。

---

## 2. 功能需求

### 2.1 既有流程（沿用 Step 10／你提供的程式碼）
- 回到前台（`_onResumed()`）時：
  1. 以 **快照速率** 與 **6h 上限** 計算離線秒數與獎勵。
  2. **立即入帳**：`memePoints += reward`。
  3. 清空 `pendingReward`，更新 `lastExitUtcMs`（避免重覆結算）。
  4. 透過 `_onPendingReward?.call(reward, effectiveDuration)` 通知 UI 顯示彈窗（**本階段在彈窗上加「翻倍」**）。

> 保持「即刻入帳」設計；彈窗中的「翻倍」是**額外再加一次 reward**，不是把未入帳獎勵變成兩倍。

### 2.2 新增狀態欄位（持久化，防重覆翻倍）
於 `SecureSaveService` Blob `offline` 節點新增：
```json
{
  "offline": {
    "lastExitUtcMs": 0,
    "idle_rate_snapshot": 0.0,
    "capHours": 6,
    "lastReward": 0.0,          // 本次回前台已入帳的離線獎勵（基數）
    "lastRewardSec": 0.0,        // 本次生效的離線秒數（僅展示）
    "lastRewardAtMs": 0,         // 計算並入帳當下的 UTC ms
    "lastRewardDoubled": false   // 是否已用過翻倍
  }
}
````

* **寫入時機**：在 `_onResumed()` 成功計算並入帳後，立刻寫入上述欄位（`lastReward>0` 時）。
* **重置時機**：下次真正離線再回來且得到新的 `reward` 時，覆寫上述欄位並把 `lastRewardDoubled=false`。

### 2.3 彈窗 UI（擴充）

* 標題：`離線收益`
* 內容：`你離線了 {H:MM:SS}，已入帳 ≈ {reward} 點迷因點數`
* 按鈕：

  * 主按鈕：`知道了`（或 `OK`）→ 關閉彈窗。
  * 次按鈕：`觀看影片翻倍 ×2`（假流程 3 秒）

    * 顯示條件：`offline.lastReward > 0 && offline.lastRewardDoubled == false`
    * 點擊後進入 3 秒 Loading，完成即**再加發 `lastReward`**，並將 `lastRewardDoubled=true`（持久化）。
    * 成功後次按鈕變為不可再點，文案改為 `已翻倍`（或直接隱藏）。

### 2.4 假廣告流程

* 以非阻塞方式顯示 3 秒「播放中…」Loading（允許取消？本階段可不提供）。
* 成功回呼 → 執行加發：
  `memePoints += offline.lastReward; offline.lastRewardDoubled = true;` → 寫檔。
* 失敗（本階段不模擬）→ 無變更。

### 2.5 例外情境

* **沒有離線獎勵**（`lastReward<=0`）：彈窗不顯示或顯示收入為 0 且不顯示翻倍按鈕。
* **重入前台**，同一筆 `lastReward` 重覆顯示彈窗：

  * 允許再次看到彈窗，但若 `lastRewardDoubled=true`，翻倍按鈕應為灰階/隱藏，避免二次加發。
* **跨日或裝備變更**：不影響本次 `lastReward`；翻倍**永遠以 `lastReward` 當基數**，與現在速率無關。

### 2.6 i18n（最少鍵）

於 `assets/lang/{en,zh,jp,ko}.json` 新增：

```json
{
  "offline.ad.double": {"en":"Watch ad to double ×2","zh":"觀看影片翻倍 ×2","jp":"動画視聴で2倍 ×2","ko":"영상 시청으로 2배 ×2"},
  "offline.ad.doubled": {"en":"Doubled","zh":"已翻倍","jp":"2倍済み","ko":"2배 완료"}
}
```

### 2.7 Debug / Telemetry（選配）

* Debug 面板顯示：`lastReward`、`lastRewardSec`、`lastRewardAtMs`、`lastRewardDoubled`。
* 事件（之後接 GA4 可用）：

  * `offline_reward_shown{sec, amount}`
  * `offline_double_click{result:success/fail, amount}`

---

## 3. 驗收標準

* ✅ **入帳即時**：回到前台當下，即使不點任何按鈕，`memePoints` 已增加「離線獎勵」基數。
* ✅ **翻倍 ×2**：在彈窗按下「觀看影片翻倍 ×2」後 3 秒，再次加發**同額**獎勵，總計為最初基數的 2 倍。
* ✅ **僅一次**：同一次離線回來（同一筆 `lastReward`），翻倍按鈕只能成功一次；再次點擊不再加發。
* ✅ **防重進**：關閉彈窗、切頁或短暫背景再回來，同一筆 `lastReward` 不可再翻倍（`lastRewardDoubled=true`）。
* ✅ **0 值行為**：當 `lastReward=0` 或無離線記錄，不顯示翻倍按鈕；不會出現負值或 NaN。

---

## 4. 實例化需求測試案例

### 案例 1：基本翻倍

* **Given** `_onResumed()` 計算 `reward=60` 並已即刻入帳，彈窗顯示「已入帳約 60」
* **When** 點擊「觀看影片翻倍 ×2」並等待 3 秒
* **Then** `memePoints` 再增加 60，總效果＝原本 +60（自動） +60（翻倍）＝120；按鈕狀態改為「已翻倍」

---

### 案例 2：僅能一次

* **Given** 上述案例 1 已完成翻倍
* **When** 再次打開彈窗（重進主頁或回前台）
* **Then** 翻倍按鈕為灰階/隱藏；`memePoints` 不再改變

---

### 案例 3：重入前台不重算

* **Given** `_onResumed()` 產生 `reward=100`，已入帳且 `lastRewardDoubled=false`
* **When** 連續切到背景又回前台（未經歷新一次有效離線）
* **Then** 不會再進行一次新的離線計算；彈窗若顯示仍是同一筆 `lastReward=100`，且翻倍可用狀態維持既有值

---

### 案例 4：0 值與隱藏

* **Given** `reward=0`（或 `snapshot<=0` / `effectiveSeconds<=0`）
* **When** 回前台
* **Then** 不顯示翻倍按鈕；若彈窗顯示則文案為 0，`memePoints` 無變化

---

### 案例 5：資料持久化

* **Given** 完成一次離線入帳（`lastReward=80`、`lastRewardDoubled=false`）
* **When** 關閉 App、立刻重開（尚未產生新離線）
* **Then** 彈窗仍可顯示「已入帳約 80」，翻倍按鈕仍可用；按下翻倍後 `lastRewardDoubled=true` 寫入存檔

---

## 5. 實作說明（基於你提供的程式碼）

### 5.1 `_onResumed()` 內新增記錄欄位

在你現有的「已計算 reward 並入帳」分支，**同時**寫入 `lastReward/lastRewardSec/lastRewardAtMs/lastRewardDoubled=false`，並把這些值帶到 `_onPendingReward` 回呼，供 UI 彈窗顯示與按鈕決策。

**示意（關鍵片段）**：

```dart
final reward = snapshot * effectiveSeconds;

final nowTs = _nowMs();
final updated = gs.copyWith(
  memePoints: gs.memePoints + reward,
  offline: gs.offline.copyWith(
    pendingReward: 0.0,
    lastExitUtcMs: nowTs,
    lastReward: reward,
    lastRewardSec: effectiveSeconds,
    lastRewardAtMs: nowTs,
    lastRewardDoubled: false,
  ),
);
await _persist(updated);

// UI：顯示彈窗（已入帳的金額）
_onPendingReward?.call(
  reward,
  Duration(seconds: effectiveSeconds.floor()),
  canDouble: true, // 由 UI 根據 lastRewardDoubled/金額再次判斷也可
);
```

### 5.2 翻倍入口（UI → 服務）

新增一個服務方法（或在 ViewModel）：

```dart
Future<void> claimOfflineAdDouble() async {
  final gs = _getGameState();
  final r = gs.offline.lastReward;
  if (r <= 0 || gs.offline.lastRewardDoubled == true) return;

  // 假廣告 3 秒
  await Future.delayed(const Duration(seconds: 3));

  final updated = gs.copyWith(
    memePoints: gs.memePoints + r, // 再加發同額一次
    offline: gs.offline.copyWith(lastRewardDoubled: true),
  );
  await _persist(updated);
  _onOfflineDoubled?.call(r); // 回傳剛剛加發的金額，供 UI 動畫/提示
}
```

> **注意**：以 `lastReward` 為唯一基數，與現時速率無關，確保一致與可驗收。

---

## 6. 限制與備註

* 仍以 **UTC** 計算離線秒數；6 小時上限規則不變。
* 「翻倍」本階段為**假廣告**；未來串真實 SDK 僅需替換 3 秒流程與成功/失敗回呼。
* 若玩家在彈窗期間升級裝備，不影響本次 `lastReward` 與翻倍金額。
* 反作弊：翻倍永遠以 `lastReward` 加發一次；即使修改裝置時間也不會影響已計算的本次基數。
* UI/UX 建議：在翻倍成功時顯示 `+{lastReward}` 的彈跳字或特效，以強化正回饋。
