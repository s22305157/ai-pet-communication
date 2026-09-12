# 維運腳本

此目錄保留原 `lib/scripts` 的一次性帳號維運程式，不是 Flutter app 的入口。
正式 analyze 排除此目錄；需要執行時應另行檢查腳本所指向的 Firebase 專案及資料範圍。

產品品質關卡：`flutter analyze --no-pub`、`flutter test --no-pub`、`flutter build web --release --no-pub`。

Windows Chrome 自動測試可用 `./tools/maintenance/test-chrome.ps1`，預設執行 M4 測試。以 `-FlutterSdk` 指定 SDK，或用 `-TestPaths @('test/features/pilot_m4_test.dart', 'test/features/journal_m23_test.dart')` 選擇測試。腳本明確使用 Flutter 工具自己的套件設定，避免直接執行預製快照時讀到錯誤路徑；它不更改 SDK 或應用程式資料。

跨平台執行入口為 `dart tools/maintenance/chrome_test_runner.dart <Flutter SDK 路徑> <測試檔案...>`。它先執行一項原生啟動測試，更新 Flutter 資產包，再用隨機本機連接埠唯讀提供該包，結束時關閉服務。`test/flutter_test_config.dart` 只在 Chrome 設定資產讀取橋接；圖片使用真實檔案，字型使用 Flutter 標準測試字型 Ahem，因此這些測試不代表正式字型的視覺驗收。直接執行 `flutter test --platform chrome` 不會啟動資產服務，照片／圖卡回歸請使用上述入口。

本機 Web 產物檢查：先完成 release build，再執行 `node tools/maintenance/pilot-release-check.cjs`。此工具核對版本、快取識別、M4 編譯內容與雜湊，不會部署。
