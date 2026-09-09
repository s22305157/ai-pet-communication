// lib/features/chat/domain/ai_response_model.dart
// ============================================================
// PAWLINK - AI 回應模型 (Domain Model)
// ============================================================

import 'dart:convert';

/// AI 寵物溝通回應模型
class AiResponseModel {
  final List<String> matchedCardIds;
  final List<String> newCardIds;

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
    this.matchedCardIds = const [],
    this.newCardIds = const [],
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
      matchedCardIds: List<String>.from(
        map['planetAward']?['matchedCardIds'] ?? [],
      ),
      newCardIds: List<String>.from(map['planetAward']?['newCardIds'] ?? []),
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
      'planetAward': {
        'matchedCardIds': matchedCardIds,
        'newCardIds': newCardIds,
      },
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
          answer: "AI 服務目前無法完成回覆，請稍後再試。這段文字是系統提示，並非 AI 分析結果。",
        ),
      ],
      knowledgeStation: const KnowledgeStation(
        title: "服務暫時無法使用",
        content: "若毛孩有身體不適或急症警訊，請直接聯絡獸醫，不要等待 AI 回覆。",
      ),
      summary: "AI 服務暫時無法使用。",
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

  const PetVoiceItem({required this.question, required this.answer});

  factory PetVoiceItem.fromMap(Map<String, dynamic> map) {
    return PetVoiceItem(
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'question': question, 'answer': answer};
  }
}

/// 知識補給站
class KnowledgeStation {
  final String title;
  final String content;

  const KnowledgeStation({required this.title, required this.content});

  factory KnowledgeStation.fromMap(Map<String, dynamic> map) {
    return KnowledgeStation(
      title: map['title'] ?? '',
      content: map['content'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'title': title, 'content': content};
  }
}
