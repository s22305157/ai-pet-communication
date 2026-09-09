import 'dart:async';
import 'dart:io';

import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockPetRemoteDataSource extends Mock implements PetRemoteDataSource {}

class MockAuthService extends Mock implements AuthService {}

PetModel pet(String id) => PetModel(
  petId: id,
  ownerId: 'owner-a',
  name: id,
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
);

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pawlink-stream-recovery-',
    );
    Hive.init(hiveDirectory.path);
    box = await Hive.openBox<dynamic>('pet_stream_recovery_test');
  });

  setUp(() => box.clear());

  test(
    'downgraded member imports missing archive pets without overwriting local edits',
    () async {
      const uid = 'owner-a';
      final local = LocalPetService(box: box);
      final remote = MockPetRemoteDataSource();
      final auth = MockAuthService();
      final user = UserModel(
        uid: uid,
        email: '',
        displayName: '',
        membershipTier: 'free',
        hadPaidMembership: true,
      );
      when(() => auth.getUserData()).thenAnswer((_) async => user);
      when(() => auth.userIdChanges).thenAnswer((_) => Stream.value(uid));
      await local.updatePet(
        uid,
        'edited',
        pet('edited').copyWith(name: 'local edit'),
      );
      await local.markPendingDelete(uid, 'deleted');
      await local.clearPendingOperation(uid, 'deleted');
      when(() => remote.watchPetsByOwner(uid)).thenAnswer(
        (_) => Stream.value([pet('edited'), pet('archive'), pet('deleted')]),
      );
      final sync = PetSyncManager(
        localService: local,
        remoteDataSource: remote,
      );
      final watcher = PetStreamWatcher(
        remoteDataSource: remote,
        localService: local,
        authService: auth,
        syncManager: sync,
      );
      final result = await watcher.watchPetsByOwner(uid).first;
      expect(result.map((p) => p.petId), containsAll(['edited', 'archive']));
      expect(result.map((p) => p.petId), isNot(contains('deleted')));
      expect(result.singleWhere((p) => p.petId == 'edited').name, 'local edit');
      verify(() => remote.watchPetsByOwner(uid)).called(1);
      verifyNoMoreInteractions(remote);
      sync.dispose();
    },
  );

  tearDownAll(() async {
    await box.deleteFromDisk();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'cloud recovery refreshes cache and cancels the fallback stream',
    () async {
      const uid = 'owner-a';
      final local = LocalPetService(box: box);
      final remote = MockPetRemoteDataSource();
      final auth = MockAuthService();
      final cloud = StreamController<List<PetModel>>();
      final user = UserModel(
        uid: uid,
        email: 'a@example.com',
        displayName: 'A',
        subscriptionVerified: true,
        membershipEntitlements: {'pro': DateTime(2100)},
        membershipTier: 'pro',
      );
      when(() => auth.getUserData()).thenAnswer((_) async => user);
      when(() => auth.userIdChanges).thenAnswer((_) => Stream.value(uid));
      when(() => remote.watchPetsByOwner(uid)).thenAnswer((_) => cloud.stream);
      when(
        () => remote.getPetDeletionTime(any()),
      ).thenAnswer((_) async => null);
      final sync = PetSyncManager(
        localService: local,
        remoteDataSource: remote,
      );
      final watcher = PetStreamWatcher(
        remoteDataSource: remote,
        localService: local,
        authService: auth,
        syncManager: sync,
      );
      final results = <List<PetModel>>[];
      final subscription = watcher.watchPetsByOwner(uid).listen(results.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      cloud.addError(Exception('offline'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await local.updatePet(uid, 'local', pet('local'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(results.last.map((item) => item.petId), contains('local'));
      expect(sync.isCloudActive.value, false);

      cloud.add([pet('cloud')]);
      for (
        var attempt = 0;
        attempt < 20 && !sync.isCloudActive.value;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(results.last.map((item) => item.petId), contains('cloud'));
      expect(sync.isCloudActive.value, true);
      final countAfterRecovery = results.length;

      await local.updatePet(uid, 'after-recovery', pet('after-recovery'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(results.length, countAfterRecovery);

      await subscription.cancel();
      await cloud.close();
    },
  );
}
