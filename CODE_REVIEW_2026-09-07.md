# PAWLINK 0.1.2 程式碼檢查報告

檢查日期：2026-09-07。檢查對象：本機 `ai-pet-communication`，分支 `docs/knowledge-base-updates`，HEAD `f6829f2`，包含使用者原本尚未提交的知識庫內容。

## 結論

Web 可編譯且能顯示登入畫面，但目前不能視為可正式提供服務的完整產品。主要阻礙是權限漏洞、未接上的 AI 服務、新手導引狀態不更新、帳號間本地資料混用，以及付費與資料同步流程不完整。

本報告的 Firebase 發現以本機規則為準，未讀取或修改線上已部署規則；代理風險以本機 handler 與離線替身驗證，沒有探測真實內網或攻擊線上服務。

## 實際驗證

| 項目 | 結果 | 能證明的範圍 |
|---|---|---|
| `flutter analyze --no-pub` | 156 項警告／提示，exit 1；未列出 error 級問題 | 包含未使用程式碼、無效空值判斷、過時 API、非同步 BuildContext 使用 |
| `flutter test --no-pub --reporter expanded` | 原有 45 項全部通過 | 多數依賴 Mock 或 Fake，不能證明真實雲端權限、AI、購買及跨帳號流程正常 |
| `flutter build web --release --no-pub` | 成功，產物在 build/web | Web 正式版可編譯 |
| 本機瀏覽器啟動正式版 | 成功顯示 PAWLINK 與 Google 登入按鈕 | 僅驗證未登入啟動畫面，未操作真實帳號 |
| `flutter build apk --release --no-pub` | 失敗：No Android SDK found | 本機缺少 Android SDK，未取得 APK，也未做裝置測試 |
| iOS | 未建置 | Windows 環境未具備 Xcode |
| `node --check functions/index.js` | 通過 | 僅 JavaScript 語法，不代表 Firebase 執行與部署成功 |
| 額外 Dart 診斷 | 4 項問題重現成功 | 真實 ChatService 回退、問卷狀態陳舊、跨帳號寵物資料、扣點負值 |
| 額外代理診斷 | 2 項問題重現成功 | 未認證 localhost URL 被接受；任意 HTML 以 text/html 回傳 |

補充診斷是「斷言缺陷目前確實存在」，因此顯示通過代表成功重現問題，不是問題已修好。Firebase 安全規則尚未用 Emulator 實測；Functions 沒有本機 node_modules／鎖定檔，未完成相依套件漏洞資料庫掃描，不對所有套件宣稱無已知漏洞。

## 優先處理的安全與功能缺陷

### 1. P1：使用者可以自行加點、升級會員

位置：[firestore.rules:7](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/firestore.rules:7)、[firestore.rules:12](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/firestore.rules:12)、[lib/screens/profile/settings_screen.dart:73](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/screens/profile/settings_screen.dart:73)。

建立帳號只檢查初始 points=1，未限制 membershipTier；更新只檢查本人及 uid 不變。因此登入者可以直接修改自己的 points、membershipTier。正式 UI 還保留「模擬切換方案」入口，呼叫 updateMembership 直接寫入資料庫。

影響：付費方案、使用額度及營收控制可被繞過；隱藏按鈕本身無法修補資料庫漏洞。

建議：限制客戶端可修改欄位，會員授權與點數由可信任後端處理；購買與廣告奖励需驗證可信回執，建立資料也必須限制方案初始值。

### 2. P1：Storage 沒有帳號隔離

位置：[storage.rules:4](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/storage.rules:4)、[lib/features/pet/data/sources/pet_remote_data_source.dart:45](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/sources/pet_remote_data_source.dart:45)。

全 bucket 任意路徑均允許已登入者 read/write，未驗證路徑 uid、檔案大小或類型。上傳路徑雖為 pets/{uid}/{imageId}.jpg，規則並沒有強制 uid 必須是本人。

影響：知道路徑的其他登入使用者可讀取、覆寫、刪除別人的圖片；也可濫用儲存空間。

建議：依 uid 驗證擁有權，限制大小和可接受圖片類型；需要公開圖片時另定明確的唯讀範圍。

### 3. P1：圖片代理可被用作任意伺服器請求

位置：[functions/index.js:9](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/functions/index.js:9)、[functions/index.js:25](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/functions/index.js:25)。

