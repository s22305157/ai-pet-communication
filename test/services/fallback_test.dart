import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'dart:async';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPetService extends Mock implements LocalPetService {}

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockRemote extends Mock implements PetRemoteDataSource {}

void main() {
  late PetStreamWatcher watcher;
  late PetSyncManager sync;
  late MockRemote remote;
  late MockLocalPetService mockLocalService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockLocalService = MockLocalPetService();
    mockAuthService = MockAuthService();

    remote = MockRemote();
    sync = PetSyncManager(
      localService: mockLocalService,
      remoteDataSource: remote,
    );
    watcher = PetStreamWatcher(
      remoteDataSource: remote,
      localService: mockLocalService,
      authService: mockAuthService,
      syncManager: sync,
    );
  });

  test(
    'watchPetsByOwner should fallback to local stream on cloud error',
    () async {
      // Setup user
      final user = UserModel(
        uid: 'user123',
        email: 'test@test.com',
        displayName: 'Tester',
        subscriptionVerified: true,
        membershipEntitlements: {'pro': DateTime(2100)},
        membershipTier: 'pro',
      );

      when(() => mockAuthService.getUserData()).thenAnswer((_) async => user);
      when(
        () => mockAuthService.userIdChanges,
      ).thenAnswer((_) => Stream.value(user.uid));

      // Mock cloud setup
      final cloudController = StreamController<List<PetModel>>();
      when(
        () => remote.watchPetsByOwner(user.uid),
      ).thenAnswer((_) => cloudController.stream);

      final localPets = [
        PetModel(
          petId: 'local1',
          ownerId: 'user123',
          name: 'LocalPet',
          species: 'Cat',
          breed: 'Siamese',
          gender: '母',
          birthday: '',
          personality: '',
          avatarUrl: '',
        ),
      ];
      final localController = StreamController<List<PetModel>>();
      when(
        () => mockLocalService.watchPets(user.uid),
      ).thenAnswer((_) => localController.stream);
      when(() => mockLocalService.getAllPets(user.uid)).thenReturn([]);
      when(
        () => mockLocalService.migrateLegacyDataForUser(user.uid),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalService.getPendingOperations(user.uid),
      ).thenReturn([]);

      // Start watching
      final resultStream = watcher.watchPetsByOwner('user123');
      final results = <List<PetModel>>[];
      final subscription = resultStream.listen((data) {
        results.add(data);
      });

      // 1. Wait a bit for initialization
      await Future.delayed(Duration(milliseconds: 100));

      // 2. Emit cloud error
      cloudController.addError(Exception('Cloud failure'));
      await Future.delayed(Duration(milliseconds: 100));

      // 3. Emit local data
      localController.add(localPets);
      await Future.delayed(Duration(milliseconds: 100));

      // Verify
      expect(results.last, localPets);
      expect(sync.isCloudActive.value, false);

      await subscription.cancel();
      await cloudController.close();
      await localController.close();
    },
  );
}
