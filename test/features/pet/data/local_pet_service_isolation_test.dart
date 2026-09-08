import 'dart:io';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

PetModel pet(String id, String owner) => PetModel(
  petId: id,
  ownerId: owner,
  name: '$owner-pet',
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
);

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late LocalPetService service;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-local-pet-isolation-',
    );
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<dynamic>('account_isolation_test');
    service = LocalPetService(box: box);
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await box.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test('partitions pets by uid even when pet IDs collide', () async {
    await service.updatePet(
      'owner-a',
      'shared-id',
      pet('shared-id', 'owner-a'),
    );
    await service.updatePet(
      'owner-b',
      'shared-id',
      pet('shared-id', 'owner-b'),
    );

    expect(service.getAllPets('owner-a').single.ownerId, 'owner-a');
    expect(service.getAllPets('owner-b').single.ownerId, 'owner-b');
    expect((await service.getPet('owner-b', 'shared-id'))?.ownerId, 'owner-b');
  });

  test('rejects writes when pet owner differs from uid scope', () async {
    expect(
      () => service.updatePet('owner-b', 'pet-a', pet('pet-a', 'owner-a')),
      throwsStateError,
    );
    expect(service.getAllPets('owner-b'), isEmpty);
  });

  test(
    'legacy migration moves only records owned by the requested uid',
    () async {
      await box.put(
        'legacy-a',
        pet('legacy-a', 'owner-a').toMap(isLocal: true),
      );
      await box.put(
        'legacy-b',
        pet('legacy-b', 'owner-b').toMap(isLocal: true),
      );

      await service.migrateLegacyDataForUser('owner-b');

      expect(service.getAllPets('owner-b').map((item) => item.petId), [
        'legacy-b',
      ]);
      expect(service.getAllPets('owner-a').map((item) => item.petId), [
        'legacy-a',
      ]);
      expect(box.containsKey('legacy-a'), true);
      expect(box.containsKey('legacy-b'), false);
    },
  );

  test('clearing one uid leaves the other uid partition intact', () async {
    await service.updatePet('owner-a', 'pet-a', pet('pet-a', 'owner-a'));
    await service.updatePet('owner-b', 'pet-b', pet('pet-b', 'owner-b'));

    await service.clearUser('owner-a');

    expect(service.getAllPets('owner-a'), isEmpty);
    expect(service.getAllPets('owner-b').single.petId, 'pet-b');
  });
}
