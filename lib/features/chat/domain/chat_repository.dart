import 'chat_consultation.dart';
import 'communication_response.dart';

abstract interface class ChatRepository {
  /// Sends the structured consultation envelope; plain text is never accepted.
  Future<CommunicationResponse> sendMessage(ChatConsultation consultation);
}
