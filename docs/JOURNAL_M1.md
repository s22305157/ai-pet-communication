# PAWLINK 日記 M0–M1 交付與操作手冊

本次工作只做到 M1。版本號更新為 0.2.8，僅推送 Git、不部署正式環境，也不實作 M2 回顧、M3 社群、M4 上線或 M5 觀察。主分支既有檔案與未追蹤工作產物不納入此功能提交。

## 已實作流程

首頁「毛孩日記」→ 讀取後端資格 → 閱讀並同意說明 → 建立一份毛孩日記資料（不限物種） → 記錄文字／照片 → 儲存到私人雲端 → 篩選、編輯、刪除與匯出。

- 私人日記與原有付費毛孩資料分離，原有會員、點數與 AI 溝通門檻不改動。
- 名字與種類可從裝置上已有的毛孩資料帶入。UI 明示是複製名字與種類；不自動連結、上傳其他檔案或私人對話。API 的選填 `linkedPetId` 僅接受後端驗證屬於本人的既有雲端毛孩。
- 300 則日記、200 MiB 正規化圖片，每日最多新增 20 則日記。每則最多 3 張 JPEG/PNG、2,000 字觀察、500 字行動、500 字結果。
- 伺服器禁止未來時間。時間戳採 Firestore Timestamp，本週統計依 Asia/Taipei。
- 編輯使用 revision；衝突保留本機草稿，必須先閱讀雲端新版本後重新編輯。
- 圖片原檔上限 10 MiB，sharp 驗證真實格式、限制解碼像素、移除 EXIF、長邊最多 1,600 px、正規化 JPEG 最多 1 MiB。不建立 Firebase 公開下載 token。
- 儲存按鈕固定在表單底部。草稿立即按 UID、日記毛孩與 entryId 分區寫入 SharedPreferences；帳號刪除清除該帳號草稿。登出不刪除草稿，但其他帳號無法透過 App 讀取。
- JSON 匯出包含文字、日期與媒體 ID；照片在日記點選放大後逐張下載。此版不提供整包照片 ZIP。
- 未開放、停用、過期或開關關閉時，不能新增／編輯；原有本人資料仍可閱讀、匯出、刪除。

## M1 的界線

這不是完整離線 PWA。已開啟表單可離線保留文字；照片上傳、雲端列表與儲存需要連線。未存入日記的已上傳照片保留 24 小時；草稿復原時若照片過期，移除該照片後重新上傳。

回顧與社群沒有分頁、空功能入口或假資料。資格資料保留規畫要求的一次性 28 天 trialEndsAt，但 M1 不生成 AI、也不根據這個期限限制日記；未來開放 M2 前需核對早期試營運帳號的試用期安排。

## M0 開關與資格

`pilotConfig/features` 是伺服器專用文件，缺少文件或 `journalEnabled != true` 即關閉新增與編輯。`reviewEnabled`、`communityEnabled` 保持 false，僅為後续保留旗標。

資格文件 `pilotParticipants/{uid}`：

| 欄位 | 說明 |
|---|---|
| status | invited 或 disabled |
| expiresAt | 邀請期限，排他上界 |
| activatedAt、trialEndsAt | 首次啟用時間與一次性 28 天期限，重複啟用不延長 |
| consentVersion | journal-m1-v1 |
| metricsConsent | 選填成效量測同意，不影響使用 |
| isTest、isAdmin | 排除成效量測 |
| journalPetId | 由後端記錄，用於建立時併發序列化 |

不製作管理網頁（屬 M3）。M0 提供 `adminSetPilotParticipant` callable 與維護 CLI。callable 要求 Firebase Auth 自訂 `pilotAdmin: true`，不信任客戶端或會員文件的管理旗標。

CLI 必須明確傳入專案，使用環境提供的 Application Default Credentials；不儲存或輸出金鑰。本次只執行 demo 模擬器，不設定正式帳號。

```powershell
# 在已啟動的本機模擬器環境使用；正式環境操作應留待另外核准的上線階段。
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9198'
node tools/maintenance/journal-pilot.cjs flags --project demo-pawlink-security --enabled true
node tools/maintenance/journal-pilot.cjs invite --project demo-pawlink-security --uid YOUR_TEST_UID --expires 2030-01-01T00:00:00+08:00 --test true
node tools/maintenance/journal-pilot.cjs inspect --project demo-pawlink-security --uid YOUR_TEST_UID
node tools/maintenance/journal-pilot.cjs disable --project demo-pawlink-security --uid YOUR_TEST_UID
```

`flags --enabled false` 停止寫入；`admin --uid ...` 僅供管理者設定自訂權限，會保留原有 claims，生效需重新取得 ID token。

## API 契約

所有 callable 使用 Firebase ID token。回應錯誤經後端處理，不回傳原始 exception、圖片、正文或金鑰。新增寫入以 `operationId` 去重；同 ID 不同內容拒絕。刪除及取消亦去重；圖片原檔上傳以已預留的 mediaId 與內容 SHA 防止覆寫。

