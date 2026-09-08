import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/book.dart';

class BookMapper {
  static Book fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Book(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      publisher: data['publisher'] ?? '',
      edition: data['edition'] ?? '',
      language: data['language'] ?? 'zh-TW',
      sourceType: data['source_type'] ?? 'paper_book',
      notes: data['notes'] ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> toMap(Book value) {
    return {
      'title': value.title,
      'author': value.author,
      'publisher': value.publisher,
      'edition': value.edition,
      'language': value.language,
      'source_type': value.sourceType,
      'notes': value.notes,
      'created_at': Timestamp.fromDate(value.createdAt),
      'updated_at': Timestamp.fromDate(value.updatedAt),
    };
  }
}
