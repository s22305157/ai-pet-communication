import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/prompt_rule.dart';

class PromptRuleMapper {
  static PromptRule fromDoc(DocumentSnapshot doc) {
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

  static Map<String, dynamic> toMap(PromptRule value) {
    return {
      'source_chunk_id': value.sourceChunkId,
      'rule_type': value.ruleType,
      'rule_text': value.ruleText,
      'priority': value.priority,
      'mode': value.mode,
      'enabled': value.enabled,
      'version': value.version,
      'created_at': Timestamp.fromDate(value.createdAt),
      'updated_at': Timestamp.fromDate(value.updatedAt),
    };
  }
}
