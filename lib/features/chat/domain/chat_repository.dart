abstract interface class ChatRepository {
  /// Sends the structured consultation envelope; plain text is never accepted.
  Future<String> sendMessage(String message);
}
