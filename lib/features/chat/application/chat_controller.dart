import '../data/chat_service.dart';
import '../../readings/application/reading_service.dart';

class ChatController {
  final ChatService _chatService;
  final ReadingService _readingService;

  ChatController(this._chatService, this._readingService);

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
