import 'dart:async';
import 'package:ai_pet_communicator/models/pet_model.dart';
import 'package:ai_pet_communicator/services/pet_service.dart';
import 'package:ai_pet_communicator/services/auth_service.dart';
import 'package:ai_pet_communicator/services/local_pet_service.dart';
import 'package:ai_pet_communicator/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPetService extends Mock implements LocalPetService {}
class MockAuthService extends Mock implements AuthService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}

void main() {
  late PetService petService;
  late MockFirebaseFirestore mockFirestore;
  late MockLocalPetService mockLocalService;
  late MockAuthService mockAuthService;
  late MockFirebaseStorage mockStorage;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockLocalService = MockLocalPetService();
    mockAuthService = MockAuthService();
    mockStorage = MockFirebaseStorage();

    petService = PetService(
      firestore: mockFirestore,
      localService: mockLocalService,
      authService: mockAuthService,
      storage: mockStorage,
    );
  });

  test('watchPetsByOwner should fallback to local stream on cloud error', () async {
    // Setup user
    final user = UserModel(
      uid: 'user123',
      email: 'test@test.com',
      displayName: 'Tester',
      membershipType: 'pro',
    );

    // Mock auth stream
    final authController = StreamController<UserModel?>();
    when(() => mockAuthService.getUserStream()).thenAnswer((_) => authController.stream);
    
    // Mock cloud setup
    final mockCollection = MockCollectionReference();
    final mockQuery = MockQuery();
    when(() => mockFirestore.collection('pets')).thenReturn(mockCollection);
    when(() => mockCollection.where('owner_id', isEqualTo: 'user123')).thenReturn(mockQuery);
    
    final cloudController = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(() => mockQuery.snapshots()).thenAnswer((_) => cloudController.stream);

    // Mock local stream
    final localPets = [
      PetModel(petId: 'local1', ownerId: 'user123', name: 'LocalPet', species: 'Cat', breed: 'Siamese', gender: '母', birthday: '', personality: '', avatarUrl: '')
    ];
    final localController = StreamController<List<PetModel>>();
    when(() => mockLocalService.watchPets()).thenAnswer((_) => localController.stream);
    when(() => mockLocalService.getAllPets()).thenReturn([]);

    // Start watching
    final resultStream = petService.watchPetsByOwner('user123');
    final results = <List<PetModel>>[];
    final subscription = resultStream.listen((data) => results.add(data));

    // 1. Emit user
    authController.add(user);
    await Future.delayed(Duration(milliseconds: 100));

    // 2. Emit cloud error
    cloudController.addError(Exception('Cloud failure'));
    await Future.delayed(Duration(milliseconds: 100));

    // 3. Emit local data
    localController.add(localPets);
    await Future.delayed(Duration(milliseconds: 100));

    // Verify
    expect(results.last, localPets);
    expect(petService.isCloudActive.value, false);

    await subscription.cancel();
    await authController.close();
    await cloudController.close();
    await localController.close();
  });
}
