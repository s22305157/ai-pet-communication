class Reading {
  final String id;
  final String petId;
  final String title;
  final String content;
  final String? mood;
  final String? source;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Reading({
    required this.id,
    required this.petId,
    required this.title,
    required this.content,
    this.mood,
    this.source,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'title': title,
      'content': content,
      'mood': mood,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Reading.fromMap(Map<String, dynamic> map, String documentId) {
    return Reading(
      id: documentId,
      petId: map['petId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      mood: map['mood'] as String?,
      source: map['source'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}
