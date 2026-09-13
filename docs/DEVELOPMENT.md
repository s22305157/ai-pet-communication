# 開發與驗證

## 環境

- Flutter 最低測試版本為 3.41.7，Dart 至少 3.11.5；CI 同時驗證最低版與 stable。
- Node.js **24**：Functions runtime、後端測試與 CI 使用相同主版本。
- Java **21**：Firebase Firestore／Storage 模擬器需要 Java。讓 `java` 可從 PATH 執行。
- Chrome：執行瀏覽器測試時使用。必要時以 `CHROME_EXECUTABLE` 指定位置。
- 將 `FLUTTER_ROOT` 設成 Flutter SDK 根目錄，或每次驗證傳入 `--flutter-sdk`。

首次安裝：

```sh
flutter pub get
npm ci --ignore-scripts --prefix functions
npm ci --ignore-scripts --prefix tools/security
node tools/security/apply-security-patches.cjs
node scripts/package_knowledge.cjs
```

最低 Flutter SDK 如需相容性覆寫，使用本機 `pubspec_overrides.yaml` 指定 `firebase_core_web: 3.10.0`；此檔不提交。stable CI 不繼承本機覆寫。

## 日常操作

```sh
node scripts/verify.cjs --flutter-sdk <Flutter SDK 根目錄>
```

依序檢查產生檔案、後端 ESLint／測試、Flutter 分析／測試，遇到失敗立即停止。一般開發可用 `flutter run`。

發布前完整本機驗證：

```sh
node scripts/verify.cjs --flutter-sdk <Flutter SDK 根目錄> --release --emulators
npm audit --omit=dev --prefix functions
```

`--release` 加入 Chrome 測試、Web release build 與產物檢查；`--emulators` 加入測試工具依賴檢查、Rules、日記、社群／回顧、M4 及溝通照片到期清除整合測試。照片測試使用實際 Storage 模擬器與 Admin SDK，確認 24 小時邊界、處理中保護與清除進度的存取限制。另以 `npm audit` 查詢正式 Functions 依賴的已知漏洞。模擬器固定使用 `demo-pawlink-security`，不使用正式資料。驗證入口不會推送 Git 或部署。

Storage 模擬器 15.29.0 的刪除端點忽略 `generation`／`ifGenerationMatch`。測試會獨立探測此能力，未支援時明確跳過檔案替換競態；未來支援後會自動執行該斷言。另以實際 Cloud Storage SDK 向本機 HTTP 測試服務確認版本條件確實送出，並驗證 HTTP 412 的處理。這項傳輸契約測試不代表真實 GCS 的版本保護已完成驗收。

真實 GCS 補驗工具為 `tools/security/gcs-generation-check.cjs`，須另行授權雲端操作後手動執行，不納入一般驗證或 CI。它只接受 `pawlink-gcs-test-<6 位日期>-<4 至 8 位識別碼>` 的獨立專案，並核對專案標籤 `purpose=gcs-generation-test`；需要既有雲端登入、Storage API 與可用計費。具備 Application Default Credentials 時可執行 `node tools/security/gcs-generation-check.cjs <專案 ID> scratch/gcs-generation-results.json`。工具在兩個私人暫存桶分別啟用／停用版本保留，執行 8 項真實 GCS 驗證，最後只清除本輪建立且標籤吻合的檔案版本與儲存桶。Firestore 操作狀態以合成資料注入，未驗證雲端 Firestore 或排程。執行者需在完成後核對資源清除，並處理本次專案的計費解除與刪除。

Windows 可使用獨立 Java 21 執行環境，不必修改系統 PATH。執行測試的 PowerShell 工作階段需將 `JAVA_HOME` 指向安裝根目錄，並把其 `bin` 加入該工作階段的 PATH；先用 `java --version` 確認為 21，再執行驗證。若 Java 已存放在 Git 忽略的 `scratch` 目錄，只需要接上路徑，不必重新下載。

Hosting 的 `predeploy` 會執行 `scripts/build_hosting.cjs`：先核對產生檔案，再重新建置目前原始碼，最後檢查產物。即使版本號相同，也不能直接使用上次的 `build/web`。部署前需設定 `FLUTTER_ROOT`；缺少 SDK 或任何步驟失敗都會中止。可先執行 `node scripts/build_hosting.cjs --flutter-sdk <SDK 路徑>`，此命令只建置與驗證，不部署。

## 功能分工

