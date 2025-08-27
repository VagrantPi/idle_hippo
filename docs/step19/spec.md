# 📄 Step 19 規格書（抽卡廣告加抽規則・新版）

## 1. 階段目標
- **單抽**：每次單抽結束後，顯示「觀看影片再抽 1 次」按鈕；觀看成功後 **立即再進行 1 次單抽並再扣 1 張抽獎券**。此規則**不限次數**（只要玩家還有券）。
- **十一連抽**（十連消耗 10 張、實際抽 11 次）：每次十一連抽結束後，顯示「觀看影片再十一連一次（仍送 1 抽）」按鈕；觀看成功後 **再執行 1 次十一連抽並再扣 10 張抽獎券**。此規則**每日僅 1 次**。
- 實作「十一連廣告加抽」**日計次**（Asia/Taipei）與跨日自動重置。
- 兼容 Step 17 的抽卡演出、紀錄與碎片/升級流程（Step 18）。

---

## 2. 功能需求

### 2.1 介面調整（抽卡 Tab）
- 抽卡結算畫面新增底部區塊：
  - **單抽結算**：`[觀看影片再抽 1 次]`（3s 假廣告流程）
  - **十一連結算**：`[觀看影片再十一連一次（仍送 1 抽）]`（3s 假廣告流程）
- 按鈕啟用條件：
  - 單抽：玩家 `petTickets >= 1` → 啟用，否則灰階（顯示「券不足」提示）。
  - 十一連：玩家 `petTickets >= 10` **且** 本日 `tenPackAdRemaining > 0` → 啟用；否則灰階並顯示剩餘次數（0/1）。

### 2.2 規則與扣券
- **單抽**流程：
  1. 玩家執行單抽（消耗 1 券）→ 顯示結果。
  2. 顯示「再抽 1 次」按鈕：
     - 點擊進入 3s 假廣告 → 成功後再次 **執行單抽並再扣 1 券**。
     - 再次結算後，仍會顯示「再抽 1 次」按鈕；只要券足夠，**可無限循環**。
  3. 任一次券不足 → 按鈕灰階，不再觸發。
- **十一連**流程：
  1. 玩家執行十一連（消耗 10 券，抽 11 次）→ 顯示結果列表。
  2. 若 `tenPackAdRemaining > 0` 且 `petTickets >= 10`：
     - 顯示「再十一連一次」按鈕 → 3s 假廣告 → 成功後 **再執行一次十一連並再扣 10 券**。
     - 完成後 `tenPackAdRemaining -= 1`（當日歸 0）。
  3. 若 `tenPackAdRemaining == 0` 或 `petTickets < 10` → 按鈕灰階。
- 兩者皆需寫抽卡紀錄（Step 17 格式），碎片/升級點數累積照舊（Step 18）。

### 2.3 日計次與跨日重置（Asia/Taipei）
- 新增每日計次欄位：`gacha.tenPackAdRemaining`，**每日預設 1**。
- 於以下時機檢查跨日：
  - 進入抽卡頁、抽卡成功後、開啟 App/回前台。
- 以 Asia/Taipei 當日字串 `YYYY-MM-DD` 比對：
  - 若 `lastDate != today` → `tenPackAdRemaining = 1`，更新 `lastDate = today`。

### 2.4 例外/邊界行為
- 假廣告流程失敗（本階段不模擬失敗，皆視為成功）。
- 廣告開始到扣券之間若券不足（競態）：
  - 進入抽卡前再次校驗券數；不足則彈錯誤提示，不執行抽卡，不扣日計次。
- 十一連的「再十一連一次」**不疊加多次**：即便玩家再做新的十一連，只要本日次數已用完，即不可再用。
- 單抽的「再抽 1 次」**不設次數上限**，但每次都必須再扣 1 券；不產生免費抽。

### 2.5 i18n（最少鍵）
```json
{
  "gacha.ad.single.title": {"en":"Watch to draw 1 more","zh":"觀看影片再抽 1 次","jp":"動画視聴でもう1回","ko":"영상 시청으로 1회 더"},
  "gacha.ad.ten.title": {"en":"Watch to draw 11 more","zh":"觀看影片再十一連一次","jp":"動画視聴でもう11連","ko":"영상 시청으로 11연차 추가"},
  "gacha.ad.need_ticket": {"en":"Not enough tickets","zh":"抽獎券不足","jp":"チケットが不足しています","ko":"티켓이 부족합니다"},
  "gacha.ad.ten.daily_used": {"en":"Today's bonus used","zh":"今日加抽已用完","jp":"本日のボーナス使用済み","ko":"오늘 보너스 소진"},
  "gacha.ad.ten.remain": {"en":"Bonus 11-pull left: {n}","zh":"加抽 11 連剩餘：{n}","jp":"ボーナス11連 残り：{n}","ko":"보너스 11연 남음: {n}"}
}
````

---

## 3. 資料結構（存檔）

```json
{
  "gacha": {
    "lastDate": "2025-08-24",        // Asia/Taipei 日期
    "tenPackAdRemaining": 1          // 每日 1 次；跨日重置
  },
  "petTickets": 37,                   // 現有抽獎券
  "gachaHistory": [ /* 近 20 筆，沿用 Step 17 */ ]
}
```

> 備註：單抽的廣告加抽**不需要**計次欄位；僅依券數決定是否可再抽。

---

## 4. 事件流（偽程式）

### 4.1 單抽 → 廣告再抽

```
onSingleDrawPressed():
  require petTickets >= 1
  consume(1)
  results = doSingleRoll()
  showResult(results)
  showButton(adSingle)

