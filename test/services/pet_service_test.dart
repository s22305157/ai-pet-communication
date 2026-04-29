import 'package:ai_pet_communicator/models/pet_model.dart';
import 'package:ai_pet_communicator/services/pet_service.dart';
import 'package:ai_pet_communicator/services/auth_service.dart';
import 'package:ai_pet_communicator/services/local_pet_service.dart';
import 'package:ai_pet_communicator/models/user_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';

class MockLocalPetService extends Mock implements LocalPetService {}
class MockAuthService extends Mock implements AuthService {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}

void main() {
  late PetService petService;
  late FakeFirebaseFirestore fakeFirestore;
  late MockLocalPetService mockLocalService;
  late MockAuthService mockAuthService;
  late MockFirebaseStorage mockStorage;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockLocalService = MockLocalPetService();
    mockAuthService = MockAuthService();
    mockStorage = MockFirebaseStorage();
    
    petService = PetService(
      firestore: fakeFirestore,
      localService: mockLocalService,
      authService: mockAuthService,
      storage: mockStorage,
    );
    
    registerFallbackValue(PetModel(
      petId: 'test',
      ownerId: 'owner',
      name: 'name',
      species: 'dog',
      breed: 'breed',
      gender: 'male',
      birthday: '2020-01-01',
      personality: 'nice',
      avatarUrl: '',
      color: 'white',
      weight: 5.0,
    ));
  });

  group('PetService Tests', () {
    test('createPet should write to both cloud and local for Pro users', () async {
      // Setup
      final user = UserModel(
        uid: 'user123',
        email: 'test@test.com',
        displayName: 'Tester',
        membershipType: 'pro',
        points: 10,
      );
      
      when(() => mockAuthService.getUserData()).thenAnswer((_) async => user);
      when(() => mockLocalService.updatePet(any(), any())).thenAnswer((_) async => {});

      final pet = PetModel(
        petId: 'pet123',
        ownerId: 'user123',
        name: 'Buddy',
        species: 'Dog',
        breed: 'Retriever',
        gender: '公',
        birthday: '2022-01-01',
        personality: 'Friendly',
        avatarUrl: '',
        color: 'Golden',
        weight: 25.0,
      );

      // Execute
      await petService.createPet(pet);

      // Verify Cloud
      final cloudDoc = await fakeFirestore.collection('pets').doc('pet123').get();
      expect(cloudDoc.exists, true);
      expect(cloudDoc.data()?['name'], 'Buddy');

      // Verify Local
      verify(() => mockLocalService.updatePet('pet123', any())).called(1);
    });

    test('createPet should only write to local for Free users', () async {
      // Setup
      final user = UserModel(
        uid: 'user123',
        email: 'test@test.com',
        displayName: 'Tester',
        membershipType: 'free',
        points: 10,
      );
      
      when(() => mockAuthService.getUserData()).thenAnswer((_) async => user);
      when(() => mockLocalService.updatePet(any(), any())).thenAnswer((_) async => {});

      final pet = PetModel(
        petId: 'petFree',
        ownerId: 'user123',
        name: 'Buddy',
        species: 'Dog',
        breed: 'Retriever',
        gender: '公',
        birthday: '2022-01-01',
        personality: 'Friendly',
        avatarUrl: '',
        color: 'Golden',
        weight: 25.0,
      );

      // Execute
      await petService.createPet(pet);

      // Verify Cloud (Should not exist)
      final cloudDoc = await fakeFirestore.collection('pets').doc('petFree').get();
      expect(cloudDoc.exists, false);

      // Verify Local
      verify(() => mockLocalService.updatePet('petFree', any())).called(1);
    });
  });
}
