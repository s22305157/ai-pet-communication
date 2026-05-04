// lib/features/chat/domain/ai_response_model.dart
// ============================================================
// PAWLINK - AI 回應模型 (Domain Model)
// ============================================================

import 'dart:convert';

/// AI 寵物溝通回應模型
class AiResponseModel {
  /// 寵物心語列表 (1~5 筆)
  final List<PetVoiceItem> petVoice;

  /// 知識補給站
  final KnowledgeStation knowledgeStation;

  /// 本次溝通總結
  final String summary;

  /// 主題標籤
  final List<String> tags;

  /// 信心值 (0.0 ~ 1.0)
  final double confidence;

  /// 語氣 (warm, gentle, calm, encouraging)
  final String tone;

  /// 版本號
  final String version;

  /// 輸入模式 (free, pro)
  final String inputMode;

  const AiResponseModel({
    required this.petVoice,
    required this.knowledgeStation,
    required this.summary,
    required this.tags,
    required this.confidence,
    required this.tone,
    required this.version,
    required this.inputMode,
  });

  /// 從 Map 建立模型
  factory AiResponseModel.fromMap(Map<String, dynamic> map) {
    return AiResponseModel(
      petVoice: (map['petVoice'] as List)
          .map((item) => PetVoiceItem.fromMap(item))
          .toList(),
      knowledgeStation: KnowledgeStation.fromMap(map['knowledgeStation']),
      summary: map['summary'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      tone: map['tone'] ?? 'warm',
      version: map['version'] ?? 'unknown',
      inputMode: map['inputMode'] ?? 'free',
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'petVoice': petVoice.map((x) => x.toMap()).toList(),
      'knowledgeStation': knowledgeStation.toMap(),
      'summary': summary,
      'tags': tags,
      'confidence': confidence,
      'tone': tone,
      'version': version,
      'inputMode': inputMode,
    };
  }

  /// 轉換為 JSON 字串
  String toJson() => json.encode(toMap());

  /// 安全版預設回應 (Fallback)
  factory AiResponseModel.safeFallback({String? error}) {
    return AiResponseModel(
      petVoice: [
        const PetVoiceItem(
          question: "...",
          answer: "對不起，我剛剛稍微分神了。雖然現在連結有點弱，但我依然能感受到你對我的愛。我們先休息一下吧，等等再聊。",
        ),
      ],
      knowledgeStation: const KnowledgeStation(
        title: "靜心連結",
        content: "有時候溝通不順暢是正常的，保持平靜的心情，能讓之後的連結更穩定。",
      ),
      summary: error ?? "連結暫時中斷，回傳預設回應。",
      tags: ["連結中斷", "系統預設"],
      confidence: 0.1,
      tone: "warm",
      version: "fallback-1",
      inputMode: "free",
    );
  }
}

/// 寵物心語單一項目
class PetVoiceItem {
  final String question;
  final String answer;

  const PetVoiceItem({
    required this.question,
    required this.answer,
  });

  factory PetVoiceItem.fromMap(Map<String, dynamic> map) {
    return PetVoiceItem(
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

/// 知識補給站
class KnowledgeStation {
  final String title;
  final String content;

  const KnowledgeStation({
    required this.title,
    required this.content,
  });

  factory KnowledgeStation.fromMap(Map<String, dynamic> map) {
    return KnowledgeStation(
      title: map['title'] ?? '',
      content: map['content'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
    };
  }
}