onAdSinglePressed():
  if petTickets < 1: toast("券不足"); return
  await fakeAd(3s)
  consume(1)
  results = doSingleRoll()
  appendResult(results) // 或重新顯示
  // 再次顯示 adSingle 按鈕（若仍有券）
```

### 4.2 十一連 → 廣告再十一連（每日 1 次）

```
onTenPlusOneDrawPressed():
  require petTickets >= 10
  consume(10)
  results = do11Rolls()
  showResultList(results)
  showButton(adTen, enabled = (tenPackAdRemaining>0 && petTickets>=10))

onAdTenPressed():
  if tenPackAdRemaining <= 0: toast("今日加抽已用完"); return
  if petTickets < 10: toast("券不足"); return
  await fakeAd(3s)
  consume(10)
  results = do11Rolls()
  appendResultList(results)
  tenPackAdRemaining -= 1
  persist()
```

---

## 5. 驗收標準

* ✅ **單抽循環**：單抽後可按「觀看影片再抽 1 次」，成功後再次單抽並扣 1 券；只要券夠即可重複。
* ✅ **再單抽仍可再抽**：第二次單抽結束仍可按「再抽 1 次」，再次扣 1 券並抽出結果。
* ✅ **十一連限 1 次**：同一日內，十一連結算後，僅能成功觸發 **1 次**廣告加抽；第二次十一連的結算畫面顯示為不可用/提示已用完。
* ✅ **跨日重置**：Asia/Taipei 跨至新日期後，`tenPackAdRemaining` 回復為 1；新的十一連可再使用一次廣告加抽。
* ✅ **扣券正確**：每次單抽/再抽扣 1 張；每次十一連/再十一連扣 10 張；不足時不得執行。
* ✅ **紀錄/碎片**：所有抽卡結果正確寫入紀錄，重複角色同稀有度轉碎片並可用於升級（承接 Step 17–18）。

---

## 6. 測試案例

### 案例 1：單抽無限循環（受券量限制）

* **Given** `petTickets=5`
* **When** 單抽 → 廣告再抽 → 廣告再抽 → … 直到券用盡
* **Then** 每次進行前都扣 1 券；剩餘券為 0 時按鈕灰階，不再觸發

### 案例 2：十一連每日一次

* **Given** `petTickets=25`, `tenPackAdRemaining=1`
* **When** 十一連 → 看廣告再十一連
* **Then** 共扣 20 券，`tenPackAdRemaining=0`；再次十一連後，結算畫面顯示「今日加抽已用完」

### 案例 3：跨日重置

* **Given** 今天已用完 `tenPackAdRemaining=0`
* **When** Asia/Taipei 跨日，重新進入抽卡頁
* **Then** `tenPackAdRemaining` 自動重置為 1；新的一次十一連可使用加抽

### 案例 4：競態校驗（券不足）

* **Given** 十一連結算顯示加抽可用，玩家在另一處消耗券導致 `petTickets=7`
* **When** 點「再十一連一次」
* **Then** 二次校驗失敗，提示「券不足」，不扣日計次，不進行抽卡

### 案例 5：紀錄與碎片一致性

* **Given** 單抽 + 再抽各 1 次
* **When** 檢查 gachaHistory 與碎片/升級計數
* **Then** 紀錄新增 2 筆；若重複角色同稀有度，碎片 +2

---

## 7. 限制與備註

* 本階段仍使用 **3 秒假廣告**，未串正式廣告 SDK；未來接入時保持相同成功/失敗回呼即可。
* 「十一連」此處沿用 Step 17 的十連送 1 抽（總 11 次）；加抽亦同（再 11 次）。
* 單抽加抽**沒有**每日上限，但每次必須扣券；不提供免費抽。
* 跨日邏輯與 Step 6/13 的 Asia/Taipei 時區一致，但本計次欄位獨立管理。
* UI 提示需即時反映可用狀態（券不足 / 今日加抽已用完），避免誤觸。
