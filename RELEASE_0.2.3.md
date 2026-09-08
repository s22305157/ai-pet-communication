# PAWLINK 0.2.3 發布紀錄

2026-09-08 已部署至 https://fir-project-tw.web.app 。

- Web 版本、個人頁、設定頁與 README 更新為 0.2.3。
- 9 個 Node.js 22 Functions 全部發布成功，包含新建 `communicateWithPet`。
- 依使用者授權啟用 `AI_ENABLED=true`、`AI_ALL_AUTHENTICATED=true`，向所有有效登入會員開放；保留每 UID 每分鐘 5 次、每日 30 次及全站每日 100 次上限。
- Plus：`gpt-5.4-mini`，Secret `OPENAI_API_KEY` 第 1 版；Pro：`gpt-5.6-luna`，獨立 Secret `OPENAI_API_KEY_PRO` 第 1 版。Free 暫沿用 mini 與原金鑰。
- 金鑰由 Secret Manager 提供給後端；部署工具已為執行服務帳號授予這兩個 Secret 的讀取權限，未讀出金鑰內容。
- 費用精算前不預留、不扣點、不結算；舊 reserve／settle API 拒絕新操作，既有退款路徑保留。
- 後端安全分流、知識檢索、結構化輸出驗證、重複請求防護及帳號隔離已包含於發布內容。

## 驗證

- ESLint、37 項後端測試、115 項 Flutter 測試通過，靜態分析無問題。
- Web release 建置與 Hosting 發布成功。
- 公開首頁、version.json、main.dart.js 皆 HTTP 200；version.json 回報 0.2.3。
- 線上 main.dart.js SHA-256 與本機建置一致：`ff2e9eff72ec2ea043c5e70de965c619c1c61ed553ed2525ea663fecabd0b875`。
- 回查線上函式的啟用開關、會員開放範圍、模型與 Secret 綁定符合設定。
- 未登入呼叫 communicateWithPet 回應 HTTP 401 / UNAUTHENTICATED。
- 未進行登入後的真實 OpenAI 生成測試，尚未驗證金鑰的實際模型存取權與生成品質；未驗證 Android/iOS 裝置。

證據：`scratch/release_023_functions_deploy.txt`、`scratch/release_023_hosting_deploy.txt`、`scratch/release_023_runtime.json`、`scratch/release_023_verification.json`、`scratch/release_023_lint.txt`、`scratch/release_023_backend.txt`、`scratch/release_023_analyze.txt`、`scratch/release_023_tests.txt`、`scratch/release_023_build.txt`。

本次未建立 Git commit 或推送 GitHub；發布的是此工作目錄已驗證的建置與後端內容。

## 2026-09-09 瀏覽器實測修正

- 發現先前 Web 編譯快取中的外掛註冊檔未包含 FirebaseFunctionsWeb，導致刪除毛孩與 AI 呼叫未送至後端。清理產物、依鎖定版本重新取得套件並建置後，已確認註冊檔包含 Functions。
- 舊 service worker 仍會載入舊程式，故新增版本化 bootstrap 與 main.dart.js 載入網址，已重新部署 Hosting。後續發布如改動程式，須同步更新 web/index.html 與 web/flutter_bootstrap.js 的 release 標記。
- 使用者瀏覽器確認載入 `main.dart.js?release=0.2.3-functions`，並出現 Firebase Functions 初始化訊息。
- 實際建立「刪除功能測試」毛孩後刪除成功；重新載入仍只顯示原有球球，測試資料未復活。餘額維持 15 PT。
- 9 項後端安全處理測試及 6 項 Flutter 毛孩清理／同步測試通過。證據：scratch/live_delete_backend_tests.txt、scratch/live_delete_flutter_tests.txt、scratch/live_ai_hosting_cache_fix.txt。
- Zena 故事測試檔案尚在填寫，依使用者指示交由其先完成。真實 AI 生成尚未成功，不宣稱已驗證 Pro 模型或金鑰可用性。

### Zena 登入後生成實測完成

2026-09-09 00:32（台北時間），依使用者授權完成 Zena 檔案並儲存；個性只保留性格與行為描述。生日 2022-07-01、體重 30 kg 為模擬值，已在測試故事中標明。

- 使用實際登入的 Pro 帳號，送出頁面計數 532 字的故事與兩個飼主提問。
- 瀏覽器顯示真實生成的結構化結果，逐題回答散步壓力及日常信任建立，並明確標示心語為推測。
- 返回 Zena 檔案，確認溝通紀錄已保存，回覆標記 `version: openai-1`、`inputMode: pro`。
- 返回首頁，餘額維持 15 PT，球球及 Zena 均保留。此次尚未實測 Free／Plus 帳號。
- 故事參考 Dogs Trust： https://www.dogstrust.org.uk/about-us/what-we-do/stories/zena 。第一人稱飼主敘述為測試改寫。

### 對話呈現與複製修正

- 已部署 Hosting 與 communicateWithPet 更新，入口 release 標記為 `0.2.3-dialogue`。
- 歷史 JSON 以共用對話元件顯示，列表改用可讀摘要，隱藏內部來源代碼；舊答案的括號聲明僅在呈現時清理，原始紀錄保留。
- 移除重複推測提醒，保留「AI 毛孩對話」名稱；後端提示改為自然第一人稱，專業照護與急症內容仍保留。
- 新結果及歷史紀錄皆有「複製回覆」，輸出提問、毛孩回覆與照護重點的純文字；一般回覆亦可選取。
- 5 項 Flutter 格式／複製／架構測試、16 項 AI 後端測試、靜態分析及 Web build 通過。
- 瀏覽器已核對 Zena 舊紀錄無 JSON／括號提醒，並點擊複製按鈕看到「已複製回覆」。瀏覽器工具的剪貼簿讀取仍回傳先前由工具貼入的內容，故未宣稱已用該工具核對系統剪貼簿；純文字序列化由測試驗證。未再進行付費生成來驗證新提示詞語氣。
- 證據：scratch/dialogue_tests.txt、scratch/dialogue_backend_tests.txt、scratch/dialogue_analyze_final.txt、scratch/dialogue_build.txt、scratch/dialogue_hosting_deploy.txt、scratch/dialogue_functions_deploy.txt。

### 毛孩語氣調整

依公開案例的對話節奏调整後端提示，經兩輪 Zena 同故事同題的 Pro 實測，第二輪毛孩段落已改成短句表達需要，完整照護指標另列。16 項後端測試通過，communicateWithPet 已部署；參考來源、限制及實際回覆記於 AI_VOICE_STYLE.md。未重新寫入或覆蓋舊紀錄，新的生成才使用新語氣。
