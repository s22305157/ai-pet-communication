// lib/features/knowledge/domain/safety_rule.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyRule {
  final String id;
  final List<String> triggerKeywords;
  final String triggerConditions;
  final String responseAction;
  final List<String> forbiddenPhrases;
  final String severity; // red_flag / caution
  final String version;
  final bool enabled;

  SafetyRule({
    required this.id,
    required this.triggerKeywords,
    required this.triggerConditions,
    required this.responseAction,
    required this.forbiddenPhrases,
    this.severity = 'red_flag',
    this.version = 'v1',
    this.enabled = true,
  });

  factory SafetyRule.fromFirestore(DocumentSnapshot doc) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'trigger_keywords': triggerKeywords,
      'trigger_conditions': triggerConditions,
      'response_action': responseAction,
      'forbidden_phrases': forbiddenPhrases,
      'severity': severity,
      'version': version,
      'enabled': enabled,
    };
  }
}
