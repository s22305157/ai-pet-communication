// lib/features/knowledge/domain/prompt_rule.dart

class PromptRule {
  final String id;
  final String sourceChunkId;
  final String ruleType; // tone / boundary / safety / output
  final String ruleText;
  final int priority;
  final String mode; // safe / general / both
  final bool enabled;
  final String version;
  final DateTime createdAt;
  final DateTime updatedAt;

  PromptRule({
    required this.id,
    required this.sourceChunkId,
    required this.ruleType,
    required this.ruleText,
    this.priority = 1,
    this.mode = 'both',
    this.enabled = true,
    this.version = 'v1',
    required this.createdAt,
    required this.updatedAt,
  });
}
