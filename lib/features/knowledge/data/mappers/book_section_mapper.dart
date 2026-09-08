import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/book_section.dart';

class BookSectionMapper {
  static BookSection fromDoc(DocumentSnapshot doc) {
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

  static Map<String, dynamic> toMap(BookSection value) {
    return {
      'book_id': value.bookId,
      'chapter_title': value.chapterTitle,
      'section_title': value.sectionTitle,
      'page_start': value.pageStart,
      'page_end': value.pageEnd,
      'summary': value.summary,
      'key_takeaways': value.keyTakeaways,
      'review_status': value.reviewStatus,
      'created_at': Timestamp.fromDate(value.createdAt),
      'updated_at': Timestamp.fromDate(value.updatedAt),
    };
  }
}
