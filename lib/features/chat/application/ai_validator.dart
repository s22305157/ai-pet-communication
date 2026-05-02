// lib/features/chat/application/ai_validator.dart
// ============================================================
// PAWLINK - AI 驗證器 (AiValidator)
// ============================================================

import 'dart:convert';
import '../domain/ai_response_model.dart';
import '../domain/ai_request_model.dart';
import '../domain/ai_safe_response_model.dart';

class AiValidationException implements Exception {
  final String message;
  final dynamic details;
  AiValidationException(this.message, [this.details]);
  @override
  String toString() => 'AiValidationException: $message ${details ?? ""}';
}

class AiValidator {
  // ── 請求驗證 (Request Validation) ─────────────────────────────

  /// 驗證發送給 AI 的 Payload 是否符合 Schema
  static void validateRequest(AiRequestModel request) {
    final json = request.toMap();

    // 檢查必要欄位
    _checkRequiredKeys(json, [
      'ownerProfile',
      'petProfile',
      'story',
      'questions',
      'inputMode',
    ], 'Request');

    // 驗證 questions
    final questions = json['questions'];
    if (questions is! List || questions.isEmpty || questions.length > 5) {
      throw AiValidationException('Request questions must be a list of 1 to 5 items');
    }

    // 驗證 inputMode
    final mode = json['inputMode'];
    if (mode != 'free' && mode != 'pro') {
      throw AiValidationException('Request inputMode must be "free" or "pro"');
    }

    // 驗證 story 長度
    if ((json['story'] as String).length > 5000) {
      throw AiValidationException('Request story exceeds 5000 characters');
    }
  }

  // ── 回應驗證 (Response Validation) ────────────────────────────

  /// 驗證 AI 回傳的內容，並轉換為模型
  /// [rawContent]：AI 回傳的原始字串（可能包含 Markdown）
  static AiResponseModel validateResponse(String rawContent) {
    // 第一層：解析 JSON 與修復
    Map<String, dynamic> jsonMap;
    try {
      jsonMap = _extractAndParseJson(rawContent);
    } catch (e) {
      // 嘗試修復後再解析
      final fixed = tryFixJson(rawContent);
      try {
        jsonMap = _extractAndParseJson(fixed);
      } catch (e2) {
        throw AiValidationException('Failed to parse AI response as JSON after repair', e2);
      }
    }

    // 第二層：Schema / 手動檢查
    _performManualResponseCheck(jsonMap);

    return AiResponseModel.fromMap(jsonMap);
  }

  /// 驗證 AI 安全版回傳的內容，並轉換為模型
  static AiSafeResponseModel validateSafeResponse(String rawContent) {
    Map<String, dynamic> jsonMap;
    try {
      jsonMap = _extractAndParseJson(rawContent);
    } catch (e) {
      final fixed = tryFixJson(rawContent);
      try {
        jsonMap = _extractAndParseJson(fixed);
      } catch (e2) {
        throw AiValidationException('Failed to parse AI safe response as JSON after repair', e2);
      }
    }

    _performManualSafeResponseCheck(jsonMap);

    return AiSafeResponseModel.fromMap(jsonMap);
  }

  /// 嘗試從字串中擷取 JSON 並解析
  static Map<String, dynamic> _extractAndParseJson(String content) {
    String jsonString = content.trim();

    // 處理 Markdown Code Block (```json ... ```)
    final regex = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true);
    final match = regex.firstMatch(jsonString);
    if (match != null) {
      jsonString = match.group(1)!;
    } else {
      // 也有可能只有 ``` ... ```
      final genericRegex = RegExp(r'```\s*([\s\S]*?)\s*```', multiLine: true);
      final genericMatch = genericRegex.firstMatch(jsonString);
      if (genericMatch != null) {
        jsonString = genericMatch.group(1)!;
      }
    }

