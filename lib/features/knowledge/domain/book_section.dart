// lib/features/knowledge/domain/book_section.dart

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
}
