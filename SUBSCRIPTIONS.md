# 月費會員生命週期

## 2026-09-09 設定狀態

- RevenueCat 專案：AI Pet Communicator（`79e402b2`）。已建立 V1 後端密鑰 `PAWLINK Firebase subscription sync`。
- 已將 `REVENUECAT_SECRET_API_KEY`、`REVENUECAT_WEBHOOK_AUTH` 存入 Firebase `fir-project-tw` 的 Secret Manager；密鑰值未存入此文件或程式碼。
- 已部署 `syncSubscription`、`revenueCatWebhook`、`reconcileSubscriptions` 至 `us-central1`。正式環境明確設定 `REVENUECAT_ALLOW_SANDBOX=false`。
- 已建立 RevenueCat Webhook `PAWLINK subscription lifecycle`（`whintgr069d23ba71`），接收 Production only、All apps、All events。
- HTTPS 接收端：`https://us-central1-fir-project-tw.cloudfunctions.net/revenueCatWebhook`。官方測試事件 `079CD34F-B2CF-44B5-AE34-BA8AF6343E72` 回應 200；缺少 Authorization 的請求回應 401。這驗證接線及驗證碼，不代表已完成真實購買驗收。
- 使用者已確認唯一 Pro 是本人帳號，並授權開通兩個月。已於 Firebase 設定管理員授權，有效至 **2026-11-09 08:33:29 Asia/Taipei**，無自動續費；回查確認成功。
- 管理員授權另存 `manualMembershipEntitlements`，並由可信後端合併到 `membershipEntitlements`。`subscriptionVerified` 表示後端已驗證權益（含管理員授權），不代表有付款紀錄。客戶端不能修改這些欄位。提供者同步不會縮短管理員授權，也不會縮短更長的已付費權益。
- 本人帳號設定 `subscriptionProviderSyncDisabled=true`，前景與 Webhook 同步均不向 RevenueCat 傳送此帳號 UID；將來連接真實購買須另行授權解除。
- **提供者補查排程仍為 PAUSED**；未部署本次新版 `reconcileSubscriptions`，不得直接恢復舊版排程。RevenueCat 目前只有 Test Store，正式商店與真實購買流程仍待設定驗收。
- 已部署更新版 `syncSubscription`、`revenueCatWebhook`、`communicateWithPet`，並新增 Firebase-only `expireMemberships`（每 15 分鐘，ENABLED），不查詢 RevenueCat。已發布新版 Web App 及 Firestore／Storage 規則，並比對公開 `main.dart.js` 與本機 SHA-256 一致。
- 本次 51 個後端測試、8 個規則測試通過，Web build 成功；此前 125 個 Flutter 測試通過。這不代表實體手機購買已驗收。
- 授權及公開部署驗證：`scratch/owner-pro-grant-verification.json`、`scratch/owner-pro-final-verification.json`。
- 真實 Firebase UID → RevenueCat 訂閱查詢被自動核准審查擋下，需使用者明確授權此跨服務識別碼傳送才能繼續遷移查證。沒有繞過限制或執行該查詢。
- 不含密鑰的部署日誌與驗證紀錄位於 `scratch/subscription_functions_deploy.txt`、`scratch/subscription_setup_verification.json`。

## 已實作的行為

- 付費權益由後端向 RevenueCat REST API v1 查證，使用 Firebase UID 作為 App User ID。
- `pro`、`plus` entitlement 分別記錄有效期限。Pro 到期但 Plus 仍有效時回到 Plus；全部到期則為 Free。到期時間本身不包含在有效期間內。
- 取消續訂不立即降級，保留已付款期間；付款寬限期使用 RevenueCat 回傳的 `grace_period_expires_date`。
- 月費產品必須有有效的到期時間。缺少期限、缺少後端驗證、舊版僅有 `membershipTier` 的帳號不會取得永久付費權益。
- AI 每次新請求都檢查伺服器時間，不依賴排程是否已更新會員標籤。Firestore、Storage 規則也直接檢查有效期限。
- 降級保留點數、寵物、照片及歷史紀錄。本人仍可讀取及刪除既有雲端資料；新寵物／修改／新紀錄與照片改存本機。升級時既有寵物同步流程會將本機照片上傳後再寫入 Firestore；本機紀錄與雲端歷史合併顯示。
- App 登入、回到前景、購買／恢復購買後觸發後端同步。會員到期計時器更新畫面與資料串流；設定頁提供手動同步及有效期顯示。
- 購買 SDK 回傳只代表購買結果，不直接修改 Firestore 的權益欄位。同步失敗不會由客戶端擅自把會員寫成 Free。

## 後端入口

