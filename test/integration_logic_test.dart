import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communicator/services/pet_service.dart';
import 'package:ai_pet_communicator/services/local_pet_service.dart';
import 'package:ai_pet_communicator/services/auth_service.dart';
import 'package:ai_pet_communicator/models/pet_model.dart';
import 'package:ai_pet_communicator/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockStorage extends Mock implements FirebaseStorage {}
class MockLocalPetService extends Mock implements LocalPetService {}
class MockAuthService extends Mock implements AuthService {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late PetService petService;
  late MockFirestore mockDb;
  late MockStorage mockStorage;
  late MockLocalPetService mockLocal;
  late MockAuthService mockAuth;

  setUp(() {
    mockDb = MockFirestore();
    mockStorage = MockStorage();
    mockLocal = MockLocalPetService();
    mockAuth = MockAuthService();
    
    // 設定預設 Mock 行為
    final testUser = UserModel(
      uid: 'user123',
      email: 'test@example.com',
      displayName: 'Test User',
      membershipType: 'pro',
      points: 100,
    );
    when(() => mockAuth.getUserStream()).thenAnswer((_) => Stream.value(testUser));
    when(() => mockAuth.getUserData()).thenAnswer((_) async => testUser);
    
    petService = PetService(
      firestore: mockDb,
      storage: mockStorage,
      localService: mockLocal,
      authService: mockAuth,
    );
  });

  group('PetService Migration & Conflict Resolution', () {
    test('遷移時應正確解決衝突 (本地較新勝出)', () async {
      final uid = 'user123';
      final localPet = PetModel(
        ownerId: uid,
        name: '小乖',
        species: '狗',
        breed: '柴犬',
        gender: '公',
        birthday: '2023',
        personality: '活潑',
        avatarUrl: 'url_local',
        updatedAt: DateTime(2024, 1, 2), // 較新的時間
      );

      final cloudPet = PetModel(
        petId: 'cloud_id',
        ownerId: uid,
        name: '小乖',
        species: '狗',
        breed: '柴犬',
        gender: '公',
        birthday: '2023',
        personality: '活潑',
        avatarUrl: 'url_cloud',
        updatedAt: DateTime(2024, 1, 1), // 較舊的時間
      );

      // 模擬本地有資料
      when(() => mockLocal.getAllPets()).thenReturn([localPet]);

      // 模擬雲端查詢與監聽
      final mockCollection = MockCollectionReference();
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      final mockDoc = MockQueryDocumentSnapshot();

      when(() => mockDb.collection('pets')).thenReturn(mockCollection);
      when(() => mockCollection.where('owner_id', isEqualTo: uid)).thenReturn(mockQuery);
      when(() => mockQuery.where('name', isEqualTo: '小乖')).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockSnapshot)); // 補上這個
      
      when(() => mockSnapshot.docs).thenReturn([mockDoc]);
      when(() => mockDoc.id).thenReturn('cloud_id');
      // 手動模擬雲端資料，確保時間是舊的 (2024-01-01)
      when(() => mockDoc.data()).thenReturn({
        'owner_id': uid,
        'name': '小乖',
        'species': '狗',
        'updated_at': '2024-01-01T00:00:00.000',
      });

      // 模擬更新雲端
      final mockDocRef = MockDocumentReference();
      when(() => mockCollection.doc('cloud_id')).thenReturn(mockDocRef as DocumentReference<Map<String, dynamic>>);
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});

      // 執行測試
      await petService.watchPetsByOwner(uid).first;

      // 驗證
      verify(() => mockDocRef.update(any())).called(1);
    });

    test('更新時應防止舊資料覆蓋新雲端資料 (雲端較新勝出)', () async {
      final uid = 'user123';
      final petId = 'pet_abc';
      final mockCollection = MockCollectionReference();
      
      // 本地資料 (較舊)
      final localPet = PetModel(
        petId: petId,
        ownerId: uid,
        name: '小乖',
        species: '狗',
        breed: '柴犬',
        gender: '公',
        birthday: '2023',
        personality: '活潑',
        avatarUrl: 'url_old',
        updatedAt: DateTime(2024, 1, 1),
      );

      // 雲端資料 (較新)
      final mockDoc = MockQueryDocumentSnapshot();
      final mockDocRef = MockDocumentReference();
      
      when(() => mockDb.collection('pets')).thenReturn(mockCollection);
      when(() => mockCollection.doc(petId)).thenReturn(mockDocRef as DocumentReference<Map<String, dynamic>>);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDoc as DocumentSnapshot<Map<String, dynamic>>);
      when(() => mockDoc.exists).thenReturn(true);
      when(() => mockDoc.id).thenReturn(petId); // 補上這個
      when(() => mockDoc.data()).thenReturn({
        'owner_id': uid,
        'name': '小乖',
        'updated_at': '2024-01-02T00:00:00.000', // 雲端較新
      });

      // 執行更新
      await petService.updatePet(petId, localPet);

      // 驗證：不應該呼叫 update
      verifyNever(() => mockDocRef.update(any()));
    });
  });
}

class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
