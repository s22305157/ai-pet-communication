import 'dart:io';

import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockPetRemoteDataSource extends Mock implements PetRemoteDataSource {}

PetModel pet(String id) => PetModel(
  petId: id,
  ownerId: 'owner-a',
  name: id,
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
  late LocalPetService local;
  late MockPetRemoteDataSource remote;
  late PetSyncManager manager;

  setUpAll(() async {
    registerFallbackValue(pet('fallback'));
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-sync-manager-',
    );
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<dynamic>('pet_sync_manager_test');
  });

  setUp(() async {
    await box.clear();
    local = LocalPetService(box: box);
    remote = MockPetRemoteDataSource();
    manager = PetSyncManager(localService: local, remoteDataSource: remote);
  });

  tearDownAll(() async {
    await box.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test('retries a pending upsert and clears it after cloud success', () async {
    final item = pet('pet-1');
    await local.updatePet('owner-a', item.petId, item);
    await local.markPendingUpsert('owner-a', item);
    when(
      () => remote.getPetDeletionTime(item.petId),
    ).thenAnswer((_) async => null);
    when(() => remote.getPet(item.petId)).thenAnswer((_) async => null);
    when(() => remote.setPet(item.petId, any())).thenAnswer((_) async {});

    await manager.syncPendingOperations('owner-a');

    verify(
      () => remote.setPet(
        item.petId,
        any(
          that: isA<PetModel>().having((pet) => pet.petId, 'petId', item.petId),
        ),
      ),
    ).called(1);
    expect(local.getPendingOperations('owner-a'), isEmpty);
  });

  test(
    'server tombstone prevents a stale pending upsert from recreating pet',
    () async {
      final item = pet('pet-1');
      await local.updatePet('owner-a', item.petId, item);
      await local.markPendingUpsert('owner-a', item);
      when(
        () => remote.getPetDeletionTime(item.petId),
      ).thenAnswer((_) async => DateTime(2026));

      await manager.syncPendingOperations('owner-a');

      verifyNever(() => remote.setPet(any(), any()));
      expect(await local.getPet('owner-a', item.petId), isNull);
      expect(local.getPendingOperations('owner-a'), isEmpty);
      expect(local.hasTombstone('owner-a', item.petId), true);
    },
  );

  test('newer cloud revision wins over a stale pending upsert', () async {
    final localPet = pet('pet-1').copyWith(updatedAt: DateTime(2026, 1));
    final cloudPet = pet('pet-1').copyWith(updatedAt: DateTime(2026, 2));
    await local.updatePet('owner-a', localPet.petId, localPet);
    await local.markPendingUpsert('owner-a', localPet);
    when(
      () => remote.getPetDeletionTime(localPet.petId),
    ).thenAnswer((_) async => null);
    when(() => remote.getPet(localPet.petId)).thenAnswer((_) async => cloudPet);

    await manager.syncPendingOperations('owner-a');

    verifyNever(() => remote.setPet(any(), any()));
    verifyNever(() => remote.updatePet(any(), any()));
    expect(
      (await local.getPet('owner-a', localPet.petId))?.updatedAt,
      cloudPet.updatedAt,
    );
    expect(local.getPendingOperations('owner-a'), isEmpty);
  });

  test('retries a queued delete and preserves the local tombstone', () async {
    final item = pet('pet-1');
    await local.updatePet('owner-a', item.petId, item);
    await local.markPendingDelete(
      'owner-a',
      item.petId,
      avatarUrl: item.avatarUrl,
    );
    when(
      () => remote.deletePet(item.petId, avatarUrl: item.avatarUrl),
    ).thenAnswer((_) async {});

    await manager.syncPendingOperations('owner-a');

    verify(
      () => remote.deletePet(item.petId, avatarUrl: item.avatarUrl),
    ).called(1);
    expect(local.getPendingOperations('owner-a'), isEmpty);
    expect(local.hasTombstone('owner-a', item.petId), true);
  });
}
