import 'dart:io';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/mappers/pet_local_mapper.dart';
import 'package:ai_pet_communication/features/pet/data/mappers/pet_firestore_mapper.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class Remote extends Mock implements PetRemoteDataSource {}

class Session extends Mock implements CurrentSession {}

PetModel pet({String owner = 'u', DateTime? updated}) => PetModel(
  petId: 'p',
  ownerId: owner,
  name: 'cat',
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
  createdAt: DateTime.utc(2026, 1),
  updatedAt: updated ?? DateTime.utc(2026, 2),
);

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late LocalPetService local;
  late Remote remote;
  late PetRepositoryImpl repository;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('write-contract');
    Hive.init(temp.path);
    box = await Hive.openBox('pets');
    local = LocalPetService(box: box);
    remote = Remote();
    final session = Session();
    when(() => session.getUserData()).thenAnswer(
      (_) async => UserModel(
        uid: 'u',
        email: '',
        displayName: '',
        subscriptionVerified: true,
        membershipEntitlements: {'pro': DateTime(2100)},
        membershipTier: 'pro',
      ),
    );
    repository = PetRepositoryImpl(
      remoteDataSource: remote,
      localService: local,
      authService: session,
      clock: () => DateTime.utc(2026, 3),
    );
    registerFallbackValue(pet());
  });
  tearDown(() async {
    await box.close();
    await temp.delete(recursive: true);
  });

  test('create always includes created_at; update does not', () {
    expect(PetFirestoreMapper.create(pet()).containsKey('created_at'), true);
    expect(PetFirestoreMapper.update(pet()).containsKey('created_at'), false);
    final restored = PetLocalMapper.fromMap(PetLocalMapper.toMap(pet()));
    expect(restored.createdAt, pet().createdAt);
    expect(restored.updatedAt, pet().updatedAt);
  });
  test('unavailable writes queue; permission failures do not', () async {
    when(() => remote.setPet('p', any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    expect(await repository.createPet(pet()), PetWriteResult.pendingSync);
    expect(local.getPendingOperations('u'), hasLength(1));
    await local.clearPendingOperation('u', 'p');
    when(() => remote.setPet('p', any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await expectLater(
      repository.createPet(pet()),
      throwsA(isA<FirebaseException>()),
    );
    expect(local.getPendingOperations('u'), isEmpty);
  });
  test('newer remote is a conflict and never writes the draft', () async {
    when(
      () => remote.getPet('p'),
    ).thenAnswer((_) async => pet(updated: DateTime.utc(2026, 4)));
    expect(await repository.updatePet('p', pet()), PetWriteResult.conflict);
    verifyNever(() => remote.updatePet(any(), any()));
    expect(local.getPendingOperations('u'), isEmpty);
  });
  test('owner mismatch is a failure, never an offline operation', () async {
    when(() => remote.getPet('p')).thenAnswer((_) async => pet(owner: 'other'));
    await expectLater(
      repository.updatePet('p', pet()),
      throwsA(isA<PetWriteFailure>()),
    );
    expect(local.getPendingOperations('u'), isEmpty);
  });
}
