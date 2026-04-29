import '../domain/reading.dart';

abstract class ReadingsRepository {
  Stream<List<Reading>> watchReadingsByPetId(String petId);
  Future<Reading?> getReadingById(String petId, String readingId);
  Future<void> addReading(Reading reading);
  Future<void> deleteReading(String petId, String readingId);
}
