class ChatService {
  Future<String> sendMessage(String message) async {
    // 模擬 AI 回應延遲
    await Future.delayed(const Duration(seconds: 1));
    return "這是來自 AI 的回應: $message";
  }
}
