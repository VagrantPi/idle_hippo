# 階段 27-6｜啟動時補發（Crash-safe）

## 目標

當 App 因崩潰/關閉導致流程沒走完，重啟時能檢查並補發（只針對最近一次未完成的交易，或本地 pending 記錄）。

### 規格

* `PurchaseOrchestrator.onAppStart()`（或由 App 啟動時呼叫）
  * 檢查本地的 `pending_grant`（若你保存）或上次 `orderId`
  * 以 `skuId + orderId` 再走一次驗證（打 mock endpoint 即可）
  * 成功 → 呼叫 `EntitlementManager.grant`（冪等保護）
  * 完成後清理 `pending_grant`

## 驗收實例化需求

1. **中斷後補發**
   * Given：已購買成功但在「驗證前」App 崩潰
   * When：重啟 → `onAppStart()`
   * Then：觸發驗證並成功發放一次（冪等，不重複）
