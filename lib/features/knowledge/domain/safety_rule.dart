// lib/features/knowledge/domain/safety_rule.dart

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
}
