import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/example_case.dart';

class ExampleCaseMapper {
  static ExampleCase fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExampleCase(
      id: doc.id,
      inputText: data['input_text'] ?? '',
      expectedMode: data['expected_mode'] ?? 'general',
      expectedTopics: List<String>.from(data['expected_topics'] ?? []),
      expectedOutputTraits: List<String>.from(
        data['expected_output_traits'] ?? [],
      ),
      relatedChunkIds: List<String>.from(data['related_chunk_ids'] ?? []),
      reviewStatus: data['review_status'] ?? 'approved',
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> toMap(ExampleCase value) {
    return {
      'input_text': value.inputText,
      'expected_mode': value.expectedMode,
      'expected_topics': value.expectedTopics,
      'expected_output_traits': value.expectedOutputTraits,
      'related_chunk_ids': value.relatedChunkIds,
      'review_status': value.reviewStatus,
      'created_at': Timestamp.fromDate(value.createdAt),
    };
  }
}
