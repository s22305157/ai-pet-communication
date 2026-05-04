// lib/features/knowledge/domain/book.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Book.fromFirestore(DocumentSnapshot doc) {
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

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'author': author,
      'publisher': publisher,
      'edition': edition,
      'language': language,
      'source_type': sourceType,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}
