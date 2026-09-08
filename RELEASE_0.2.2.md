# PAWLINK 0.2.2 發布紀錄

2026-09-08 已部署至 https://fir-project-tw.web.app 。

- pubspec、個人頁、設定頁與 README 更新為 0.2.2。
- Web release build 成功，Hosting 發布成功。
- 8 個 Functions 全部成功更新為 Node.js 22。
- Firestore／Storage 規則編譯及發布成功。
- 經使用者明確授權，為 Storage 服務代理新增 `roles/firebaserules.firestoreServiceAgent`；回查確認角色存在，其他 IAM 綁定保留。
- 線上首頁、version.json、main.dart.js 皆 HTTP 200；version.json 為 0.2.2，main.dart.js 的 SHA-256 與本機建置一致。
- 未登入呼叫 /cors-proxy 回應 HTTP 401，符合預期。
- 加密知識庫經解密驗證與檢索 smoke test 通過，保留知識庫版本 0.1.9；沒有發布解密內容。

本次沿用已通過的 106 項 Flutter、19 項後端、11 項依賴補丁及 6 組規則測試結果；版本文字更新後重新執行 Web 正式建置與公開端点檢查。

測試工具的版本鎖定補丁仍需保留，npm audit 依原始套件版號仍列出 4 個 Moderate；不代表掃描歸零。

執行證據：

- `scratch/release_022_build.txt`
- `scratch/release_022_deploy.txt`
- `scratch/release_022_verification.json`

本次未建立 Git commit 或推送 GitHub。
