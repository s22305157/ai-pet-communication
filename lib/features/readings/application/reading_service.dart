import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';

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

    await saveReading(reading);
  }

  Future<void> saveReading(Reading reading) async {
    try {
      await _repository.addReading(reading);
    } catch (error, stackTrace) {
      throw ReadingPersistenceException(reading, error, stackTrace);
    }
  }

  Future<void> deleteReading(String petId, String readingId) async {
    try {
      await _repository.deleteReading(petId, readingId);
    } catch (e, stackTrace) {
      debugPrint('Failed to delete reading: $e\n$stackTrace');
      rethrow;
    }
  }
}

class ReadingPersistenceException implements Exception {
  final Reading reading;
  final Object cause;
  final StackTrace stackTrace;

  const ReadingPersistenceException(this.reading, this.cause, this.stackTrace);

  @override
  String toString() => 'ReadingPersistenceException: $cause';
}