| 位置 | 責任 |
| --- | --- |
| `lib/app` | 初始化、依賴組裝、跨功能導航、請求轉換器註冊 |
| `lib/core` | 共用 session、儲存、錯誤型別、請求傳輸介面與操作控制器 |
| `lib/features/*/domain` | 功能資料模型、操作請求與存取介面 |
| `lib/features/*/application` | 業務流程、草稿、重試、帳號與操作生命週期 |
| `lib/features/*/data` | Firebase／本機儲存、資料格式與錯誤轉換 |
| `lib/features/*/presentation` | 畫面、表單輸入、導航互動 |
| `functions/endpoints` | 各功能公開 callable 名稱；服務實作維持在 Functions 模組 |
| `content/planet_cards.json` | 圖卡文案、穩定編號與圖片位置的唯一編輯來源 |

新增社群、回顧或試營運操作時，在所屬 domain 定義請求、data 定義轉換；只有新的功能類別需要修改 `app/data/request_wire_mapper.dart`。畫面透過 `RequestRepository.execute` 與 `RequestController.submit`，不直接使用 Firebase 或 callable 字串。

`ServiceFailure` 表達帳號變更、版本衝突、離線與配額等原因；SDK 錯誤在 data 層轉換。新增流程應直接注入依賴，並測試帳號切換、重複送出及非同步完成順序。

- `core` 不引用 `features` 或 `app`；`app` 負責組裝。既有畫面使用的主題、依賴入口、跨功能路由與版本常數維持明確的檔案範圍。分層檢查同時涵蓋 core 與 features。
- 日記使用同一個 `JournalDrafts` 實例，立即排入讀寫、捨棄與帳號清除工作；Controller 不另外持有延後送入 store 的佇列。
- 聊天以 `ChatConsultation` 與 `CommunicationResponse` 傳遞資料；callable 封裝與回覆解析集中在 data。只有 unavailable、timeout、internal 自動重試一次並保留 requestId；pending 與 unknown 保留操作識別，但不自動重送。輸入／回覆驗證失敗不重送，紀錄保存失敗只重試保存。
- 日記後端由 `journal_context.js` 共用資格、操作去重與量測規則，各功能服務在實際使用時建立；照片驗證通過且開始解碼時才載入 Sharp。

## 溝通照片保留

`communicationPhotos/` 的照片在建立 24 小時後不可再供新請求使用。客戶端原有的清除保留；`cleanupCommunicationPhotos` 每小時分批清除過期照片，跳過仍在 10 分鐘處理寬限內的請求，並以 Storage generation 限定刪除版本。未完成的分頁位置保存在 `_maintenance/communicationPhotoCleanup`，儲存服務失敗時不推進進度。

此排程須部署 Functions 後才生效。正式 bucket 的 soft delete、版本保留與 lifecycle 設定需在部署驗收時另行核對；本機測試不代表雲端已清除，也不保證備份或軟刪除副本立即消失。

既有分層例外記錄於 `test/architecture/legacy_imports.json`。修改相關模組時應減少例外，不新增寬鬆目錄豁免；已失效的例外會讓測試失敗。

## 圖卡與版本

```sh
node scripts/generate_catalog.cjs
node scripts/generate_version.cjs
node scripts/verify_generated.cjs
```

圖卡編輯 `content/planet_cards.json`，圖片放在 `assets/cards`，再產生 Dart 常數。既有編號不可重排或重用；授卡規則仍由 `functions/planet_cards.js` 在後端判斷，契約測試核對前後端編號。

版本只編輯 `pubspec.yaml`，再產生畫面常數與 Web 入口。Web 客製內容編輯 `tools/build/templates`，不要直接修改產生的 `web/index.html`、`web/flutter_bootstrap.js` 或 `.g.dart`。CI 與部署前檢查會拒絕過期產物。

## 常見問題與驗證界線

- Windows 的 Flutter 啟動器或 SDK 快取權限有問題時，驗證入口會使用 SDK 自己的 Dart、工具快照與套件設定；執行者仍需具備 SDK／使用者工具狀態的寫入權限。
- 瀏覽器圖片測試需使用既有 `chrome_test_runner.dart`。直接執行 `flutter test --platform chrome` 不會啟動測試資產服務。
- Functions 模擬器前需封裝知識索引；封裝只複製加密內容，不需要讀取正式金鑰。
- 本機／模擬器測試不代表正式 AI、實際付款或實體手機驗證。部署後另核對公開產物雜湊及 Functions runtime。
- 本機計畫、分析報告與操作紀錄保留在忽略目錄，不加入 Hosting 產物。