| API | 主要輸入 | 回應 |
|---|---|---|
| getPilotAccess | 無 | invited、enabled、activated、期限毫秒值、limits |
| activatePilot | operationId、consentVersion、metricsConsent | activated |
| createJournalPet | operationId、name、species（必填，最多 80 字）、focus、arrivedAtMs?、linkedPetId? | 後端 petId |
| getJournalHome | 無 | pet、weekDays |
| upsertJournalEntry | operationId、petId、entryId、expectedRevision、occurredAtMs、context、observation、action、outcome、mediaIds | entryId、revision |
| listJournalEntries | petId、context?、fromMs?、toMs?、cursor? | 最多 20 筆 items、下頁 cursor |
| deleteJournalEntry | operationId、petId、entryId、expectedRevision | deleted |
| beginJournalUpload | operationId、petId、bytes、contentType | mediaId、內部 path |
| uploadJournalBytes | mediaId、base64 | uploaded |
| finalizeJournalUpload | operationId、mediaId | mediaId |
| cancelJournalUpload | operationId、mediaId | cancelled |
| getJournalImage | mediaId | 正規化 JPEG base64 |
| exportJournal | petId | schemaVersion、name、entries |
| deleteJournalPet | operationId、petId | deleted（邏輯刪除立即生效，實體清理重試） |
| adminSetPilotParticipant | operationId、uid、status、expiresAtMs、isTest? | saved |

草稿的 entryId 在客戶端產生以支援新增去重，但始終位於登入帳號的私人 namespace；不能拿它存取其他帳號。日記毛孩 ID 由伺服器產生。

錯誤：unauthenticated 未登入、permission-denied 關閉或未邀請、not-found 已刪除或不屬於此人的 ID、invalid-argument 格式錯誤、aborted 編輯衝突、resource-exhausted 容量／頻率限制、already-exists 重用操作 ID、unavailable 暫時失敗。

## 資料、媒體與清理

- `users/{uid}/journalPets/{petId}/entries/{entryId}`：私人日記，後端寫入，Rules 僅允許有效本人單筆讀取；列表經後端查詢。
- `users/{uid}/journalMedia/{mediaId}`：pending/ready/deleted、預留與實際容量、內部 path；客戶端禁止直接讀寫。
- `journalOperations`：操作 hash 與不含正文的結果；`journalLimits`：每分鐘最多 60 個新寫入操作。
- `pilotEvents`：同意者的啟用、建立及編輯事件，不含正文或照片；到期 90 天由清理工作刪除。不在 M1 宣稱已有 M4 成效面板。
- `_journalCleanup`、`_journalPetCleanup`：可重試實體清理工作；`_pilotAdminAudit`：資格維護紀錄。

圖片經 callable 傳輸，而非讓客戶端直接使用 Storage SDK。原因是 Storage Rules 每次最多讀兩份 Firestore 文件，無法同時可靠驗證帳號刪除標記、資格、全域開關與日記／媒體狀態。兩種日記 Storage 路徑均禁止客戶端直接讀寫；後端讀取在下載前後檢查帳號與毛孩狀態，回應採 private/no-store。

官方限制來源：https://firebase.blog/posts/2022/09/announcing-cross-service-security-rules/

每次上傳預留 1 MiB，最多三個未完成上傳、每日最多 60 次新上傳。失敗時前端嘗試取消，無網路時由伺服器每小時掃描，清除超過 24 小時的未附加照片。正常化完成後的原檔也有獨立清理標記。

日記刪除保留不含內容的 tombstone，防止舊草稿重新建立；照片立刻不可讀，實體檔案由清理工作移除。日記毛孩刪除先標記、再重試清理。原有帳號／毛孩刪除已接入此清理流程；有驗證連結的原毛孩 tombstone 也會立即阻止讀寫。

## 本機驗證

需要 Flutter、Node 22、Java 21，以及已安裝的 functions / tools/security 依賴。Firebase 一律使用 demo-pawlink-security。不要把範例專案替換為正式專案進行測試。

```powershell
flutter pub get --offline
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub
node functions/node_modules/eslint/bin/eslint.js functions
node --test functions/test/*.test.js
node tools/security/apply-security-patches.cjs
node tools/security/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --config firebase.journal-test.json --project demo-pawlink-security --only auth,firestore,storage,functions "node --test tools/security/journal.test.cjs"
# 既有權限回歸另跑，避免兩個 suite 同時清空相同模擬資料庫。
node tools/security/node_modules/firebase-tools/lib/bin/firebase.js emulators:exec --config firebase.security.json --project demo-pawlink-security --only firestore,storage "node --test tools/security/rules.test.cjs"
```

`firebase.journal-test.json` 不屬於正式部署設定。自動測試覆蓋实际 callable 身分驗證與讀寫、真實 Firestore 交易／Rules、Storage 圖片處理、容量併發與刪除競態；清理排程的 service 直接呼叫驗證，不宣稱雲端排程已部署。

真實 iPhone／Android 照片選取、鍵盤與檔案下載，及三分鐘完成首次紀錄的真人計時，仍需實機驗收；390×844 widget 測試不能替代實機。

## 本次驗證結果（2026-09-09）

| 項目 | 結果 |
|---|---|
| Flutter analyze | 通過，無 issue |
| Flutter 全部測試 | 142 項通過，含 M1 草稿、衝突、跨帳號與 390×844 版面 |
| Flutter Web release build | 通過，僅本機建置 |
| Functions ESLint | 通過 |
| Node 後端測試 | 59 項通過，含真實 sharp 圖片編解碼與舊功能回歸 |
| M1 Firebase 模擬器 | 14 項通過，含 HTTP callable 登入、日記、圖片全流程與到期邊界 |
| 既有 Firebase Rules 模擬器 | 9 項通過 |
| 新增依賴 | sharp 鎖定 0.35.4，安裝後 audit 0 漏洞 |

模擬器使用 demo 專案，沒有向正式 Firebase 寫入資料、開放名單或部署。未實測實體手機、正式 Firebase 與正式雲端排程。M2–M5 不在本次交付中。

此環境可用的執行路徑：Flutter `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\bin\cache\flutter_tools.snapshot`；Java `scratch/security-jre/jdk-21.0.12.1+1-jre/bin`。一般安裝環境使用前面的標準命令即可。
