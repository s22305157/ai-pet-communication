// lib/features/knowledge/domain/book_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BookSection {
  final String id;
  final String bookId;
  final String chapterTitle;
  final String sectionTitle;
  final int pageStart;
  final int pageEnd;
  final String summary;
  final List<String> keyTakeaways;
  final String reviewStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookSection({
    required this.id,
    required this.bookId,
    required this.chapterTitle,
    required this.sectionTitle,
    required this.pageStart,
    required this.pageEnd,
    required this.summary,
    required this.keyTakeaways,
    this.reviewStatus = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookSection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookSection(
      id: doc.id,
      bookId: data['book_id'] ?? '',
      chapterTitle: data['chapter_title'] ?? '',
      sectionTitle: data['section_title'] ?? '',
      pageStart: data['page_start'] ?? 0,
      pageEnd: data['page_end'] ?? 0,
      summary: data['summary'] ?? '',
      keyTakeaways: List<String>.from(data['key_takeaways'] ?? []),
      reviewStatus: data['review_status'] ?? 'draft',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'book_id': bookId,
      'chapter_title': chapterTitle,
      'section_title': sectionTitle,
      'page_start': pageStart,
      'page_end': pageEnd,
      'summary': summary,
      'key_takeaways': keyTakeaways,
      'review_status': reviewStatus,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}
