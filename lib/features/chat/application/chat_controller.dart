// lib/features/chat/application/chat_controller.dart
// ============================================================
// PAWLINK - 聊天控制器 (ChatController)
// ============================================================

import 'dart:developer' as dev;
import '../domain/chat_consultation.dart';
import '../domain/ai_safe_response_model.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/core/errors/service_failure.dart';
import '../domain/chat_repository.dart';
import '../domain/communication_response.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/application/ai_validator.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/application/safety_router.dart';

class ChatController {
  final ChatRepository _chatService;
  final ReadingService _readingService;

  ChatController(this._chatService, this._readingService);

  /// 處理完整的 AI 溝通請求 (包含重試與 Fallback 邏輯)
  Future<CommunicationResponse> handleCommunication(
    String petId,
    AiRequestModel request,
  ) async =>
      (await handleCommunicationWithPersistence(petId, request)).response;

  Future<CommunicationOutcome> handleCommunicationWithPersistence(
    String petId,
    AiRequestModel request, {
    String? requestId,
  }) async {
    try {
      // Validate once; invalid input and malformed responses never re-send AI.
      AiValidator.validateRequest(request);
      final safety = SafetyRouter.evaluate(request);
      final consultation = ChatConsultation(
        requestId: requestId ?? const Uuid().v4(),
        petId: petId,
        request: request,
        useSafeMode: safety.useSafeMode,
      );
      final response = await _send(consultation);
      if (safety.useSafeMode) {
        if (response is! AiSafeResponseModel) {
          throw AiValidationException('Expected a safe response');
        }
        AiValidator.enforceSafetyDecision(response, safety);
      }
      ReadingPersistenceException? persistenceFailure;
      try {
        await _readingService.recordAiResponse(
          petId: petId,
          aiText: response.toJson(),
          source: safety.useSafeMode ? 'safe_chat' : 'pro_chat',
        );
      } on ReadingPersistenceException catch (error) {
        persistenceFailure = error;
      }
      return CommunicationOutcome(
        response: response,
        persistenceFailure: persistenceFailure,
      );
    } catch (error) {
      // Do not log input, provider payloads or private response text.
      dev.log('AI 溝通未完成，回傳 Fallback 內容');
      return CommunicationOutcome(
        response: AiResponseModel.safeFallback(error: error.toString()),
        isFallback: true,
      );
    }
  }

  Future<CommunicationResponse> _send(ChatConsultation consultation) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _chatService.sendMessage(consultation);
      } on ServiceFailure catch (error) {
        if (attempt >= 1 || !error.isRetryable) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        // Preserve the original request ID for backend idempotency.
      }
    }
  }

  Future<void> retryPersistence(CommunicationOutcome outcome) async {
    final failure = outcome.persistenceFailure;
    if (failure == null) return;
    await _readingService.saveReading(failure.reading);
  }
}

class CommunicationOutcome {
  final CommunicationResponse response;
  final ReadingPersistenceException? persistenceFailure;
  final bool isFallback;

  const CommunicationOutcome({
    required this.response,
    this.persistenceFailure,
    this.isFallback = false,
  });

  bool get wasPersisted => persistenceFailure == null && !isFallback;
}
