// lib/features/knowledge/domain/knowledge_chunk.dart

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
}