只檢查 http/https，沒有主機白名單、內網位址防護、認證或請求配額；fetch 預設亦會跟隨重新導向。離線驗證確認 http://127.0.0.1/private 會交給 fetch。

影響：可濫用後端對其可到達的內網／外網發送請求並消耗流量。實際可讀取哪些內部資源取決於部署網路與資源認證，不能由這次離線測試推定可取得雲端憑證。

建議：只代理必要的可信圖片來源，檢查 URL 與每次 redirect，阻擋內網位址，加入配額、回應大小限制及可中止的上游請求。

### 4. P1：代理可在 App 網域回傳任意 HTML

位置：[functions/index.js:37](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/functions/index.js:37)、[functions/index.js:48](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/functions/index.js:48)、[firebase.json:10](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/firebase.json:10)。

代理原封不動採用上游 Content-Type 並回傳內容；Hosting 把 /cors-proxy 接到這個函式。離線測試確認 text/html 被接受，沒有 sandbox CSP。

影響：若照此部署，攻擊者可引導使用者開啟 App 網域上的代理網址，載入攻擊者 HTML/JavaScript，形成同來源腳本風險。這與單純 CORS 設定不同。

建議：限制允許的圖片 MIME 與實際內容，拒絕 HTML/SVG 等可執行內容，加入 nosniff；必要時將代理設於獨立來源。

### 5. P1：本地資料跨帳號顯示

位置：[lib/features/pet/data/local_pet_service.dart:5](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/local_pet_service.dart:5)、[lib/features/pet/application/pet_stream_watcher.dart:33](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/application/pet_stream_watcher.dart:33)、[lib/services/auth_service.dart:99](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:99)。

所有帳號共用 local_pets，watchPets 回傳全部資料，Free 分支未按 uid 過濾；登出未清除／切換帳號資料區。migrateIfNeeded(uid) 也讀取全部本地寵物。

重現：模擬登入 B 帳號並呼叫 watchPetsByOwner('owner-b')，回傳的寵物 ownerId 是 owner-a。

建議：以 uid 分區本地儲存，讀寫及遷移均驗證 ownerId；登出取消監聽、清理記憶體狀態並關閉該帳號的資料區。

### 6. P1：AI 核心服務尚未實作

位置：[lib/features/chat/data/chat_service.dart:1](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/chat/data/chat_service.dart:1)、[lib/features/chat/application/chat_controller.dart:24](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/chat/application/chat_controller.dart:24)。

ChatService 只有延遲 1 秒後回傳「這是來自 AI 的回應: ...」，沒有呼叫模型；控制器卻要求符合 schema 的 JSON。因此真實路徑會解析失敗、重試，最後回傳 fallback-1。額外測試已重現。

另外，知識庫與角色檔雖列於 pubspec assets，lib 沒有載入這些檔案的程式；不能把知識庫文件更新視為 AI 已實際使用新內容。

建議：經可信後端串接真實模型，傳遞結構化 messages、授權、額度、知識檢索及回應驗證，明確區別成功與失敗結果。

### 7. P1：完成新手問卷後不會收到使用者狀態更新

位置：[lib/services/auth_service.dart:34](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:34)、[lib/services/auth_service.dart:133](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:133)、[lib/screens/onboarding/onboarding_screen.dart:350](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/screens/onboarding/onboarding_screen.dart:350)。

getUserStream 只在 Firebase Auth 登入狀態改變時單次 get 使用者文件；問卷完成只 update Firestore，沒有新的 stream 事件。OnboardingScreen 卻依賴這個事件切換首頁，也未在完成後恢復 submitting。

重現：Firestore 已變成 hasCompletedOnboarding=true，但訂閱者收到的最後狀態仍是 false，事件數維持 1。點數與方案顯示也會受相同問題影響。

建議：由 authStateChanges 切換訂閱 users/{uid}.snapshots，管理取消與錯誤；提交失敗時恢復 UI，防止重複提交。

### 8. P1：行動版啟動與登入條件不完整

位置：[android/app/src/main/AndroidManifest.xml:2](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/android/app/src/main/AndroidManifest.xml:2)、[ios/Runner/Info.plist:5](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/ios/Runner/Info.plist:5)、[lib/services/ad_service.dart:34](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/ad_service.dart:34)、[lib/services/auth_service.dart:69](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:69)。

