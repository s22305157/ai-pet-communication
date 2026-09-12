class ReviewStatement {
  final String text;
  final List<String> entryIds;
  ReviewStatement({required this.text, required List<String> entryIds})
    : entryIds = List.unmodifiable(entryIds);
}

class ReviewResult {
  final List<ReviewStatement> happenings, observations, tips;
  final String petVoice;
  ReviewResult({
    required List<ReviewStatement> happenings,
    required List<ReviewStatement> observations,
    required List<ReviewStatement> tips,
    required this.petVoice,
  }) : happenings = List.unmodifiable(happenings),
       observations = List.unmodifiable(observations),
       tips = List.unmodifiable(tips);
}

class ReviewSource {
  final String context, observation, action, outcome;
  const ReviewSource({
    required this.context,
    required this.observation,
    required this.action,
    required this.outcome,
  });
}

class WeeklyReview {
  final String status, safetyMessage;
  final int days, entries, textDays, attempts, trialEndsAtMs;
  final bool analysisEnabled, canGenerate;
  final ReviewResult? result;
  const WeeklyReview({
    required this.status,
    required this.safetyMessage,
    required this.days,
    required this.entries,
    required this.textDays,
    required this.attempts,
    required this.trialEndsAtMs,
    required this.analysisEnabled,
    required this.canGenerate,
    required this.result,
  });
  String get message => switch (status) {
    'ready' => '回顧依據你留下的文字整理。觀察是 AI 推測，可點開原始紀錄核對。',
    'processing' => '回顧處理中，稍後重新整理即可查看。',
    'invalidated' => '來源日記已變更，舊回顧已隱藏。',
    'failed' => '這次回顧未完成，可在剩餘次數內重試。',
    'safety' => '紀錄中有身體警訊，本週只顯示統計。',
    'insufficient' => '至少需要三個不同日期的文字紀錄，才會生成回顧。',
    _ => '每週一 08:30 整理前一個完整週一至週日，也可手動產生已結束週次的回顧。',
  };
}
