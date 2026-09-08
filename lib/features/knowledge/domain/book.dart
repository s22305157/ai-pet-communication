// lib/features/knowledge/domain/book.dart

class Book {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final String edition;
  final String language;
  final String sourceType;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.edition,
    this.language = 'zh-TW',
    this.sourceType = 'paper_book',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });
}
