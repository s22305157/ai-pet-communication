# PAWLINK 結構優化驗收紀錄

依據使用者提供的 2026-09-08 結構檢查逐項修改。正式服務未寫入、未部署。

| 項目 | 完成內容 | 驗證 |
| --- | --- | --- |
| 1. 依賴組裝 | PetService 改為四個必要建構子依賴，移除 GetIt／Firebase／Hive fallback；測試組裝移至 test/support。AuthService 改一般建構子，DI 管理 singleton 與 dispose。 | 未初始化 Firebase/Hive 建立服務、註冊 GetIt 替身不改變行為。 |
| 2. 序列化與時間 | PetLocalMapper 保留本地版本時間；PetFirestoreMapper 分開 create/update，create 必帶 created_at、update 不覆寫 created_at；repository 接受 clock。另將知識庫六個 domain 模型的 Firestore 轉換移到 data/mappers。 | 建立／更新 payload 與本地時間往返測試；domain import 邊界檢查。 |
| 3. 寫入結果 | create/update 回傳 saved、pendingSync、conflict；身分／owner 錯誤使用 PetWriteFailure；只將明列的暫時性 Firebase 錯誤或 timeout 排入佇列；永久刪除失敗也不寫 tombstone。表單衝突保留草稿、離線顯示待同步。 | 不可重試錯誤不入列、owner mismatch、遠端較新不送出更新，以及表單衝突保留案例。 |
| 4. 同步生命週期 | 每 uid 以 Future queue 序列執行，錯誤不污染後續工作；快照使用 asyncMap；session generation 阻擋舊 session 更新狀態；公開唯讀 SyncState 與 ValueListenable。pending operation 使用獨立 operationId，舊上傳完成不清掉新操作。 | 同 uid 快照順序、跨 uid 獨立執行、失敗後補跑、同步中追加修改、舊／取消 session 狀態、既有帳號隔離與 fallback/recovery。 |
| 5. 模組解耦 | CurrentSession 與 StoragePolicy 集中 session／儲存判斷；ReadingsRepository 移 domain，本地與雲端依賴使用介面。寵物／readings 清理由 PetCleanupRepository 協調，帳號清理由 AccountDataCleanup 協調；AuthService 不直接開 Hive。使用者初建共用 transaction 邏輯，避免重複建立覆寫既有文件。 | 原有帳號資料清理、readings 儲存策略與 AuthService 文件串流測試；feature 不直接引用另一 feature 的 data 實作。 |
| 6. 表單與圖片 | PetFormController 共用選圖、上傳、身分檢查與儲存；表單可直接注入 controller。AvatarImageLoader 共用載入／錯誤／空 URL／請求世代；非同步 UI 完成前檢查 mounted，保存途中防重複點擊。 | 空 URL、舊請求晚回、dispose、無全域登入的表單保存、衝突草稿、關閉後保存完成不 setState。 |
| 7. 品質基準 | scratch 歷史診斷及 tools/maintenance 維運腳本明確排除正式分析；清理 error、warning、lint、舊 null 運算及 deprecated UI API；fallback 測試不再 mock sealed Query。 | analyze 0 項診斷；新增結構邊界測試。 |
| 8. 目錄與舊入口 | app 包含 DI/theme；auth/home/profile/onboarding 畫面歸入 feature；readings 擁有列表／詳情。維運腳本移 tools/maintenance。移除無引用 ReadingModel／DummyScreen。後端通用 validation/errors 從 credit_logic 抽離，保留相容匯出。 | 所有引用通過 analyze、完整 Flutter 測試與 Web release build；後端純邏輯測試通過。 |

## 驗證結果

- `flutter analyze --no-pub`：**No issues found**，exit 0（原始基準 146 項）。
- `flutter test --no-pub --reporter expanded`：**97 個通過**。
- `flutter build web --release --no-pub`：成功，輸出 `build/web`；Wasm dry run 成功。
- `node --test functions/test/*.test.js`：**12 個通過**。
- `git diff --check`：通過。
- 依使用者追加要求安裝後端既有相依套件（含 ESLint 8.57.1），產生 `functions/package-lock.json`；`node node_modules/eslint/bin/eslint.js .` 通過，0 errors / 0 warnings。安裝停用 lifecycle scripts，node_modules 不納入 Git。

Flutter 指令以現有 `C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe` 搭配 `flutter_tools.snapshot` 執行，沒有升級 SDK 或套件。

後端安裝使用專案 scratch 內的 npm 10.9.4。現有 Node 為 24，functions 宣告部署 runtime 為 Node 20，因此安裝出現 engine 警告；沒有變更部署 runtime。ESLint 沿用 package.json 的 8.x 範圍，沒有在此次結構整理中升級 lint 規則或 Firebase SDK 主版本。

## 可回復性與範圍

- 來源碼與測試以 Git 提交保存；可使用 `git revert` 回復該次提交。
- 搬檔前額外保留當時 lib/test 及後端來源於 `scratch/structure_backup_before_moves`。這是未追蹤的本機備份，不納入產品提交。
- 原先使用者的 scratch 檔案及原始檢查報告均保留；一次性轉換腳本及執行紀錄亦留在 scratch。
- 本次沒有執行 Android/iOS 裝置測試、正式 Firebase 寫入、付費或 AI 真實串接驗證，也沒有推送或部署。Web 編譯與替身測試的成功不代表這些平台／正式串接已驗收。
