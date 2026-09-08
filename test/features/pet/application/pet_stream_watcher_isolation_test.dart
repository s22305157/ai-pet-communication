import '../../../support/pet_service_fixture.dart';
import 'dart:async';

import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPetService extends Mock implements LocalPetService {}

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

PetModel pet(String id, String owner) => PetModel(
  petId: id,
  ownerId: owner,
  name: id,
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
);

void main() {
  test(
    'free stream filters other owners and closes on account switch',
    () async {
      const uid = 'owner-b';
      final localService = MockLocalPetService();
      final authService = MockAuthService();
      final authController = StreamController<String?>();
      final localController = StreamController<List<PetModel>>();
      final user = UserModel(
        uid: uid,
        email: 'b@example.com',
        displayName: 'B',
        membershipTier: 'free',
      );

      when(() => authService.getUserData()).thenAnswer((_) async => user);
      when(
        () => authService.userIdChanges,
      ).thenAnswer((_) => authController.stream);
      when(
        () => localService.watchPets(uid),
      ).thenAnswer((_) => localController.stream);
      when(() => localService.getPendingOperations(uid)).thenReturn([]);

      final petService = buildPetService(
        firestore: MockFirebaseFirestore(),
        storage: MockFirebaseStorage(),
        localService: localService,
        authService: authService,
      );
      final results = <List<PetModel>>[];
      var streamClosed = false;
      final subscription = petService
          .watchPetsByOwner(uid)
          .listen(results.add, onDone: () => streamClosed = true);

      authController.add(uid);
      localController.add([pet('pet-a', 'owner-a'), pet('pet-b', uid)]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(results.single.map((item) => item.petId), ['pet-b']);

      authController.add('owner-a');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(results.last, isEmpty);
      expect(streamClosed, true);

      await subscription.cancel();
      await authController.close();
      await localController.close();
    },
  );
}
