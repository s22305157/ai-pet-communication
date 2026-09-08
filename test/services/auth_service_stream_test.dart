import 'dart:async';

import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

Map<String, dynamic> userData({
  required String uid,
  bool onboarding = false,
  int points = 1,
  String tier = 'free',
}) {
  return {
    'uid': uid,
    'email': '$uid@example.com',
    'displayName': uid,
    'points': points,
    'membershipTier': tier,
    'hasCompletedOnboarding': onboarding,
  };
}

void main() {
  test('emits updated user after onboarding Firestore update', () async {
    const uid = 'user-a';
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    final user = MockUser();
    final authStates = StreamController<User?>();

    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn('a@example.com');
    when(() => user.displayName).thenReturn('A');
    when(() => user.photoURL).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => authStates.stream);
    when(() => auth.currentUser).thenReturn(user);
    await firestore.collection('users').doc(uid).set(userData(uid: uid));

    final service = AuthService(auth: auth, firestore: firestore);
    final events = <UserModel?>[];
    final subscription = service.getUserStream().listen(events.add);

    authStates.add(user);
    await service
        .getUserStream()
        .firstWhere((value) => value?.uid == uid)
        .timeout(const Duration(seconds: 2));
    expect(events.last?.hasCompletedOnboarding, false);
    final eventCountBeforeUpdate = events.length;

    await service.updateOnboardingStatus(true, const {'goal': 'bonding'});
    final updated = await service
        .getUserStream()
        .firstWhere((value) => value?.hasCompletedOnboarding == true)
        .timeout(const Duration(seconds: 2));

    expect(updated?.hasCompletedOnboarding, true);
    expect(events.length, greaterThan(eventCountBeforeUpdate));

    await subscription.cancel();
    await authStates.close();
  });

  test('cancels the previous user document stream on account switch', () async {
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    final userA = MockUser();
    final userB = MockUser();
    final authStates = StreamController<User?>();

    when(() => userA.uid).thenReturn('user-a');
    when(() => userB.uid).thenReturn('user-b');
    when(() => auth.authStateChanges()).thenAnswer((_) => authStates.stream);
    await firestore
        .collection('users')
        .doc('user-a')
        .set(userData(uid: 'user-a', points: 10));
    await firestore
        .collection('users')
        .doc('user-b')
        .set(userData(uid: 'user-b', points: 20));

    final service = AuthService(auth: auth, firestore: firestore);
    final events = <UserModel?>[];
    final subscription = service.getUserStream().listen(events.add);

    authStates.add(userA);
    await service
        .getUserStream()
        .firstWhere((value) => value?.uid == 'user-a')
        .timeout(const Duration(seconds: 2));
    authStates.add(userB);
    await service
        .getUserStream()
        .firstWhere((value) => value?.uid == 'user-b')
        .timeout(const Duration(seconds: 2));

    await firestore.collection('users').doc('user-a').update({'points': 99});
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(events.last?.uid, 'user-b');
    expect(events.last?.points, 20);

    await subscription.cancel();
    await authStates.close();
  });
}
