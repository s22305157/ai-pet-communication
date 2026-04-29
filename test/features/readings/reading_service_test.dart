import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communicator/features/readings/application/reading_service.dart';
import 'package:ai_pet_communicator/features/readings/data/readings_repository.dart';
import 'package:ai_pet_communicator/features/readings/domain/reading.dart';

class FakeReadingsRepository extends ReadingsRepository {
  final readings = <Reading>[];
  bool throwError = false;

  @override
  Future<void> addReading(Reading reading) async {
    if (throwError) throw Exception('Firestore error');
    readings.add(reading);
  }

  @override
  Stream<List<Reading>> watchReadingsByPetId(String petId) {
    throw UnimplementedError();
  }

  @override
  Future<Reading?> getReadingById(String petId, String readingId) async {
    if (throwError) throw Exception('Firestore error');
    try {
      return readings.firstWhere((r) => r.petId == petId && r.id == readingId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteReading(String petId, String readingId) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeReadingsRepository repository;
  late ReadingService service;

  setUp(() {
    repository = FakeReadingsRepository();
    service = ReadingService(repository);
  });

  test('recordAiResponse calls addReading when successful', () async {
    await service.recordAiResponse(petId: 'p1', aiText: 'Meow');

    expect(repository.readings.length, 1);
    expect(repository.readings.first.petId, 'p1');
    expect(repository.readings.first.content, 'Meow');
    expect(repository.readings.first.title, 'AI 寵物溝通紀錄');
  });

  test('recordAiResponse logs error but does not throw when repository fails', () async {
    repository.throwError = true;

    // This should not throw
    await service.recordAiResponse(petId: 'p1', aiText: 'Meow');

    expect(repository.readings.length, 0);
  });

  test('recordAiResponse throws when petId is empty', () async {
    expect(
      () => service.recordAiResponse(petId: '', aiText: 'Meow'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
