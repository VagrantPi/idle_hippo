# 📄 Step 24 規格書（Loading 畫面＋歌曲清單 SWR/ETag/Isolate 更新＋封面遠端快取）

---

## 1. 階段目標
- 新增 **Loading 頁**（背景圖＋Loading 動畫）。
- **存檔擴充**：`collect_version`（初始 0）、`collect_etag`、`collect_updated_at`。
- 啟動流程採 **SWR（Stale-While-Revalidate）**：
  - **第一次安裝開啟**：不使用 Isolate，Loading 頁同步檢查與更新 `collect.json`，完成後才進主畫面。
  - **非第一次開啟**：立即載入本地 `collect.json`，允許直接進主畫面；背景啟動 **Isolate** 檢查更新。
- **新增開啟檢查**：每次開啟 App 都會在 Loading 流程檢查是否有離線獎勵（離線收益系統 Step 10/11），若有則提示並立即入帳。
- SWR 細節：
  - 請求帶 `If-None-Match` → 304 不更新，200 覆寫並更新 etag/version。
  - 網路失敗/JSON 壞檔：最多重試 3 次（退避 1s/2s/3s），仍失敗則保留舊檔。
- 音樂遊戲入口：未下載音源且無網路/下載失敗 → 友善錯誤，不進入遊戲場景。

—

【變更】遠端版本檢查與封面圖片快取：
- 遠端 `collect.json` 的 `songs[].image` 由資產路徑改為遠端 URL（png/jpg/webp 皆可）。
- 新增 `version.json`（只含 `version` 數字）：
  - URL：`https://raw.githubusercontent.com/VagrantPi/idle_hippo_music_resource/refs/heads/main/version.json`
  - 啟動或背景更新時，先請求此檔；若 `version` ≤ 本地 `collectVersion` → 視為最新不下載；若 `version` > 本地 → 下載 `collect.json`。
- `collect.json` URL：
  - `https://raw.githubusercontent.com/VagrantPi/idle_hippo_music_resource/refs/heads/main/collect.json`
- 比對與下載規則：
  - 下載 `collect.json` 後，若 JSON 內含 `version`，`collectVersion` 以該值（或 `version.json` 的值）覆寫，不使用 `+1`，避免重複下載。
  - 解析新 `collect.json` 後，對於每筆歌曲：
    - 以 `id` 檢查本地快取是否已有封面（`appdata://images/{id}.{ext}`）。
    - 若不存在 → 下載 `image` URL 到 `appdata://images/`，檔名為 `id`、沿用副檔名。
    - 若已存在 → 不重複下載。
- 首次開啟：在 Loading 階段同步完成上述更新與圖片下載。
- 非首次開啟：主畫面快速進場；SWR/ETag/Isolate 在背景下載，圖片快取亦在背景處理。

---

## 2. 功能需求

### 2.1 UI/UX
- **Loading 頁**：
  - 背景：`assets/images/background/Loading.png`
  - 下方文字：「Loading…」＋動態特效
  - 顯示時間：至少 1 秒（避免瞬閃）
- **提示文案**（多語系）：
  - `Checking updates…`、`Updating songs…`、`Retry in {sec}s` 等
- 完成檢查後自動進入主畫面

### 2.2 資料結構
```json
{
  "karaoke": {
    "collectVersion": 0,
    "collectEtag": "",
    "collectUpdatedAt": 0,
    "collectPath": "appdata://collect.json"
  }
}
````

### 2.3 SWR + ETag + Isolate 流程

1. 啟動 App → 顯示 Loading 畫面（至少 1s）。
2. 檢查並入帳離線獎勵。
3. **第一次開啟**：同步檢查並更新 `collect.json`（完成後才進主畫面）。
4. **非第一次開啟**：

   * 載入本地 `collect.json`（若無則用 asset 預設）。
   * 顯示 Loading 1s 後導向主畫面。
   * 背景以 **Isolate** 發送帶 ETag 的請求檢查更新：

     * 304 → 保持不變。
     * 200 → 驗證 JSON → 成功後原子覆寫檔案 → 更新 `etag/version`。
       * 若 JSON 含 `version` 欄位：以其值覆寫 `collectVersion`；否則維持 `+1` 策略。
       * 完成覆寫後針對 `songs`：
         * 若 `appdata://images/{id}.{ext}` 不存在 → 下載 `image` URL 並原子寫入快取。
         * 若已存在 → 略過。
     * 失敗 → 重試 3 次（1s, 2s, 3s），最終仍失敗則保留舊檔。

