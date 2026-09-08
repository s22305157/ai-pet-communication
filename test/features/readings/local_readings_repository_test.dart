import 'dart:io';

import 'package:ai_pet_communication/features/readings/data/local_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Reading reading(String id, String petId, DateTime createdAt) => Reading(
  id: id,
  petId: petId,
  title: id,
  content: 'content-$id',
  createdAt: createdAt,
);

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late LocalReadingsRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-local-readings-',
    );
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<dynamic>('local_readings_repository_test');
    repository = LocalReadingsRepository(box: box);
  });

  setUp(() => box.clear());

  tearDownAll(() async {
    await box.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test('partitions readings by uid and pet id', () async {
    await repository.addReading(
      'owner-a',
      reading('shared', 'pet-1', DateTime(2026, 1, 1)),
    );
    await repository.addReading(
      'owner-b',
      reading('shared', 'pet-1', DateTime(2026, 1, 2)),
    );

    expect(
      repository.getReadings('owner-a', 'pet-1').single.createdAt,
      DateTime(2026, 1, 1),
    );
    expect(
      repository.getReadings('owner-b', 'pet-1').single.createdAt,
      DateTime(2026, 1, 2),
    );
  });

  test('clearPet and clearUser do not remove another account data', () async {
    await repository.addReading(
      'owner-a',
      reading('a-1', 'pet-1', DateTime(2026)),
    );
    await repository.addReading(
      'owner-a',
      reading('a-2', 'pet-2', DateTime(2026)),
    );
    await repository.addReading(
      'owner-b',
      reading('b-1', 'pet-1', DateTime(2026)),
    );

    await repository.clearPet('owner-a', 'pet-1');
    expect(repository.getReadings('owner-a', 'pet-1'), isEmpty);
    expect(repository.getReadings('owner-a', 'pet-2'), hasLength(1));
    expect(repository.getReadings('owner-b', 'pet-1'), hasLength(1));

    await repository.clearUser('owner-a');
    expect(repository.getReadings('owner-a', 'pet-2'), isEmpty);
    expect(repository.getReadings('owner-b', 'pet-1'), hasLength(1));
  });
}
