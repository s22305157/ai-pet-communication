// lib/features/chat/domain/ai_safe_response_model.dart
// ============================================================
// PAWLINK - AI 安全版回應模型 (Safe Response Model)
// ============================================================

import 'dart:convert';

class AiSafeResponseModel {
  final String version;
  final String mode;
  final String disclaimer;
  final SafePetVoice petVoice;
  final List<String> knowledgeTips;
  final SafetyAlert safetyAlert;
  final List<String> nextSteps;
  final double confidence;
  final bool needsMoreInfo;
  final List<String>? missingInfo;
  final List<String>? tags;

  const AiSafeResponseModel({
    required this.version,
    required this.mode,
    required this.disclaimer,
    required this.petVoice,
    required this.knowledgeTips,
    required this.safetyAlert,
    required this.nextSteps,
    required this.confidence,
    required this.needsMoreInfo,
    this.missingInfo,
    this.tags,
  });

  factory AiSafeResponseModel.fromMap(Map<String, dynamic> map) {
    return AiSafeResponseModel(
      version: map['version'] ?? '1.0',
      mode: map['mode'] ?? 'safe_default',
      disclaimer: map['disclaimer'] ?? '',
      petVoice: SafePetVoice.fromMap(map['pet_voice'] ?? {}),
      knowledgeTips: List<String>.from(map['knowledge_tips'] ?? []),
      safetyAlert: SafetyAlert.fromMap(map['safety_alert'] ?? {}),
      nextSteps: List<String>.from(map['next_steps'] ?? []),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      needsMoreInfo: map['needs_more_info'] ?? false,
      missingInfo: map['missing_info'] != null ? List<String>.from(map['missing_info']) : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'mode': mode,
      'disclaimer': disclaimer,
      'pet_voice': petVoice.toMap(),
      'knowledge_tips': knowledgeTips,
      'safety_alert': safetyAlert.toMap(),
      'next_steps': nextSteps,
      'confidence': confidence,
      'needs_more_info': needsMoreInfo,
      if (missingInfo != null) 'missing_info': missingInfo,
      if (tags != null) 'tags': tags,
    };
  }

  String toJson() => json.encode(toMap());
}

class SafePetVoice {
  final String text;
  final String tone;
  final bool isInference;

  const SafePetVoice({
    required this.text,
    required this.tone,
    required this.isInference,
  });

  factory SafePetVoice.fromMap(Map<String, dynamic> map) {
    return SafePetVoice(
      text: map['text'] ?? '',
      tone: map['tone'] ?? 'neutral',
      isInference: map['is_inference'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'tone': tone,
      'is_inference': isInference,
    };
  }
}

class SafetyAlert {
  final bool hasRedFlags;
  final String message;
  final List<String>? redFlags;

  const SafetyAlert({
    required this.hasRedFlags,
    required this.message,
    this.redFlags,
  });

  factory SafetyAlert.fromMap(Map<String, dynamic> map) {
    return SafetyAlert(
      hasRedFlags: map['has_red_flags'] ?? false,
      message: map['message'] ?? '',
      redFlags: map['red_flags'] != null ? List<String>.from(map['red_flags']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'has_red_flags': hasRedFlags,
      'message': message,
      if (redFlags != null) 'red_flags': redFlags,
    };
  }
}
