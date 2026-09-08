import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/repositories/pet_repository_impl.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';

class Remote extends Mock implements PetRemoteDataSource {}

class Session extends Mock implements CurrentSession {}

void main() {
  test(
    'offline delete reports pending and old-account delete is rejected',
    () async {
      final temp = await Directory.systemTemp.createTemp('delete-contract-');
      Hive.init(temp.path);
      final box = await Hive.openBox<dynamic>('delete_contract');
      final session = Session();
      final remote = Remote();
      when(() => session.getUserData()).thenAnswer(
        (_) async => UserModel(uid: 'a', email: '', displayName: 'A'),
      );
      when(
        () => remote.deletePet('p', avatarUrl: null),
      ).thenThrow(FirebaseException(plugin: 'functions', code: 'unavailable'));
      final local = LocalPetService(box: box);
      final repo = PetRepositoryImpl(
        remoteDataSource: remote,
        localService: local,
        authService: session,
      );
      expect(
        await repo.deletePet('p', expectedOwnerId: 'a'),
        PetWriteResult.pendingSync,
      );
      expect(local.getPendingOperations('a').single.isDelete, true);
      when(() => session.getUserData()).thenAnswer(
        (_) async => UserModel(uid: 'b', email: '', displayName: 'B'),
      );
      await expectLater(
        repo.deletePet('p', expectedOwnerId: 'a'),
        throwsA(isA<PetWriteFailure>()),
      );
      verify(() => remote.deletePet('p', avatarUrl: null)).called(1);
      await box.deleteFromDisk();
      await temp.delete();
    },
  );
}
