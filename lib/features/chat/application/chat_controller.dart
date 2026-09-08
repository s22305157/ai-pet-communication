// lib/features/chat/application/chat_controller.dart
// ============================================================
// PAWLINK - 聊天控制器 (ChatController)
// ============================================================

import 'dart:developer' as dev;
import 'dart:convert';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/application/ai_validator.dart';
import 'package:ai_pet_communication/features/chat/application/prompt_manager.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/knowledge/application/knowledge_retrieval_service.dart';
import 'package:ai_pet_communication/features/chat/application/safety_router.dart';

class ChatController {
  final ChatService _chatService;
  final ReadingService _readingService;
  final KnowledgeRetrievalService _knowledgeRetrievalService;

  ChatController(
    this._chatService,
    this._readingService, [
    KnowledgeRetrievalService? knowledgeRetrievalService,
  ]) : _knowledgeRetrievalService =
           knowledgeRetrievalService ?? KnowledgeRetrievalService();

  /// 處理完整的 AI 溝通請求 (包含重試與 Fallback 邏輯)
  Future<dynamic> handleCommunication(
    String petId,
    AiRequestModel request,
  ) async =>
      (await handleCommunicationWithPersistence(petId, request)).response;

  Future<CommunicationOutcome> handleCommunicationWithPersistence(
    String petId,
    AiRequestModel request,
  ) async {
    int retryCount = 0;
    const int maxRetries = 1; // 失敗時重試一次

    while (retryCount <= maxRetries) {
      try {
        // 1. 先做安全分流，再以完整問題檢索知識。
        final safetyDecision = SafetyRouter.evaluate(request);
        final retrievalQuery = [
          request.petProfile.species,
          request.ownerProfile.mainConcern,
          request.story,
          ...request.questions,
        ].where((value) => value.trim().isNotEmpty).join(' ');
        List<KnowledgeHit> knowledgeHits;
        try {
          knowledgeHits = await _knowledgeRetrievalService.search(
            query: retrievalQuery,
            species: request.petProfile.species,
            limit: safetyDecision.needsImmediateAction ? 5 : 4,
          );
        } catch (error, stackTrace) {
          dev.log('知識庫檢索失敗，改用無檢索安全提示', error: error, stackTrace: stackTrace);
          knowledgeHits = const [];
        }

        // 2. 將安全結果與可追溯知識片段組裝進 Prompt。
        final bundle = PromptManager.buildMessages(
          request,
          knowledgeHits: knowledgeHits,
          safetyDecision: safetyDecision,
        );

        // 3. 呼叫 AI 服務；使用 JSON 序列化保留訊息角色與跳脫字元。
        final rawResponse = await _chatService.sendMessage(
          jsonEncode(bundle.messages),
        );

        // 4. 根據模式進行動態驗證
        dynamic aiResponse;
        if (bundle.isSafeMode) {
          final safeResponse = AiValidator.validateSafeResponse(rawResponse);
          AiValidator.enforceSafetyDecision(
            safeResponse,
            bundle.safetyDecision,
          );
          aiResponse = safeResponse;
        } else {
          aiResponse = AiValidator.validateResponse(rawResponse);
        }
        // 5. 記錄到資料庫 (儲存 JSON 字串)
        ReadingPersistenceException? persistenceFailure;
        try {
          await _readingService.recordAiResponse(
            petId: petId,
            aiText: aiResponse.toJson(),
            source: bundle.isSafeMode ? 'safe_chat' : 'pro_chat',
          );
        } on ReadingPersistenceException catch (error) {
          persistenceFailure = error;
        }

        return CommunicationOutcome(
          response: aiResponse,
          persistenceFailure: persistenceFailure,
        );
      } catch (e) {
        dev.log('AI 溝通失敗 (嘗試 ${retryCount + 1}): $e');

        if (retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // 重試也失敗，回傳標準版的安全預設值 (AiResponseModel)
        dev.log('AI 溝通最終失敗，回傳 Fallback 內容');
        return CommunicationOutcome(
          response: AiResponseModel.safeFallback(error: e.toString()),
          isFallback: true,
        );
      }
    }

    return CommunicationOutcome(
      response: AiResponseModel.safeFallback(
        error: 'Unknown error in communication loop',
      ),
      isFallback: true,
    );
  }

  Future<void> retryPersistence(CommunicationOutcome outcome) async {
    final failure = outcome.persistenceFailure;
    if (failure == null) return;
    await _readingService.saveReading(failure.reading);
  }

  // ── 舊有的處理方法 (維持相容性或供簡單測試使用) ──────────────────
  Future<String> handleUserMessage(String petId, String message) async {
    try {
      final aiResponse = await _chatService.sendMessage(message);

      await _readingService.recordAiResponse(
        petId: petId,
        aiText: aiResponse,
        source: 'chat',
      );

      return aiResponse;
    } catch (e) {
      rethrow;
    }
  }
}

class CommunicationOutcome {
  final dynamic response;
  final ReadingPersistenceException? persistenceFailure;
  final bool isFallback;

  const CommunicationOutcome({
    required this.response,
    this.persistenceFailure,
    this.isFallback = false,
  });

  bool get wasPersisted => persistenceFailure == null && !isFallback;
}