| 名稱 | 用途 |
| --- | --- |
| `syncSubscription` | 已登入使用者查證自己的訂閱；每個 UID 間隔至少 10 秒，忽略客戶端提交的 UID／等級／到期日。 |
| `revenueCatWebhook` | 驗證固定 Authorization header 後重新讀取訂閱現況；也處理 TRANSFER 雙方及 aliases。提供者失敗回 503 讓 RevenueCat 重試。 |
| `reconcileSubscriptions` | 每 15 分鐘最多處理 100 個帳號，使用持久化游標輪巡所有帳號，補查漏掉的購買／續訂通知。失敗時仍以既有期限降級，下一輪重試。 |
| `expireMemberships` | 不呼叫提供者的獨立到期排程，每 15 分鐘最多處理 100 個帳號，以現有可信期限更新等級。即時權限由 AI／資料庫規則直接檢查時間。 |

輪巡一圈所需時間隨帳號數增加；100 個以上帳號不保證 15 分鐘內全部同步。到期權限判斷不受此延遲影響。Webhook、前景同步負責即時恢復續訂權益。

每次同步比較 RevenueCat 的 `request_date_ms`，較舊或相同時間的快照不覆蓋較新的快照。重複、延遲、亂序通知不直接套用通知中的等級／日期。不存在或已刪除的 Firebase 帳號不會被重建。

## 完整上線設定流程

1. 在 RevenueCat 建立／確認 entitlement ID 正好是 `plus`、`pro`，並連接對應月費商店商品。RevenueCat App User ID 必須與 Firebase UID 一致。既有匿名購買需先在原裝置登入／恢復購買完成身分關聯。
2. 在 Firebase Secret Manager 設定 `REVENUECAT_SECRET_API_KEY`（可讀 subscribers 的後端金鑰）與 `REVENUECAT_WEBHOOK_AUTH`（自行產生的高強度完整 Authorization header 值，例如 `Bearer ...`）。不得放入 Dart、Git 或前端 build。
3. iOS／Android build 使用 `--dart-define=REVENUECAT_APPLE_API_KEY=...` 或 `--dart-define=REVENUECAT_GOOGLE_API_KEY=...`，只放 RevenueCat 的平台公開 SDK key。未設定時不初始化商店 SDK；Web 使用後端同步，不呼叫行動商店購買。
4. 部署新 Functions，將 `revenueCatWebhook` 實際 HTTPS URL 填入 RevenueCat Webhooks。Authorization header 必須與 Secret Manager 的完整值相同。接收所有訂閱相關通知及轉移通知，避免只選到期事件。
5. 正式環境保持 `REVENUECAT_ALLOW_SANDBOX=false`（預設）。測試購買請使用獨立測試 Firebase／RevenueCat 環境；該環境可設為 true。
6. **先完成既有付費帳號的訂閱同步與核對，再發布新版 App／權限規則及 AI 函式**。舊的手動 Plus／Pro 標籤不算付款證據，不能靠加一個虛構未來日期遷移。新 Functions 可先單獨部署 `syncSubscription`、`revenueCatWebhook`、`reconcileSubscriptions`；核對後再部署 `communicateWithPet`、Firestore／Storage 規則與 App。
7. 確認 Cloud Scheduler 已建立排程並能執行。程式碼中的排程定義不等於已在正式環境啟用。

付款價格與方案購買頁仍沿用原專案狀態；本次不新增價格、不啟動收費。若只部署前端，無法完成後端訂閱驗證。

## 驗證

本次本機結果：48 項 Node 測試、125 項 Flutter 測試、8 項 Firebase 安全規則測試全部通過；Functions ESLint、Flutter 靜態分析與 Web 建置通過。後續部署情況見上方設定狀態；未進行真實商店交易。

- Node：`node --test functions/test/*.test.js`，涵蓋到期邊界、Pro → Plus → Free、取消／寬限期、sandbox 隔離、重複／亂序快照、並行同步、刪帳競爭、提供者故障與 AI 到期授權。
- Flutter：`flutter test --no-pub`，包含模型／mapper、到期後雲端寵物保留、本機修改／刪除不被覆蓋、歷史紀錄合併、本機照片及串流取消測試。
- 規則：`tools/security/rules.test.cjs` 使用 `demo-pawlink-security` 的 Firestore／Storage 模擬器；不得改成正式專案執行。
- `flutter analyze --no-pub`、`flutter build web --no-pub` 及 Functions ESLint。
- 尚須在設定完成後實測商店 sandbox 的首次購買、續訂、取消、寬限期／到期、恢復購買、退款與帳號轉移，並查看實際 Firestore 權益及排程執行紀錄。本機假資料測試不能取代這些驗收。

## 參考

- [RevenueCat Webhooks：驗證通知、重新查詢訂閱及重試](https://www.revenuecat.com/docs/integrations/webhooks)
- [事件流程：取消、付款失敗與寬限期](https://www-docs.revenuecat.com/docs/integrations/webhooks/event-flows)