### 2.4 音樂遊戲入口保護

* 若未下載音源且無網路 → 顯示「網路不可用」錯誤，阻止進場。
* 若下載失敗 → 顯示「下載失敗」錯誤，阻止進場。
* 試聽僅在音源已下載情況下播放前 10 秒。

---

## 3. 驗收標準

* ✅ **第一次開啟**：Loading 頁完整跑檢查，更新完成後才進入主畫面。
* ✅ **非第一次開啟**：Loading 1s 後立即進主畫面，更新在背景進行。
* ✅ **離線獎勵檢查**：啟動時如有離線收益，能正確提示並入帳。
* ✅ **ETag 命中**：伺服器回 304 → 不覆寫本地檔；不改 `collectVersion`。
* ✅ **更新成功**：伺服器回 200 → 通過驗證並原子覆寫；`collectEtag` 與 `collectVersion` 更新（含 `version` 時以其為準）。
* ✅ **重試機制**：模擬前兩次失敗、第三次成功，正確退避 1s/2s/3s。
* ✅ **壞檔防護**：下載成功但 JSON 不合法 → 不覆寫舊檔，App 正常啟動。
* ✅ **非阻塞啟動**：除首次開啟外，無論成功或失敗，Loading 都會在 1s 後跳主畫面。
* ✅ **入口保護**：無網路或音源下載失敗時，音樂遊戲正確攔截並顯示錯誤。
* ✅ **封面快取**：首次或版本更新時，新歌曲封面會自動下載並快取；既有歌曲不重複下載。

---

## 4. 實例化需求測試案例

### 測試案例 1：首次開啟

* **Given** 全新安裝（`collectVersion=0`）
* **When** 開啟 App
* **Then** Loading 頁持續顯示並同步檢查更新，完成後才進入主畫面

### 測試案例 2：非首次開啟

* **Given** 本地已有 `collect.json`
* **When** 開啟 App
* **Then** Loading 顯示 1s 後直接進入主畫面，背景執行 Isolate 更新

### 測試案例 3：離線獎勵

* **Given** 上次關閉距今 2 小時，應有離線收益
* **When** 開啟 App
* **Then** Loading 頁期間提示「離線收益：X」，並自動將收益入帳

### 測試案例 4：ETag 304

* **Given** 本地 etag="abc"
* **When** 遠端回應 304
* **Then** 不更新檔案，仍使用現有版本

### 測試案例 5：ETag 200

* **Given** 本地 etag="abc"
* **When** 遠端回應 200 並提供新 etag="def"
* **Then** JSON 驗證通過，原子覆寫，`collectEtag=def`，`collectVersion+=1`

### 測試案例 6：三次失敗

* **Given** 網路不穩
* **When** 連續失敗三次
* **Then** 保留舊檔，進入主畫面

### 測試案例 7：音樂遊戲入口錯誤攔截

* **Given** 未下載音源且無網路
* **When** 點擊進入遊戲
* **Then** 彈出「網路不可用」錯誤，無法進入遊戲

### 測試案例 8：封面圖片快取（首次 / 更新）

* **Given** 本地不存在 `images/{id}.png`
* **When** 遠端返回 200 並且 `version` 提升，且 `image` 為 http(s) URL
* **Then** 下載該封面存入 `appdata://images/{id}.ext`；下次開啟不再下載
