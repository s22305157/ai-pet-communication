# 自動發卡（本機實作，待部署）

- `functions/planet_cards.js` 維護 001–020 的確定性規則。只比對後端回覆的 `knowledgeStation.content` 或 `knowledge_tips`，同一句需同时符合主題和照護概念。不是隨機抽卡，也不使用使用者輸入、心語或標籤直接發卡。
- 目前只支援貓；無對應概念、急症或有紅旗的安全回覆不發卡。保守文字規則可能漏掉未涵蓋的同義表述；新增卡片需同步新增規則和語句測試。
- 完成 AI 請求時，在同一 Firestore transaction 建立 `users/{uid}/planetCards/{cardId}`，並將 `planetAward` 收據存入 AI 請求。每張卡只建立一次，保存首次請求、毛孩與時間；同 requestId 重試回傳原收據。
- 收藏由 Admin SDK 寫入。Firestore Rules 僅允許有效帳號讀取自己的收藏，禁止所有用戶端寫入。刪除帳號既有的 recursiveDelete 會一併刪除收藏。
- 結果頁顯示本次命中的卡與本次新收藏標示；收據跟隨溝通紀錄保存。圖鑑即時讀取帳號收藏，未收藏卡仍可預覽。切換帳號會重新建立收藏訂閱。
- 舊溝通不追溯補發。上線需一併部署 Functions、Firestore Rules 與新版前端；此變更尚未部署。
- 各卡 JSON 中原先的 `status` 是生成時的紀錄，本文件記載後續接入狀態。
