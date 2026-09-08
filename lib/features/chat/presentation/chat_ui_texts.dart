// lib/features/chat/presentation/chat_ui_texts.dart
// ============================================================
// PAWLINK - 聊天介面文案 (UI Texts)
// ============================================================

class ChatUiTexts {
  // ── 1. 頂部提示 ───────────────────────────────────────────
  static const String safeModeTitle = "安全模式已開啟";
  static const String safeModeSubtitle =
      "分享毛孩最近的生活，讓 AI 對話更貼近你們的相處。";

  // ── 2. 區塊標題與副標題 ──────────────────────────────────────

  // 毛孩心語
  static const String petVoiceTitle = "AI 毛孩對話";
  static const String petVoiceSubtitle = "";

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
  static const String emptyInfoSubtitle =
      "沒關係，我先陪你一起看。\n你可以補充毛孩的精神、食慾、排泄、活動力，或最近有沒有特別異常。";

  // ── 4. 紅旗提醒文案 ──────────────────────────────────────────
  static const String redFlagTitle = "這裡有需要留意的地方";
  static const String redFlagContent =
      "如果毛孩出現呼吸急促、持續嘔吐、抽搐、站不穩、血便、血尿或明顯疼痛，請盡快聯絡獸醫或就近就醫。";

  // ── 5. 結尾補充文案 ──────────────────────────────────────────
  static const String footerNote = "";

  // ── 6. 按鈕文案 ───────────────────────────────────────────
  static const String btnAddInfo = "補充觀察資訊";
  static const String btnReAnalyze = "重新分析";
  static const String btnShowSafetyAlert = "查看安全提醒";
}
