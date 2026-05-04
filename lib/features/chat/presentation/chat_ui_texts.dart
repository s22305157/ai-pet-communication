// lib/features/chat/presentation/chat_ui_texts.dart
// ============================================================
// PAWLINK - 聊天介面文案 (UI Texts)
// ============================================================

class ChatUiTexts {
  // ── 1. 頂部提示 ───────────────────────────────────────────
  static const String safeModeTitle = "安全模式已開啟";
  static const String safeModeSubtitle = 
      "目前會先依據你提供的文字資訊，做保守推測與照護提醒。這不是醫療診斷，也不是影像判讀。若毛孩看起來不舒服，請優先尋求獸醫協助。";

  // ── 2. 區塊標題與副標題 ──────────────────────────────────────
  
  // 毛孩心語
  static const String petVoiceTitle = "毛孩心語";
  static const String petVoiceSubtitle = "這是一段依目前資訊做出的推測，不是毛孩真正的心聲。";

  // 毛孩知識補給站
  static const String knowledgeTipsTitle = "毛孩知識補給站";
  static const String knowledgeTipsSubtitle = "先幫你整理一些簡單、實用的照護小提醒。";

  // 安全提醒
  static const String safetyAlertTitle = "安全提醒";
  static const String safetyAlertSubtitle = "如果有不舒服的警訊，請不要拖延，盡快聯絡獸醫。";

  // 下一步建議
  static const String nextStepsTitle = "下一步建議";
  static const String nextStepsSubtitle = "你也可以再補充一些觀察，讓結果更貼近毛孩現在的狀況。";

  // ── 3. 空狀態文案 ──────────────────────────────────────────
  static const String emptyInfoTitle = "目前資訊還不夠完整";
  static const String emptyInfoSubtitle = "沒關係，我先陪你一起看。\n你可以補充毛孩的精神、食慾、排泄、活動力，或最近有沒有特別異常。";

  // ── 4. 紅旗提醒文案 ──────────────────────────────────────────
  static const String redFlagTitle = "這裡有需要留意的地方";
  static const String redFlagContent = 
      "如果毛孩出現呼吸急促、持續嘔吐、抽搐、站不穩、血便、血尿或明顯疼痛，請盡快聯絡獸醫或就近就醫。";

  // ── 5. 結尾補充文案 ──────────────────────────────────────────
  static const String footerNote = "以上內容是根據文字資訊做出的安全推測，不是醫療診斷，也不是影像判讀。";

  // ── 6. 按鈕文案 ───────────────────────────────────────────
  static const String btnAddInfo = "補充觀察資訊";
  static const String btnReAnalyze = "重新分析";
  static const String btnShowSafetyAlert = "查看安全提醒";
}
