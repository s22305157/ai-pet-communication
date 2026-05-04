// lib/features/knowledge/domain/prompt_rule.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory PromptRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromptRule(
      id: doc.id,
      sourceChunkId: data['source_chunk_id'] ?? '',
      ruleType: data['rule_type'] ?? 'tone',
      ruleText: data['rule_text'] ?? '',
      priority: data['priority'] ?? 1,
      mode: data['mode'] ?? 'both',
      enabled: data['enabled'] ?? true,
      version: data['version'] ?? 'v1',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'source_chunk_id': sourceChunkId,
      'rule_type': ruleType,
      'rule_text': ruleText,
      'priority': priority,
      'mode': mode,
      'enabled': enabled,
      'version': version,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}
