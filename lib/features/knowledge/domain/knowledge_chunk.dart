// lib/features/knowledge/domain/knowledge_chunk.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class KnowledgeChunk {
  final String id;
  final String bookId;
  final String sectionId;
  final String topic;
  final String subtopic;
  final String summary;
  final List<String> keyPoints;
  final List<String> keywords;
  final List<String> usageContext;
  final List<String> toneTags;
  final String safetyLevel; // normal / caution / red_flag
  final String promptCandidate;
  final double confidenceHint;
  final String sourcePageRef;
  final String version;
  final String reviewStatus; // draft / reviewed / approved
  final DateTime createdAt;
  final DateTime updatedAt;

  KnowledgeChunk({
    required this.id,
    required this.bookId,
    required this.sectionId,
    required this.topic,
    required this.subtopic,
    required this.summary,
    required this.keyPoints,
    required this.keywords,
    required this.usageContext,
    required this.toneTags,
    this.safetyLevel = 'normal',
    this.promptCandidate = '',
    this.confidenceHint = 1.0,
    required this.sourcePageRef,
    this.version = 'v1',
    this.reviewStatus = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnowledgeChunk.fromFirestore(DocumentSnapshot doc) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'book_id': bookId,
      'section_id': sectionId,
      'topic': topic,
      'subtopic': subtopic,
      'summary': summary,
      'key_points': keyPoints,
      'keywords': keywords,
      'usage_context': usageContext,
      'tone_tags': toneTags,
      'safety_level': safetyLevel,
      'prompt_candidate': promptCandidate,
      'confidence_hint': confidenceHint,
      'source_page_ref': sourcePageRef,
      'version': version,
      'review_status': reviewStatus,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}
