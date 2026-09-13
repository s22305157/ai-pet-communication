abstract interface class CommunicationResponse {
  List<String> get matchedCardIds;
  List<String> get newCardIds;
  Map<String, dynamic> toMap();
  String toJson();
}
