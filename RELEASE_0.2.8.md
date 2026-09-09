# PAWLINK 0.2.8

本次安全修正維持版本號 0.2.8，發布範圍為 Web Hosting、Functions 及 Firestore／Storage 規則與索引。

- 私人毛孩日記：受邀資格、文字紀錄、照片處理、時間軸、容量限制與匯出／刪除。
- 帳號刪除使用持久化工作及自動重試，完成資料清理後才刪除 Auth。
- 關閉原始知識片段擷取介面，保留後端 AI 知識檢索。
- 日記加入帳號與全站配額、草稿加密及登出清除；刪除後可立即重建日記毛孩。
- 日記 API 型別化並拆分後端權限、圖片、紀錄與清理職責。

本機驗證：Flutter 3.41.7 分析 0 issue、146 項測試、Web release build；Node 22 測試 70 項、日記模擬器 16 項、Rules 9 項、Functions 正式依賴 audit 0 漏洞。

App Check 正式強制驗證需完成用戶端註冊與監控；最新版 stable CI、Android／iOS 實機驗證仍待完成。AI 每週回顧、同伴圈與金流不在本版範圍。
