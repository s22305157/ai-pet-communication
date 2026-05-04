// lib/features/knowledge/domain/example_case.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory ExampleCase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExampleCase(
      id: doc.id,
      inputText: data['input_text'] ?? '',
      expectedMode: data['expected_mode'] ?? 'general',
      expectedTopics: List<String>.from(data['expected_topics'] ?? []),
      expectedOutputTraits: List<String>.from(data['expected_output_traits'] ?? []),
      relatedChunkIds: List<String>.from(data['related_chunk_ids'] ?? []),
      reviewStatus: data['review_status'] ?? 'approved',
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'input_text': inputText,
      'expected_mode': expectedMode,
      'expected_topics': expectedTopics,
      'expected_output_traits': expectedOutputTraits,
      'related_chunk_ids': relatedChunkIds,
      'review_status': reviewStatus,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
