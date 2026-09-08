import 'package:ai_pet_communication/features/readings/domain/reading.dart';

abstract interface class LocalReadingsStore {
  Stream<List<Reading>> watchReadings(String uid, String petId);
  Future<Reading?> getReading(String uid, String petId, String readingId);
  Future<void> addReading(String uid, Reading reading);
  Future<void> deleteReading(String uid, String petId, String readingId);
}
