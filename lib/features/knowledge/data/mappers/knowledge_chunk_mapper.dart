import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/knowledge_chunk.dart';

class KnowledgeChunkMapper {
  static KnowledgeChunk fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KnowledgeChunk(
      id: doc.id,
      bookId: data['book_id'] ?? '',
      sectionId: data['section_id'] ?? '',
      topic: data['topic'] ?? '',
      subtopic: data['subtopic'] ?? '',
      summary: data['summary'] ?? '',
      keyPoints: List<String>.from(data['key_points'] ?? []),
      keywords: List<String>.from(data['keywords'] ?? []),
      usageContext: List<String>.from(data['usage_context'] ?? []),
      toneTags: List<String>.from(data['tone_tags'] ?? []),
      safetyLevel: data['safety_level'] ?? 'normal',
      promptCandidate: data['prompt_candidate'] ?? '',
      confidenceHint: (data['confidence_hint'] ?? 1.0).toDouble(),
      sourcePageRef: data['source_page_ref'] ?? '',
      version: data['version'] ?? 'v1',
      reviewStatus: data['review_status'] ?? 'draft',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> toMap(KnowledgeChunk value) {
    return {
      'book_id': value.bookId,
      'section_id': value.sectionId,
      'topic': value.topic,
      'subtopic': value.subtopic,
      'summary': value.summary,
      'key_points': value.keyPoints,
      'keywords': value.keywords,
      'usage_context': value.usageContext,
      'tone_tags': value.toneTags,
      'safety_level': value.safetyLevel,
      'prompt_candidate': value.promptCandidate,
      'confidence_hint': value.confidenceHint,
      'source_page_ref': value.sourcePageRef,
      'version': value.version,
      'review_status': value.reviewStatus,
      'created_at': Timestamp.fromDate(value.createdAt),
      'updated_at': Timestamp.fromDate(value.updatedAt),
    };
  }
}
