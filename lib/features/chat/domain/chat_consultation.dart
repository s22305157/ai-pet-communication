import 'ai_request_model.dart';

/// An application request. Transport envelopes and JSON belong to the data layer.
class ChatConsultation {
  final String requestId;
  final String petId;
  final AiRequestModel request;
  final bool useSafeMode;

  const ChatConsultation({
    required this.requestId,
    required this.petId,
    required this.request,
    required this.useSafeMode,
  });
}
