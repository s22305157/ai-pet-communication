import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/safety_rule.dart';

class SafetyRuleMapper {
  static SafetyRule fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SafetyRule(
      id: doc.id,
      triggerKeywords: List<String>.from(data['trigger_keywords'] ?? []),
      triggerConditions: data['trigger_conditions'] ?? '',
      responseAction: data['response_action'] ?? '',
      forbiddenPhrases: List<String>.from(data['forbidden_phrases'] ?? []),
      severity: data['severity'] ?? 'red_flag',
      version: data['version'] ?? 'v1',
      enabled: data['enabled'] ?? true,
    );
  }

  static Map<String, dynamic> toMap(SafetyRule value) {
    return {
      'trigger_keywords': value.triggerKeywords,
      'trigger_conditions': value.triggerConditions,
      'response_action': value.responseAction,
      'forbidden_phrases': value.forbiddenPhrases,
      'severity': value.severity,
      'version': value.version,
      'enabled': value.enabled,
    };
  }
}
