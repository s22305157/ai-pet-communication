import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/planet/data/firebase_planet_collection_repository.dart';
import 'package:ai_pet_communication/features/planet/domain/planet_collection_repository.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

void main() {
  test(
    'account switches clear old cards and detach the previous collection',
    () async {
      final auth = _Auth();
      final accounts = StreamController<User?>();
      when(() => auth.authStateChanges()).thenAnswer((_) => accounts.stream);
      final first = _User(), second = _User();
      when(() => first.uid).thenReturn('first');
      when(() => second.uid).thenReturn('second');
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('users/first/planetCards/001').set({});
      await firestore.doc('users/second/planetCards/002').set({});
      final values = StreamIterator(
        FirebasePlanetCollectionRepository(
          auth: auth,
          firestore: firestore,
        ).watch(),
      );
      addTearDown(() async {
        await values.cancel();
        await accounts.close();
      });

      Future<PlanetCollection> next() async {
        expect(
          await values.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        return values.current;
      }

      for (final (user, id) in [(first, '001'), (second, '002')]) {
        accounts.add(user);
        final loading = await next();
        expect(loading.status, CollectionStatus.loading);
        expect(loading.ids, isEmpty);
        final ready = await next();
        expect(ready.status, CollectionStatus.ready);
        expect(ready.ids, {id});
      }

      await firestore.doc('users/first/planetCards/003').set({});
      accounts.add(null);
      final signedOut = await next();
      expect(signedOut.status, CollectionStatus.signedOut);
      expect(signedOut.ids, isEmpty);
    },
  );
}
