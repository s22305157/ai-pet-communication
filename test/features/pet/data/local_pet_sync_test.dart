import 'dart:io';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

PetModel pet(String id, {String owner = 'owner-a', String name = 'pet'}) =>
    PetModel(
      petId: id,
      ownerId: owner,
      name: name,
      species: 'cat',
      breed: '',
      gender: '',
      birthday: '',
      personality: '',
      avatarUrl: 'https://example.invalid/$id.png',
    );

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late LocalPetService service;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pawlink-pet-sync-');
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<dynamic>('local_pet_sync_test');
    service = LocalPetService(box: box);
  });

  setUp(() => box.clear());

  tearDownAll(() async {
    await box.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test('pending delete removes local record and keeps a tombstone', () async {
    await service.updatePet('owner-a', 'pet-1', pet('pet-1'));
    await service.markPendingDelete(
      'owner-a',
      'pet-1',
      avatarUrl: pet('pet-1').avatarUrl,
    );

    expect(await service.getPet('owner-a', 'pet-1'), isNull);
    expect(service.hasTombstone('owner-a', 'pet-1'), true);
    expect(service.getPendingOperations('owner-a').single.isDelete, true);
  });

  test(
    'cloud cache refreshes records without overwriting pending writes',
    () async {
      await service.updatePet('owner-a', 'pet-1', pet('pet-1', name: 'local'));
      await service.markPendingUpsert('owner-a', pet('pet-1', name: 'pending'));
      await service.reconcileCloudSnapshot('owner-a', [
        pet('pet-1', name: 'cloud'),
        pet('pet-2', name: 'new-cloud'),
      ]);

      expect((await service.getPet('owner-a', 'pet-1'))?.name, 'local');
      expect((await service.getPet('owner-a', 'pet-2'))?.name, 'new-cloud');
    },
  );

  test(
    'clearUser removes pets, pending operations and tombstones only for uid',
    () async {
      await service.updatePet('owner-a', 'a', pet('a'));
      await service.markPendingDelete('owner-a', 'a');
      await service.updatePet('owner-b', 'b', pet('b', owner: 'owner-b'));

      await service.clearUser('owner-a');

      expect(service.getPendingOperations('owner-a'), isEmpty);
      expect(service.hasTombstone('owner-a', 'a'), false);
      expect(service.getAllPets('owner-b').single.petId, 'b');
    },
  );
}
