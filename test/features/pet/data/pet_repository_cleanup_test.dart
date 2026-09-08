import 'dart:io';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/readings/data/local_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockPetRemoteDataSource extends Mock implements PetRemoteDataSource {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> petBox;
  late Box<dynamic> readingBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-pet-cleanup-',
    );
    Hive.init(hiveDirectory.path);
    petBox = await Hive.openBox<dynamic>('pet_cleanup_pets');
    readingBox = await Hive.openBox<dynamic>('pet_cleanup_readings');
  });

  setUp(() async {
    await petBox.clear();
    await readingBox.clear();
  });

  tearDownAll(() async {
    await petBox.deleteFromDisk();
    await readingBox.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'deleting a pet clears local readings and calls recursive backend delete',
    () async {
      const uid = 'owner-a';
      const petId = 'pet-1';
      const avatarUrl = 'https://example.invalid/pet-1.png';
      final localPets = LocalPetService(box: petBox);
      final localReadings = LocalReadingsRepository(box: readingBox);
      final remote = MockPetRemoteDataSource();
      final auth = MockAuthService();
      final item = PetModel(
        petId: petId,
        ownerId: uid,
        name: 'pet',
        species: 'cat',
        breed: '',
        gender: '',
        birthday: '',
        personality: '',
        avatarUrl: avatarUrl,
      );
      when(() => auth.getUserData()).thenAnswer(
        (_) async => UserModel(
          uid: uid,
          email: 'a@example.com',
          displayName: 'A',
          membershipTier: 'free',
        ),
      );
      when(
        () => remote.deletePet(petId, avatarUrl: avatarUrl),
      ).thenAnswer((_) async {});
      await localPets.updatePet(uid, petId, item);
      await localReadings.addReading(
        uid,
        Reading(
          id: 'reading-1',
          petId: petId,
          title: 'title',
          content: 'content',
          createdAt: DateTime(2026),
        ),
      );
      final repository = PetRepositoryImpl(
        remoteDataSource: remote,
        localService: localPets,
        authService: auth,
        localReadings: localReadings,
      );

      await repository.deletePet(petId);

      expect(await localPets.getPet(uid, petId), isNull);
      expect(localReadings.getReadings(uid, petId), isEmpty);
      expect(localPets.getPendingOperations(uid), isEmpty);
      expect(localPets.hasTombstone(uid, petId), true);
      verify(() => remote.deletePet(petId, avatarUrl: avatarUrl)).called(1);
    },
  );
}
