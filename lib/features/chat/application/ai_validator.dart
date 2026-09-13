import '../domain/ai_validation_exception.dart';
import '../domain/ai_request_model.dart';
import '../domain/ai_safe_response_model.dart';
import 'safety_router.dart';
export '../domain/ai_validation_exception.dart';

class AiValidator {
  static void validateRequest(AiRequestModel request) {
    final json = request.toMap();

    // 檢查必要欄位
    _checkRequiredKeys(json, [
      'ownerProfile',
      'petProfile',
      'story',
      'questions',
      'inputMode',
    ], 'Request');

    // 驗證 questions
    final questions = json['questions'];
    if (questions is! List || questions.isEmpty || questions.length > 5) {
      throw AiValidationException(
        'Request questions must be a list of 1 to 5 items',
      );
    }

    // 驗證 inputMode
    final mode = json['inputMode'];
    if (!['free', 'plus', 'pro'].contains(mode)) {
      throw AiValidationException(
        'Request inputMode must be free, plus or pro',
      );
    }

    // 驗證 story 長度
    if ((json['story'] as String).length > 5000) {
      throw AiValidationException('Request story exceeds 5000 characters');
    }
  }

  /// 確保模型輸出沒有弱化本機先行判定的安全層級。
  static void enforceSafetyDecision(
    AiSafeResponseModel response,
    SafetyDecision decision,
  ) {
    if (!decision.needsImmediateAction) return;
    final redFlags = response.safetyAlert.redFlags ?? const [];
    if (!response.safetyAlert.hasRedFlags || redFlags.isEmpty) {
      throw AiValidationException(
        'Emergency response must preserve detected red flags',
      );
    }
    final firstStep = response.nextSteps.first;
    if (!firstStep.contains('立即') ||
        !(firstStep.contains('獸醫') || firstStep.contains('急診'))) {
      throw AiValidationException(
        'Emergency response must lead with immediate veterinary care',
      );
    }
  }

  /// 輔助方法：檢查必要 Key
  static void _checkRequiredKeys(
    Map<String, dynamic> json,
    List<String> keys,
    String context,
  ) {
    for (final key in keys) {
      if (!json.containsKey(key)) {
        throw AiValidationException('Missing required $context key: $key');
      }
    }
  }
}
