import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../domain/reading.dart';
import '../data/readings_repository.dart';

class ReadingService {
  final ReadingsRepository _repository;

  ReadingService(this._repository);

  Future<void> recordAiResponse({
    required String petId,
    required String aiText,
    String? mood,
    String? source,
  }) async {
    if (petId.isEmpty) {
      throw ArgumentError('petId is required');
    }

    final reading = Reading(
      id: const Uuid().v4(),
      petId: petId,
      title: 'AI 寵物溝通紀錄',
      content: aiText,
      mood: mood,
      source: source,
      createdAt: DateTime.now(),
    );

    try {
      await _repository.addReading(reading);
    } catch (e, stackTrace) {
      debugPrint('Failed to add reading to Firestore: $e\n$stackTrace');
    }
  }
  Future<void> deleteReading(String petId, String readingId) async {
    try {
      await _repository.deleteReading(petId, readingId);
    } catch (e, stackTrace) {
      debugPrint('Failed to delete reading from Firestore: $e\n$stackTrace');
      rethrow;
    }
  }
}