Android/iOS 沒有 AdMob App ID 設定，但 main 會初始化 Mobile Ads；這是官方明確列出的崩潰條件。Google 登入統一使用 signInWithPopup，沒有 native 平台分支。iOS 也沒有目前圖片選取流程所需設定的完整驗證。

建議：補齊平台設定與原生登入，實際 Android/iOS 裝置測試。Android SDK 在本機缺失，所以本次未重現 native crash。

依據：[Google AdMob Android 初始化說明](https://firebase.google.com/docs/admob/android/quick-start)、[Flutter AdMob 設定](https://developers.google.com/admob/flutter/quick-start)。

## 資料一致性與產品完整性

### 9. P2：扣點可變負數，取消與失敗沒有補償

位置：[lib/services/auth_service.dart:125](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:125)、[lib/services/membership_action_handler.dart:150](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/membership_action_handler.dart:150)。

consumePoints 直接 increment(-points)，沒有交易內的餘額檢查。額外測試確認從 1 點同時扣兩次得到 -1。扣點時間又在進入輸入頁前，使用者取消或 AI 失敗都沒有退款流程。

建議：後端以具唯一請求編號的交易預留／結算／退回額度，避免重送重扣；產品明確定義扣點時機。

### 10. P2：Free 寵物只在本地，溝通紀錄卻只寫 Firestore

位置：[lib/features/pet/data/repositories/pet_repository_impl.dart:40](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/repositories/pet_repository_impl.dart:40)、[lib/features/readings/data/firestore_readings_repository.dart:37](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/readings/data/firestore_readings_repository.dart:37)、[firestore.rules:28](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/firestore.rules:28)、[lib/features/readings/application/reading_service.dart:33](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/readings/application/reading_service.dart:33)。

Free 新建寵物不建立雲端父文件，但紀錄 repository 一律寫 pets/{petId}/readings；規則要求父文件屬於本人，因此本地-only 寵物的雲端紀錄寫入會被拒絕。ReadingService 捕捉失敗只記錄 log，呼叫端仍當成功。

目前真實 AI 本身會先 fallback；AI 接通後這個持久化缺陷仍會阻止 Free 紀錄可靠儲存。

建議：提供本地 reading repository，或調整整體資料模型與權限策略；將儲存結果傳回 UI，明確顯示未儲存與重試狀態。

### 11. P2：同步沒有完整的離線操作與刪除協議

位置：[lib/features/pet/data/repositories/pet_repository_impl.dart:58](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/repositories/pet_repository_impl.dart:58)、[lib/features/pet/data/repositories/pet_repository_impl.dart:81](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/repositories/pet_repository_impl.dart:81)、[lib/features/pet/application/pet_stream_watcher.dart:58](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/application/pet_stream_watcher.dart:58)、[lib/features/pet/application/pet_sync_manager.dart:29](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/application/pet_sync_manager.dart:29)。

雲端寫入失敗僅寫本地，沒有 pending operation queue；刪除失敗也僅刪本地，不保留刪除標記。雲端監聽成功時沒有同步更新本地快取，降級串流啟用後亦沒有在恢復雲端時取消。

可造成：重新讀取時刪除的資料回來、其他裝置修改未更新離線副本；另一裝置刪除的寵物，也可能被本地舊資料的 migrateIfNeeded 重新建立。

建議：統一資料來源、同步狀態與錯誤傳遞；加入待同步佇列、重試及 tombstone/version 機制，對恢復連線與多裝置衝突寫測試。

### 12. P2：刪除帳號沒有清理所屬資料

位置：[lib/services/auth_service.dart:150](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/auth_service.dart:150)、[lib/features/pet/data/sources/pet_remote_data_source.dart:32](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/pet/data/sources/pet_remote_data_source.dart:32)。

deleteAccount 只先刪 users 文件再刪 Auth 帳號；pets、readings、Storage、本地資料未清除。若 Auth 刪除因需重新驗證失敗，使用者文件已先被刪除。刪單一寵物也未遞迴清理 readings 與圖片。

建議：先完成重新認證，再使用可重試的後端清理工作，涵蓋所有資料與本地登出清理，避免中途失敗造成不一致。

### 13. P2：購買與付費體驗尚未串接

位置：[lib/services/subscription_service.dart:10](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/subscription_service.dart:10)、[lib/services/membership_action_handler.dart:37](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/services/membership_action_handler.dart:37)、[lib/features/chat/presentation/pet_communication_input_screen.dart:82](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/lib/features/chat/presentation/pet_communication_input_screen.dart:82)。

RevenueCat 使用 placeholder keys，未找到正式 UI 呼叫購買與授權同步的完整流程。Plus 即使有點數也只收到升級提示，是否符合方案定義需確認；輸入頁對所有帳號固定 inputMode=free、寵物年齡=3、飼主資料為示範值。

建議：先確認方案規格，再串接購買、恢復、帳號關聯、後端授權與真實檔案資料；未完成前不要對外當作可用付費功能。

### 14. P2：部署設定與本機安全檔案未完整連結

位置：[firebase.json:22](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/firebase.json:22)、[functions/package.json:12](C:/Users/s2230/.gemini/antigravity-ide/scratch/ai-pet-communication/functions/package.json:12)。

firebase.json 未指定 storage.rules，不能假設一般部署會更新這份 Storage 規則。Functions 使用 Node 18，官方文件已列為淘汰；Functions 沒有 lockfile、ESLint 設定及安全規則測試工作流。

建議：明確列出所有部署資源，採用受支援 runtime，建立可重現的相依版本與規則 Emulator 測試。runtime 狀態依據：[Firebase 管理函式](https://firebase.google.com/docs/functions/manage-functions?hl=zh-TW)。

## 架構與維護性評估

已具備 feature 資料夾、部分 domain/application/data/presentation 分層、repository 介面與 GetIt 組裝，這些可以保留，不需要整套重寫。

需要調整的重點：

- **依賴來源混用**：GetIt、服務內 static singleton、預設建立 Firebase.instance 與相容 factory 並存；PetService 即使提供部分依賴仍會自行建立其他服務，容易讓測試與正式環境行為不同。集中在 injection.dart 組裝，業務層用必要建構參數。
- **錯誤語意不清楚**：多個 catch 只 debugPrint，UI 無法區別已儲存、僅本地儲存與完全失敗；改為具型別的結果。
- **ChatController 回傳 dynamic**：安全版、一般版、失敗版沒有共同可辨識的結果契約；建議 sealed result，避免 UI 猜型別。
- **帳號生命週期未管理**：authStateChanges 訂閱未保存，hasListener 不能當作「已初始化」旗標；關閉／重建畫面可能增加底層監聽，登出也沒有統一重置本地與訂閱。
- **宣告與實作有落差**：桌面 Firebase 明確 throw UnsupportedError；清除快取按鈕只顯示成功訊息、沒有清理動作；設定畫面版本仍為 0.1.0。
- **知識庫保密範圍**：知識庫以 asset 打包進 Web；Git 加密不會保護部署後可下載的明文資產。若需要保密，應改由後端提供檢索。此項是否需要改取決於資料公開政策。
- **Git 加密工具的環境依賴**：本次 git diff 觸發 kbcrypt 時出現 python: command not found。需為協作者明確設定 Python／cryptography 與安全的金鑰供應；本次沒有變更 filter 或金鑰。
- **測試覆蓋缺口**：現有測試刻意接受「儲存錯誤被吞掉」、mock 成功 JSON，也測試 Plus 被擋的現況；因此全綠並不代表產品流程正確。需新增安全規則、首次登入問卷、帳號切換、真正服務整合、離線刪除及購買授權測試。

## 建議修復順序與驗收

1. 先處理會員／點數規則、Storage 隔離、代理來源與 MIME 限制；用 Emulator 驗證惡意寫入被拒絕。
2. 修復帳號 stream 與本地分區；驗證首次問卷可進首頁、切換帳號無資料混用。
3. 接上真正 AI 與 reading 儲存，建立額度結算／退款；驗證成功、取消、失敗與重試。
4. 完成同步佇列、刪除流程與購買授權。
5. 補 native 配置與 SDK，在真機跑登入、圖片選取、廣告及購買。
6. 清理靜態警告並把建置、測試、規則驗證納入 CI。

本次新增本報告與 scratch 下三個診斷／預覽腳本，未修改 lib、Firebase 規則、Functions 業務碼或使用者原有知識庫。Web build 產物已重建；沒有部署、修改線上帳號或扣除真實點數。

可重跑診斷：

```powershell
flutter test --no-pub --reporter expanded scratch/audit_20260907_test.dart
node scratch/audit_proxy_20260907.cjs
```
