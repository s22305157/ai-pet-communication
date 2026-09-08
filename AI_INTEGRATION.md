# OpenAI 接入準備（2026-09-08）

已實作 Firebase callable `communicateWithPet` 與 Flutter 呼叫端。0.2.3 發布設定依使用者授權開放所有有效登入會員（`AI_ENABLED=true`、`AI_ALL_AUTHENTICATED=true`）。程式與範例預設仍關閉，避免其他環境意外啟用。第一階段僅支援文字，媒體輸入會明確拒絕。

## 會員模型分流

Plus 使用已建立的 Secret Manager `OPENAI_API_KEY`（使用者提供的 GPT-5.4 mini 金鑰），Pro 使用獨立的 `OPENAI_API_KEY_PRO`（GPT-5.6 Luna）。不需要另建 `OPENAI_API_KEY_PLUS`。後端按已驗證的會員等級取用，缺少對應金鑰即拒絕生成；Plus／Pro 不互借金鑰。Free 暫沿用同一個 GPT-5.4 mini 金鑰。金鑰值不寫入程式碼、請求紀錄或回覆。

| 會員等級 | 後端設定 | 預設模型 | 點數 |
| --- | --- | --- | --- |
| Free | `OPENAI_MODEL_FREE` | `gpt-5.4-mini` | 待費用精算，目前不預留／扣點 |
| Plus | `OPENAI_MODEL_PLUS` | `gpt-5.4-mini` | 待費用精算，目前不預留／扣點 |
| Pro | `OPENAI_MODEL_PRO` | `gpt-5.6-luna` | 待費用精算，目前不預留／扣點 |

Plus、Pro 型號依使用者指定。Free 暫沿用文字模型，可單獨修改或留空關閉。會員等級只讀取 Firestore `users/{uid}.membershipTier`；前端提交的模式、模型名稱與提示詞不能決定模型或權限。任一方案模型設為空字串即拒絕該方案；不跨方案降級或替換模型。

官方模型資料：[GPT-5.4 mini](https://developers.openai.com/api/docs/models/gpt-5.4-mini)、[GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna)。兩者支援 Responses API 與 Structured Outputs；實際帳號的模型存取權仍須用正式專案金鑰驗證。

## 呼叫流程（收費待設定）

1. Flutter 傳送 `{requestId, petId, request}`，不傳可信 system/developer 訊息。Firebase SDK 提供登入 token。
2. 後端檢查啟用開關、開放範圍（全體登入會員或 UID 名單）、有效帳號、毛孩擁有權／刪除狀態、會員等級。Free 的本機毛孩可沒有雲端父檔案；Plus／Pro 必須先同步。
3. Firestore transaction 鎖定 request ID 與請求雜湊，限制同 UID 每分鐘 5 次、每日 30 次，全站每日 100 次。日期以 UTC 切換；Pro 也受限。
4. 後端重新判斷安全路由並檢索知識庫，送出 OpenAI Responses API。使用固定後端指令、嚴格 JSON schema、45 秒 timeout、最多 3000 output tokens，`store: false`。此參數不代表供應商完全不保留任何安全或濫用監測資料。
5. 格式驗證成功後保存回覆快取。相同 ID 重送取回原結果，不重新呼叫模型；失敗 ID 不重做生成，需重新開始。request ID 僅供去重，不是點數預留編號。
6. 急症直接回傳本機規則對應的就醫提醒，不呼叫 OpenAI，不改動點數餘額。這不是模型生成的診斷。
7. 費用精算完成前，所有方案都不要求點數餘額、不預留、不扣點、不結算。舊 reserve／settle API 也會拒絕新操作；release 與逾期退款僅保留處理歷史預留，不會建立新收費。正式費率未設定，不提供可誤啟用的計費開關。
8. 成功回覆後沿用既有 ReadingService 儲存紀錄；儲存失敗可以只重試儲存，不再次呼叫模型。切換帳號時捨棄進行中的舊帳號回覆。

目前 `users/{uid}/aiRequests/{requestId}` 保留成功結果供去重重試，並記錄所用模型與會員等級，供管理者核對分流；前端無直接讀寫權限。帳號刪除會遞迴清除。刪除毛孩後後端拒絕重取，但快取仍隨帳號保存。正式大規模開放前，應決定快取保存期限與逾期清理策略。

## 啟用步驟

先在 Firebase／OpenAI 的管理介面準備專案金鑰、API 計費與模型存取權，不要把金鑰放在 Flutter、Git、`.env` 範例或對話中。

```powershell
firebase functions:secrets:set OPENAI_API_KEY --project fir-project-tw
firebase functions:secrets:set OPENAI_API_KEY_PRO --project fir-project-tw
```

指令會互動要求輸入金鑰。既有知識檢索也需要 `KB_ENCRYPTION_KEY`；本次未更動該 secret。複製 `functions/.env.example` 為 `functions/.env.fir-project-tw`，填入允許測試的 Firebase Auth UID（逗號分隔）。當 `AI_ALL_AUTHENTICATED=false` 時，空白 UID 名單拒絕所有帳號，不支援 `*`。0.2.3 正式環境依使用者授權設為 `AI_ALL_AUTHENTICATED=true`，因此不限制 UID 名單。先維持 `AI_ENABLED=false` 完成部署檢查，再改為 `true` 並重新部署開放指定測試帳號。

```powershell
firebase deploy --project fir-project-tw --only functions:communicateWithPet,functions:reserveCommunicationCredit,functions:settleCommunicationCredit,functions:releaseCommunicationCredit,functions:releaseExpiredCommunicationCredits
flutter build web --release --no-pub
firebase deploy --project fir-project-tw --only hosting
```

前端與 credit handlers 應搭配此次後端一起部署，避免舊版結算流程與新後端混用。既有 Firestore/Storage 安全修正須已上線。要停止新 AI 請求，將 `AI_ENABLED=false` 後重新部署；在途請求可能仍完成。

## 驗證範圍

原接入驗證及本次停用收費驗證分開保存；本次輸出位於 `scratch/ai_no_billing_backend.txt`、`scratch/ai_no_billing_tests.txt`、`scratch/ai_no_billing_analyze.txt`。

自動化測試涵蓋：會員分流／偽造模型、登入及帳號隔離、空模型拒絕、毛孩權限、零點數／無預留亦可呼叫、停用預留與结算 API、重複送出、用量上限、模型錯誤與拒答、結構化輸出、急症免模型且不改動點數、Flutter 傳輸、成功與 fallback 均不計費。

這些是本機測試，不能替代真實 Firebase transaction 競爭測試或模型回覆品質評估。啟用後需以 Free／Plus／Pro 各測一筆，確認實際模型、點數餘額維持不變、中文輸出、知識引用及紀錄保存；再測斷網重試與切換帳號。尚未驗證 Android／iOS 裝置或真實付費 API。目前已依使用者指示開放所有有效登入會員；如需縮小範圍，可將 `AI_ALL_AUTHENTICATED=false` 並設定 UID 名單後部署。

API 格式依據：[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)。
