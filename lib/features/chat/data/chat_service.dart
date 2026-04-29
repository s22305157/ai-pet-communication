class ChatService {
  Future<String> sendMessage(String message) async {
    // Simulate AI response delay
    await Future.delayed(const Duration(seconds: 1));
    return "?謕? AI ?豯???message";
  }
}
