// Regression coverage for session and write ordering fixes.
// Isolated fake services and temporary Hive data; no production calls.
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/application/pet_stream_watcher.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/readings/data/account_readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';
import 'package:ai_pet_communication/features/readings/domain/local_readings_store.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';

class Remote extends Mock implements PetRemoteDataSource {}

class CloudReadings extends Mock implements ReadingsRepository {}

class LocalReadings extends Mock implements LocalReadingsStore {}

class Session implements CurrentSession {
  String uid = 'a';
  String tier = 'free';
  final changes = StreamController<String?>.broadcast();
  @override
  Future<UserModel?> getUserData() async => UserModel(
    uid: uid,
    email: '',
    displayName: uid,
    subscriptionVerified: true,
    membershipEntitlements: {tier: DateTime(2100)},
    membershipTier: tier,
  );
  @override
  Stream<String?> get userIdChanges => changes.stream;
}

PetModel pet(String name, int month) => PetModel(
  petId: 'pet',
  ownerId: 'a',
  name: name,
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
  updatedAt: DateTime(2026, month),
);
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late Directory temp;
  late Box<dynamic> petsBox;
  late Box<dynamic> readingsBox;
  late LocalPetService local;
  late Session session;
  setUpAll(() {
    registerFallbackValue(pet('fallback', 1));
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pawlink-recheck-');
    Hive.init(temp.path);
    petsBox = await Hive.openBox<dynamic>('audit_pets');
    readingsBox = await Hive.openBox<dynamic>('audit_readings');
    local = LocalPetService(box: petsBox);
    session = Session();
  });
  tearDown(() async {
    await session.changes.close();
    await petsBox.deleteFromDisk();
    await readingsBox.deleteFromDisk();
    await temp.delete();
  });

  test('reading stream closes and clears data when account changes', () async {
    await local.updatePet('a', 'pet', pet('A pet', 1));
    final readings = LocalReadings();
    final source = StreamController<List<Reading>>.broadcast();
    when(
      () => readings.watchReadings('a', 'pet'),
    ).thenAnswer((_) => source.stream);
    final repo = AccountReadingsRepository(
      authService: session,
      localPets: local,
      localReadings: readings,
      cloudReadings: CloudReadings(),
    );
    final events = <List<Reading>>[];
    final initial = Completer<void>();
    final closed = Completer<void>();
    final sub = repo.watchReadingsByPetId('pet').listen((data) {
      events.add(data);
      if (!initial.isCompleted) initial.complete();
    }, onDone: closed.complete);
    await settle();
    source.add([]);
    await initial.future.timeout(const Duration(seconds: 2));
    await settle();
    session.uid = 'b';
    session.changes.add('b');
    source.add([
      Reading(
        id: 'r',
        petId: 'pet',
        title: '',
        content: 'A secret',
        createdAt: DateTime(2026),
      ),
    ]);
    await closed.future.timeout(const Duration(seconds: 2));
    expect(
      events.expand((e) => e).where((e) => e.content == 'A secret'),
      isEmpty,
    );
    expect(events.last, isEmpty);
    await sub.cancel();
    await source.close();
  });

  test(
    'multiple same-account pet subscribers continue to receive updates',
    () async {
      session.tier = 'pro';
      final remote = Remote();
      final snapshots = StreamController<List<PetModel>>.broadcast();
      when(
        () => remote.watchPetsByOwner('a'),
      ).thenAnswer((_) => snapshots.stream);
      when(
        () => remote.getPetDeletionTime(any()),
      ).thenAnswer((_) async => null);
      final manager = PetSyncManager(
        localService: local,
        remoteDataSource: remote,
      );
      final watcher = PetStreamWatcher(
        remoteDataSource: remote,
        localService: local,
        authService: session,
        syncManager: manager,
      );
      var firstCount = 0;
      final firstReceived = Completer<void>();
      final secondReceived = Completer<void>();
      final first = watcher.watchPetsByOwner('a').listen((_) {
        firstCount++;
        if (!firstReceived.isCompleted) firstReceived.complete();
      });
      await settle();
      snapshots.add([]);
      await firstReceived.future.timeout(const Duration(seconds: 2));
      final before = firstCount;
      final second = watcher.watchPetsByOwner('a').listen((_) {
        if (!secondReceived.isCompleted) secondReceived.complete();
      });
      await settle();
      snapshots.add([]);
      await secondReceived.future.timeout(const Duration(seconds: 2));
      await settle();
      expect(firstCount, greaterThan(before));
      await first.cancel();
      await second.cancel();
      await snapshots.close();
      manager.dispose();
    },
  );

  test(
    'old sync conflict preserves a newer local draft and pending operation',
    () async {
      final remote = Remote();
      final waiting = Completer<PetModel?>();
      final entered = Completer<void>();
      when(
        () => remote.getPetDeletionTime('pet'),
      ).thenAnswer((_) async => null);
      when(() => remote.getPet('pet')).thenAnswer((_) {
        entered.complete();
        return waiting.future;
      });
      await local.updatePet('a', 'pet', pet('old', 1));
      await local.markPendingUpsert('a', pet('old', 1));
      final manager = PetSyncManager(
        localService: local,
        remoteDataSource: remote,
      );
      final run = manager.syncPendingOperations('a');
      await entered.future;
      await local.updatePet('a', 'pet', pet('new draft', 3));
      await local.markPendingUpsert('a', pet('new draft', 3));
      waiting.complete(pet('cloud', 2));
      await run;
      expect((await local.getPet('a', 'pet'))!.name, 'new draft');
      expect(local.getPendingOperations('a').single.pet!.name, 'new draft');
      manager.dispose();
    },
  );

  test('direct online write preserves a newer pending operation', () async {
    session.tier = 'pro';
    final remote = Remote();
    final waiting = Completer<void>();
    final entered = Completer<void>();
    when(() => remote.getPet('pet')).thenAnswer((_) async => pet('base', 1));
    when(
      () => remote.updatePet(
        'pet',
        any(),
        expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
      ),
    ).thenAnswer((_) {
      entered.complete();
      return waiting.future;
    });
    final repo = PetRepositoryImpl(
      remoteDataSource: remote,
      localService: local,
      authService: session,
      clock: () => DateTime(2026, 2),
    );
    final run = repo.updatePet('pet', pet('online edit', 1));
    await entered.future;
    await local.updatePet('a', 'pet', pet('newer edit', 3));
    await local.markPendingUpsert('a', pet('newer edit', 3));
    waiting.complete();
    await run;
    expect(local.getPendingOperations('a').single.pet!.name, 'newer edit');
    expect((await local.getPet('a', 'pet'))!.name, 'newer edit');
  });
}
