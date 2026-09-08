// Diagnostic reproductions: these tests document current defects, not acceptance criteria.
// Run explicitly: flutter test --no-pub scratch/audit_20260907_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class MockAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockReadings extends Mock implements ReadingService {}
class MockAuthService extends Mock implements AuthService {}
class MockLocal extends Mock implements LocalPetService {}
class MockRemote extends Mock implements PetRemoteDataSource {}
class MockSync extends Mock implements PetSyncManager {}

void main() {
  test('REPRO: real ChatService always produces fallback for valid request', () async {
    final controller = ChatController(ChatService(), MockReadings());
    final result = await controller.handleCommunication('pet-a', AiRequestModel(
      ownerProfile: const OwnerProfile(experienceLevel: 'new', careStyle: 'gentle',
        emotionStyle: 'calm', dailyRoutine: 'stable', mainConcern: 'play'),
      petProfile: const PetProfile(name: 'Pet', species: 'dog', breed: 'mixed',
        age: 3, coatColor: 'brown', personalityTraits: ['gentle']),
      story: '今天毛孩在玩球', questions: ['開心嗎？'], inputMode: 'free',
    ));
    expect(result, isA<AiResponseModel>());
    expect((result as AiResponseModel).version, 'fallback-1');
  });

  test('REPRO: onboarding is saved but auth stream remains incomplete', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockAuth();
    final user = MockUser();
    final events = StreamController<User?>();
    when(() => user.uid).thenReturn('owner-a');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => events.stream);
    await db.collection('users').doc('owner-a').set({
      'uid': 'owner-a', 'points': 1, 'hasCompletedOnboarding': false,
    });
    final service = AuthService(auth: auth, firestore: db);
    final received = <UserModel?>[];
    final first = Completer<void>();
    final sub = service.getUserStream().listen((value) {
      received.add(value);
      if (!first.isCompleted) first.complete();
    });
    events.add(user);
    await first.future.timeout(const Duration(seconds: 3));
    await service.updateOnboardingStatus(true, {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await db.collection('users').doc('owner-a').get()).data()!['hasCompletedOnboarding'], true);
    expect(received.last!.hasCompletedOnboarding, false);
    expect(received.length, 1);
    await sub.cancel();
    await events.close();
  });

  test('REPRO: account B receives account A pets from local stream', () async {
    final local = MockLocal();
    final auth = MockAuthService();
    final petA = PetModel(petId: 'pet-a', ownerId: 'owner-a', name: 'Private Pet',
      species: 'dog', breed: '', gender: '', birthday: '', personality: '', avatarUrl: '');
    when(() => auth.getUserData()).thenAnswer((_) async => UserModel(
      uid: 'owner-b', email: '', displayName: 'B', membershipTier: 'free'));
    when(() => local.watchPets()).thenAnswer((_) => Stream.value([petA]));
    final watcher = PetStreamWatcher(remoteDataSource: MockRemote(),
      localService: local, authService: auth, syncManager: MockSync());
    final pets = await watcher.watchPetsByOwner('owner-b').first;
    expect(pets.single.ownerId, 'owner-a');
  });

  test('REPRO: two concurrent deductions can take one point below zero', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockAuth();
    final user = MockUser();
    when(() => user.uid).thenReturn('owner-a');
    when(() => auth.currentUser).thenReturn(user);
    await db.collection('users').doc('owner-a').set({'uid': 'owner-a', 'points': 1});
    final service = AuthService(auth: auth, firestore: db);
    await Future.wait([service.consumePoints(1), service.consumePoints(1)]);
    expect((await db.collection('users').doc('owner-a').get()).data()!['points'], -1);
  });
}
