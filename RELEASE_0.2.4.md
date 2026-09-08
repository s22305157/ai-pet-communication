# PAWLINK 0.2.4

此 Git 版本整合 0.2.2 起已在本機完成的安全、同步、OpenAI 接入與對話介面修正。

- Plus／Pro 由後端選擇模型與獨立 Secret；有效登入會員可使用，費用精算前不预留或扣點。
- 修正 Web Functions 外掛註冊及舊快取問題；版本與載入網址統一為 0.2.4。
- 歷史紀錄以對話格式呈現，可複製純文字回覆，並使用自然的毛孩口吻。
- 帳號隔離、刪除及同步修復與回歸測試一併納入。

先前正式環境已用 Pro 帳號驗證 Zena 實際生成及紀錄保存，餘額維持 15 PT；測試毛孩刪除後重新載入未復活。Free／Plus 實際生成及 Android／iOS 裝置尚未驗證。

本次依使用者要求更新版本、推送 Git 並部署 Firebase Hosting 0.2.4。API 金鑰仍只由 Secret Manager 保存，本機 runtime env、暫存資料及部署紀錄不納入提交。

驗證：119 項 Flutter 測試、37 項後端測試、Flutter 靜態分析與後端 ESLint 通過。
