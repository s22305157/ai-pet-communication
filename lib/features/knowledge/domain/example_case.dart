// lib/features/knowledge/domain/example_case.dart

class ExampleCase {
  final String id;
  final String inputText;
  final String expectedMode;
  final List<String> expectedTopics;
  final List<String> expectedOutputTraits;
  final List<String> relatedChunkIds;
  final String reviewStatus;
  final DateTime createdAt;

  ExampleCase({
    required this.id,
    required this.inputText,
    required this.expectedMode,
    required this.expectedTopics,
    required this.expectedOutputTraits,
    required this.relatedChunkIds,
    this.reviewStatus = 'approved',
    required this.createdAt,
  });
}
