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
    // 規則整理：
    // 1. 故事內容 < 300 字 -> 安全版
    // 2. 出現急症/紅旗詞 (無論字數) -> 安全版
    // 3. 資訊充足 (>= 300 字) 且無紅旗詞 -> 一般版 (無論免費或付費版)
    final bool isLowInfo = request.story.trim().length < 300;
    final bool hasRedFlags = _detectRedFlags(request.story) || 
                             request.questions.any((q) => _detectRedFlags(q));
                             
    final bool useSafeMode = isLowInfo || hasRedFlags;

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

  // ── 紅旗詞偵測邏輯 ──────────────────────────────────────────
  
  static final List<String> _redFlagKeywords = [
    '呼吸急促', '喘', '嘔吐', '腹瀉', '抽搐', '昏迷', '無法站立', 
    '出血', '血便', '血尿', '疼痛', '嗜睡', '拒食', '發紺', '站不穩'
  ];

  static bool _detectRedFlags(String text) {
    for (final keyword in _redFlagKeywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }
}
