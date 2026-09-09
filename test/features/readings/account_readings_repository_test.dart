import 'dart:io';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/readings/data/account_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/firestore_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/data/local_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

PetModel pet(String owner) => PetModel(
  petId: 'pet-1',
  ownerId: owner,
  name: 'pet',
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
);

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> petBox;
  late Box<dynamic> readingBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-reading-router-',
    );
    Hive.init(hiveDirectory.path);
    petBox = await Hive.openBox<dynamic>('reading_router_pets');
    readingBox = await Hive.openBox<dynamic>('reading_router_readings');
  });

  setUp(() async {
    await petBox.clear();
    await readingBox.clear();
  });

  test(
    'downgraded account reads cloud history and saves new readings locally',
    () async {
      final auth = MockAuthService();
      final firestore = FakeFirebaseFirestore();
      final localPets = LocalPetService(box: petBox);
      final localReadings = LocalReadingsRepository(box: readingBox);
      when(() => auth.getUserData()).thenAnswer(
        (_) async => UserModel(
          uid: 'owner-a',
          email: '',
          displayName: '',
          hadPaidMembership: true,
        ),
      );
      when(() => auth.userIdChanges).thenAnswer((_) => Stream.value('owner-a'));
      await localPets.updatePet('owner-a', 'pet-1', pet('owner-a'));
      final cloud = FirestoreReadingsRepository(firestore);
      final old = Reading(
        id: 'old',
        petId: 'pet-1',
        title: 'old',
        content: 'history',
        createdAt: DateTime(2025),
      );
      final fresh = Reading(
        id: 'new',
        petId: 'pet-1',
        title: 'new',
        content: 'local',
        createdAt: DateTime(2026),
      );
      await cloud.addReading(old);
      final repository = AccountReadingsRepository(
        authService: auth,
        localPets: localPets,
        localReadings: localReadings,
        cloudReadings: cloud,
      );
      await repository.addReading(fresh);

      final merged = await repository
          .watchReadingsByPetId('pet-1')
          .firstWhere((items) => items.length == 2)
          .timeout(const Duration(seconds: 3));
      expect(merged.map((r) => r.id), ['new', 'old']);
      expect(await cloud.getReadingById('pet-1', 'new'), isNull);
      expect(
        (await repository.getReadingById('pet-1', 'old'))?.content,
        'history',
      );
      await repository.deleteReading('pet-1', 'old');
      expect(await repository.getReadingById('pet-1', 'old'), isNull);
    },
  );

  tearDownAll(() async {
    await petBox.deleteFromDisk();
    await readingBox.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'free account stores reading locally without a cloud parent document',
    () async {
      final auth = MockAuthService();
      final firestore = FakeFirebaseFirestore();
      final localPets = LocalPetService(box: petBox);
      final localReadings = LocalReadingsRepository(box: readingBox);
      when(() => auth.getUserData()).thenAnswer(
        (_) async => UserModel(
          uid: 'owner-a',
          email: 'a@example.com',
          displayName: 'A',
          membershipTier: 'free',
        ),
      );
      await localPets.updatePet('owner-a', 'pet-1', pet('owner-a'));
      final repository = AccountReadingsRepository(
        authService: auth,
        localPets: localPets,
        localReadings: localReadings,
        cloudReadings: FirestoreReadingsRepository(firestore),
      );
      final item = Reading(
        id: 'reading-1',
        petId: 'pet-1',
        title: 'title',
        content: 'content',
        createdAt: DateTime(2026),
      );

      await repository.addReading(item);

      expect(
        localReadings.getReadings('owner-a', 'pet-1').single.id,
        'reading-1',
      );
      expect(
        (await firestore.collection('pets').doc('pet-1').get()).exists,
        false,
      );
    },
  );

  test(
    'free account cannot write a reading for another owner local pet',
    () async {
      final auth = MockAuthService();
      final firestore = FakeFirebaseFirestore();
      final localPets = LocalPetService(box: petBox);
      when(() => auth.getUserData()).thenAnswer(
        (_) async => UserModel(
          uid: 'owner-b',
          email: 'b@example.com',
          displayName: 'B',
          membershipTier: 'free',
        ),
      );
      await localPets.updatePet('owner-a', 'pet-1', pet('owner-a'));
      final repository = AccountReadingsRepository(
        authService: auth,
        localPets: localPets,
        localReadings: LocalReadingsRepository(box: readingBox),
        cloudReadings: FirestoreReadingsRepository(firestore),
      );

      expect(
        () => repository.addReading(
          Reading(
            id: 'reading-1',
            petId: 'pet-1',
            title: 'title',
            content: 'content',
            createdAt: DateTime(2026),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