    return json.decode(jsonString.trim());
  }

  /// 嘗試修復損壞的 JSON
  static String tryFixJson(String rawContent) {
    String fixed = rawContent.trim();
    
    // 1. 如果開頭不是 {，嘗試找第一個 {
    if (!fixed.startsWith('{')) {
      final firstBrace = fixed.indexOf('{');
      if (firstBrace != -1) {
        fixed = fixed.substring(firstBrace);
      }
    }

    // 2. 如果結尾不是 }，嘗試找最後一個 }
    if (!fixed.endsWith('}')) {
      final lastBrace = fixed.lastIndexOf('}');
      if (lastBrace != -1) {
        fixed = fixed.substring(0, lastBrace + 1);
      }
    }

    // 這裡可以加入更多修復邏輯，例如：
    // - 移除末尾多餘的逗號
    // - 補齊未閉合的括號（較複雜）

    return fixed;
  }

  /// 嚴格檢查回應欄位與型別
  static void _performManualResponseCheck(Map<String, dynamic> json) {
    final requiredKeys = [
      'petVoice',
      'knowledgeStation',
      'summary',
      'tags',
      'confidence',
      'tone',
      'version',
      'inputMode',
    ];

    _checkRequiredKeys(json, requiredKeys, 'Response');

    // petVoice 驗證
    final petVoice = json['petVoice'];
    if (petVoice is! List || petVoice.isEmpty || petVoice.length > 5) {
      throw AiValidationException('Response petVoice must be a list of 1 to 5 items');
    }

    for (final item in petVoice) {
      if (item is! Map<String, dynamic>) {
        throw AiValidationException('petVoice item must be a object');
      }
      if (item['question'] is! String || (item['question'] as String).trim().isEmpty) {
        throw AiValidationException('petVoice question cannot be empty');
      }
      if (item['answer'] is! String || (item['answer'] as String).trim().isEmpty) {
        throw AiValidationException('petVoice answer cannot be empty');
      }
    }

    // knowledgeStation 驗證
    final ks = json['knowledgeStation'];
    if (ks is! Map<String, dynamic>) {
      throw AiValidationException('knowledgeStation must be a object');
    }
    if (ks['title'] is! String || (ks['title'] as String).trim().isEmpty) {
      throw AiValidationException('knowledgeStation title cannot be empty');
    }
    if (ks['content'] is! String || (ks['content'] as String).trim().isEmpty) {
      throw AiValidationException('knowledgeStation content cannot be empty');
    }

    // 其他欄位驗證
    if (json['confidence'] is! num || json['confidence'] < 0 || json['confidence'] > 1) {
      throw AiValidationException('confidence must be a number between 0 and 1');
    }

    final allowedTones = ['warm', 'gentle', 'calm', 'encouraging'];
    if (!allowedTones.contains(json['tone'])) {
      throw AiValidationException('Invalid tone: ${json['tone']}');
    }

    if (json['inputMode'] != 'free' && json['inputMode'] != 'pro') {
      throw AiValidationException('inputMode must be "free" or "pro"');
    }
  }

  /// 嚴格檢查安全版回應欄位與型別
  static void _performManualSafeResponseCheck(Map<String, dynamic> json) {
    final requiredKeys = [
      'version',
      'mode',
      'disclaimer',
      'pet_voice',
      'knowledge_tips',
      'safety_alert',
      'next_steps',
      'confidence',
      'needs_more_info'
    ];

    _checkRequiredKeys(json, requiredKeys, 'SafeResponse');

    if (json['mode'] != 'safe_default') {
      throw AiValidationException('SafeResponse mode must be "safe_default"');
    }

    // pet_voice 驗證
    final pv = json['pet_voice'];
    if (pv is! Map<String, dynamic>) throw AiValidationException('pet_voice must be a object');
    _checkRequiredKeys(pv, ['text', 'tone', 'is_inference'], 'pet_voice');
    
    final allowedTones = ['gentle', 'calm', 'supportive', 'neutral'];
    if (!allowedTones.contains(pv['tone'])) {
      throw AiValidationException('Invalid safe tone: ${pv['tone']}');
    }

    // safety_alert 驗證
    final sa = json['safety_alert'];
    if (sa is! Map<String, dynamic>) throw AiValidationException('safety_alert must be a object');
    _checkRequiredKeys(sa, ['has_red_flags', 'message'], 'safety_alert');

    // 陣列長度驗證
    if (json['knowledge_tips'] is! List || (json['knowledge_tips'] as List).isEmpty) {
      throw AiValidationException('knowledge_tips must be a non-empty list');
    }
    if (json['next_steps'] is! List || (json['next_steps'] as List).isEmpty) {
      throw AiValidationException('next_steps must be a non-empty list');
    }

    if (json['confidence'] is! num || json['confidence'] < 0 || json['confidence'] > 1) {
      throw AiValidationException('confidence must be a number between 0 and 1');
    }
  }

  /// 輔助方法：檢查必要 Key
  static void _checkRequiredKeys(Map<String, dynamic> json, List<String> keys, String context) {
    for (final key in keys) {
      if (!json.containsKey(key)) {
        throw AiValidationException('Missing required $context key: $key');
      }
    }
  }
}
