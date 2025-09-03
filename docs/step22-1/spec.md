# 📄 Step 22-1 規格書（河馬卡拉 OK：歌曲清單與下載播放）

> 本階段 **不實作節奏/判定/計分**。目標：建出「歌曲清單 → 難度選擇 → 進入**全螢幕遊戲頁**並播放音樂」的流程；歌曲首次需下載並快取，之後離線可播。

---

## 1. 階段目標
- 從 `assets/audio/collect.json` 載入歌曲清單與難度資訊（easy/hard）。
- 歌曲卡顯示：封面、名稱、長度、兩種難度與各自星數（滿分 5）。
- 首次點選難度時 **下載 MP3** 並顯示下載動畫+進度條；完成後**轉場到全螢幕頁**並開始播放。
- 後續再玩同曲同難度 **不需下載**（使用本機快取）。
- 進入全螢幕頁即播放音樂（無需出現打擊物件與 UI，單純播放）。

---

## 2. 功能需求

### 2.1 資料載入
- 檔案：`assets/audio/collect.json`
- 結構（僅取用以下欄位；beatmap 本階段可忽略但需能解析保留）：
  - `songs[].id`（唯一鍵）
  - `songs[].title`
  - `songs[].image`（封面）
  - `songs[].music`（MP3 下載 URL）
  - `songs[].length_seconds`
  - `songs[].difficulties[].level`：`"easy" | "hard"`
  - `songs[].difficulties[].key_count`：顯示為星數（上限 5）
- 資料異常（JSON 缺欄/空陣列）時，顯示空清單狀態與重試按鈕。

### 2.2 UI/UX：歌曲清單頁
- 每首歌以卡片呈現：左封面、右側資訊區。
- 顯示：
  - 標題（多語鍵允許覆寫，無則用原字串）
  - 長度（mm:ss）
  - 難度選項：**Easy** / **Hard**，各自後方顯示星數（`min(key_count, 5)` 顆）。
- 點選任一難度 → 進入**下載模態**（若未下載）或直接**轉場**（已下載）。

### 2.3 下載與快取
- 檔案命名：`{id}.mp3`（每首歌共用一份音檔，難度共用）
- 儲存位置：App 私有目錄（如 `appDir/audio/{id}.mp3`）
- 下載模態：
  - 顯示封面、歌名、目前難度標籤（僅作提示，不影響檔案）
  - **進度條（0~100%）** 與數字百分比
  - 取消按鈕（取消則回到清單，不建立破損檔）
- 斷線/失敗：
  - 顯示錯誤提示與「重試」按鈕；重試會重新請求。
- 完成下載：
  - 轉場動畫（0.3~0.5s）→ 進入全螢幕頁。

### 2.4 全螢幕「遊戲」頁（本階段僅播放）
- 內容：**全版背景（可用純色或封面模糊）**、置中顯示歌名與難度標籤、**立即播放音樂**。
- 自動播放規則：
  - 進入頁面後，若本機檔案就緒，**立即播放**；
  - 音量遵從全域設定（若有）。
- 基本控制：
  - 右上角：返回按鈕（停止播放→返回清單）
  - 暫停/恢復（可選；若不做控制，保持自動播放到結束）
- 結束處理：
  - 播畢自動停止，顯示「播放完成」狀態（不離開頁）。

### 2.5 狀態管理與多語
- 快取狀態：以檔案存在與可讀性為準；若檔案損毀則重新下載。
- i18n 最少鍵：
```json
{
  "ktv.title": {"zh":"河馬卡拉OK","en":"Hippo Karaoke"},
  "ktv.length": {"zh":"長度","en":"Length"},
  "ktv.easy": {"zh":"簡單","en":"Easy"},
  "ktv.hard": {"zh":"困難","en":"Hard"},
  "ktv.stars": {"zh":"星","en":"★"},
  "ktv.download.title": {"zh":"下載歌曲","en":"Downloading Song"},
  "ktv.download.progress": {"zh":"下載中","en":"Downloading"},
  "ktv.download.retry": {"zh":"重試","en":"Retry"},
  "ktv.download.cancel": {"zh":"取消","en":"Cancel"},
  "ktv.playing.now": {"zh":"正在播放","en":"Now Playing"},
  "ktv.done": {"zh":"播放完成","en":"Finished"}
}
````

### 2.6 Telemetry（預留至 Step 33）

* `karaoke_song_list_loaded {count}`
* `karaoke_download_start {songId}`
* `karaoke_download_complete {songId, bytes}`
* `karaoke_download_error {songId, code}`
* `karaoke_enter_fullscreen {songId, level}`
* `karaoke_play_start {songId, level}`
* `karaoke_play_end {songId, level, reason: ended|back }`

---

## 3. 驗收標準

* ✅ 清單頁歌曲數量、資訊（封面/名稱/長度/兩難度星數）與 `collect.json` 一致。
* ✅ 首次點選任一難度 → 出現下載模態並顯示實時進度；完成後自動轉場至**全螢幕頁**並**立即播放**。
* ✅ 同首歌在已下載後，再次點選任一難度 → **不顯示下載**、直接轉場播放。
* ✅ 下載中取消 → 不建立損毀檔；回到清單可再次嘗試。
* ✅ 下載失敗顯示錯誤並可重試；重試成功後能正常播放。
* ✅ 返回清單時，播放停止、資源釋放，不殘留聲音。

---

## 4. 實例化需求測試案例

### 案例 1：清單載入

* **Given** `collect.json` 含 1 首歌
* **When** 開啟卡拉 OK 清單頁
* **Then** 顯示 1 張卡；標題「Echoes Of The Void」、長度 02:00；easy 3 星、hard 5 星

### 案例 2：首次下載播放

* **Given** 本機無 `EchoesOfTheVoid.mp3`
* **When** 點選「Easy」
* **Then** 顯示下載模態並出現進度；完成後轉場至全螢幕頁；音樂自動開始播放

### 案例 3：二次播放免下載

* **Given** 本機已有 `EchoesOfTheVoid.mp3`
* **When** 點選「Hard」
* **Then** 直接轉場至全螢幕頁並立即開始播放（無下載流程）

### 案例 4：下載取消

* **Given** 正在下載歌曲
* **When** 按下「取消」
* **Then** 回到清單頁、不建立半成品檔案；再次點選可重新下載

### 案例 5：下載失敗重試

* **Given** 網路異常導致下載失敗
* **When** 顯示錯誤後按「重試」且網路恢復
* **Then** 成功下載並可播放

### 案例 6：返回釋放

* **Given** 正在全螢幕頁播放
* **When** 按返回
* **Then** 音樂停止、釋放播放器資源，返回清單無殘留聲音

---

## 5. 限制與備註

* 本階段**不實作**節奏物件、判定、分數與日次數限制；僅建立**清單 → 下載 → 播放**骨架。
* 單曲多難度 **共用同一音檔**；beatmap 於後續步驟讀取。
* 下載時顯示百分比須使用分段回報（支援 HEAD/Content-Length；若無法獲取長度，改成不定長動畫與已下載 KB 顯示）。
* 若檔案校驗需要，後續可於 JSON 增加 `checksum`，本階段先不強制。
