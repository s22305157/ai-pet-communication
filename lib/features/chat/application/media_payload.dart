// lib/features/chat/application/media_payload.dart
// ============================================================
// PAWLINK - AI 媒體資料酬載 (Media Payload)
// 
// 根據方案決定傳入的媒體資訊：
//   free         → null（不傳任何媒體）
//   plus / pro   → imageUrl 或 imageBase64
//   未來影片支援  → videoUrl、videoFrames、videoSummary
// ============================================================

/// 方案等級枚舉
enum InputMode { free, plus, pro }

extension InputModeExtension on InputMode {
  String get value {
    switch (this) {
      case InputMode.free:
        return 'free';
      case InputMode.plus:
        return 'plus';
      case InputMode.pro:
        return 'pro';
    }
  }

  /// 是否有媒體存取權限（plus 以上）
  bool get hasMediaAccess => this == InputMode.plus || this == InputMode.pro;

  static InputMode fromString(String value) {
    switch (value.toLowerCase()) {
      case 'plus':
        return InputMode.plus;
      case 'pro':
        return InputMode.pro;
      default:
        return InputMode.free;
    }
  }
}

/// 媒體資料酬載
/// free 模式下此物件應傳 null，不應傳入任何欄位
class MediaPayload {
  // ── 圖片（plus / pro 支援）───────────────────────────────────
  /// 遠端圖片 URL（優先使用）
  final String? imageUrl;

  /// Base64 編碼圖片（當無法使用 URL 時使用）
  final String? imageBase64;

  // ── 影片（未來支援）─────────────────────────────────────────
  /// 影片遠端 URL
  final String? videoUrl;

  /// 影片關鍵幀截圖（Base64 列表），用於 Vision 模型分析
  final List<String>? videoFrames;

  /// 影片內容的文字摘要（由前端或後端預先生成）
  final String? videoSummary;

  const MediaPayload({
    this.imageUrl,
    this.imageBase64,
    this.videoUrl,
    this.videoFrames,
    this.videoSummary,
  });

  /// 序列化為 JSON Map，供 PromptManager 使用
  Map<String, dynamic> toJson() {
    return {
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (videoFrames != null && videoFrames!.isNotEmpty)
        'videoFrames': videoFrames,
      if (videoSummary != null) 'videoSummary': videoSummary,
    };
  }

  /// 是否包含任何有效的媒體資料
  bool get hasContent =>
      imageUrl != null ||
      imageBase64 != null ||
      videoUrl != null ||
      (videoFrames != null && videoFrames!.isNotEmpty) ||
      videoSummary != null;
}
