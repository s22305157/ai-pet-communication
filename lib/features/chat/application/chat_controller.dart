// lib/features/chat/application/chat_controller.dart
// ============================================================
// PAWLINK - 聊天控制器 (ChatController)
// ============================================================

import 'dart:developer' as dev;
import '../data/chat_service.dart';
import '../../readings/application/reading_service.dart';
import '../domain/ai_response_model.dart';
import 'ai_validator.dart';
import 'prompt_manager.dart';
import '../domain/ai_request_model.dart';

class ChatController {
  final ChatService _chatService;
  final ReadingService _readingService;

  ChatController(this._chatService, this._readingService);

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
        // 1. 組裝 Prompt Bundle (包含是否為安全模式的判斷)
        final bundle = PromptManager.buildMessages(request);

        // 2. 呼叫 AI 服務
        final rawResponse = await _chatService.sendMessage(
          bundle.messages.toString(),
        );

        // 3. 根據模式進行動態驗證
        dynamic aiResponse;
        if (bundle.isSafeMode) {
          aiResponse = AiValidator.validateSafeResponse(rawResponse);
        } else {
          aiResponse = AiValidator.validateResponse(rawResponse);
        }
        // 4. 記錄到資料庫 (儲存 JSON 字串)
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
