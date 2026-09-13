class AiValidationException implements Exception {
  final String message;
  final dynamic details;
  AiValidationException(this.message, [this.details]);
  @override
  String toString() => 'AiValidationException: $message ${details ?? ""}';
}
