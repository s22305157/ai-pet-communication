import 'package:ai_pet_communicator/services/auth_service.dart';
import 'package:ai_pet_communicator/services/local_pet_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockLocalPetService extends Mock implements LocalPetService {}

void main() {
  late AuthService authService;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockLocalPetService mockLocalService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockLocalService = MockLocalPetService();
    
    authService = AuthService(
      auth: mockAuth,
      firestore: fakeFirestore,
      localService: mockLocalService,
    );
  });

  test('consumePoints should decrement points in Firestore using FieldValue.increment', () async {
    // Setup
    const uid = 'user123';
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn(uid);
    
    await fakeFirestore.collection('Users').doc(uid).set({
      'uid': uid,
      'points': 10,
    });

    // Execute
    await authService.consumePoints(1);

    // Verify
    final doc = await fakeFirestore.collection('Users').doc(uid).get();
    expect(doc.data()?['points'], 9);
  });

  test('consumePoints should do nothing if no user is logged in', () async {
    // Setup
    when(() => mockAuth.currentUser).thenReturn(null);
    
    // Execute
    await authService.consumePoints(1);
    
    // Verify (No crash, no collection created)
    final collections = await fakeFirestore.collection('Users').get();
    expect(collections.docs.isEmpty, true);
  });
}
