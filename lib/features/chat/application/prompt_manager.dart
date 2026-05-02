// lib/features/chat/application/prompt_manager.dart
// ============================================================
// PAWLINK - Prompt 組裝器
// 
// 負責將三層 Prompt 組裝成最終發送給 LLM 的 messages 陣列：
//   [0] system    → AiPrompts.systemInstruction
//   [1] developer → AiPrompts.developerInstruction
//   [2] user      → 動態序列化的 JSON Payload
// ============================================================

import 'dart:convert';
import 'ai_prompts.dart';
import 'ai_validator.dart';
import '../domain/ai_request_model.dart';
import 'media_payload.dart';

import 'package:flutter/foundation.dart';

class PromptBundle {
  final List<Map<String, String>> messages;
  final bool isSafeMode;
  PromptBundle({required this.messages, required this.isSafeMode});
}

class PromptManager {
  /// 建立最終發送給 LLM API 的訊息列表
  ///
  /// [request]：完整的請求模型，包含飼主、毛孩、故事與問題
  static PromptBundle buildMessages(AiRequestModel request) {
    // ── 驗證 Request 是否符合 Schema ──────────────────────────────
    AiValidator.validateRequest(request);

    // ── 判斷是否啟用安全模式 (低資訊或免費版) ────────────────────────
    // 規則：免費版、或是故事內容低於 300 字，自動啟用安全版回應引擎
    final bool isLowInfo = request.story.trim().length < 300;
    final bool useSafeMode = request.inputMode == 'free' || isLowInfo;

    final String systemContent = useSafeMode 
        ? AiPrompts.safeSystemInstruction 
        : AiPrompts.systemInstruction;
        
    final String developerContent = useSafeMode
        ? AiPrompts.safeDeveloperInstruction
        : AiPrompts.developerInstruction;

    // ── 序列化 User Payload 為 JSON 字串 ────────────────────────────
    final Map<String, dynamic> userPayload = request.toMap();
    
    // 嚴格規則：若啟用安全模式 (低資訊或免費版)，強制不帶入媒體資料
    if (useSafeMode) {
      userPayload['media'] = null;
    }

    final String userPayloadString = const JsonEncoder.withIndent('  ')
        .convert(userPayload);

    // ── 組裝標準 Message 陣列 ────────────────────────────────
    final messages = [
      {
        'role': 'system',
        'content': systemContent,
      },
      {
        'role': 'developer',
        'content': developerContent,
      },
      {
        'role': 'user',
        'content': userPayloadString,
      },
    ];

    return PromptBundle(messages: messages, isSafeMode: useSafeMode);
  }

  // ── 方便使用的工廠方法 ───────────────────────────────────────
  
  /// 快速建立一個請求訊息列表
  static PromptBundle build(
    Map<String, dynamic> ownerData,
    Map<String, dynamic> petData,
    String story,
    List<String> questions,
    String mode,
    MediaPayload? media,
  ) {
    final request = AiRequestModel(
      ownerProfile: OwnerProfile(
        experienceLevel: ownerData['experienceLevel'] ?? '',
        careStyle: ownerData['careStyle'] ?? '',
        emotionStyle: ownerData['emotionStyle'] ?? '',
        dailyRoutine: ownerData['dailyRoutine'] ?? '',
        mainConcern: ownerData['mainConcern'] ?? '',
      ),
      petProfile: PetProfile(
        name: petData['name'] ?? '',
        species: petData['species'] ?? '',
        breed: petData['breed'] ?? '',
        age: (petData['age'] as num?)?.toDouble() ?? 0,
        coatColor: petData['coatColor'] ?? '',
        personalityTraits: List<String>.from(petData['personalityTraits'] ?? []),
      ),
      story: story,
      questions: questions,
      inputMode: mode,
      media: mode == 'free' ? null : media, // 安全檢查
    );

    return buildMessages(request);
  }
}
