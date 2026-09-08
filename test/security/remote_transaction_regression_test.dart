import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';

class Storage extends Mock implements FirebaseStorage {}

PetModel pet(String name) => PetModel(
  petId: 'p',
  ownerId: 'a',
  name: name,
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
);
void main() {
  test(
    'remote transaction rejects a stale revision instead of overwriting it',
    () async {
      final remote = PetRemoteDataSource(
        firestore: FakeFirebaseFirestore(),
        storage: Storage(),
      );
      await remote.setPet('p', pet('initial'));
      final current = (await remote.getPet('p'))!;
      await expectLater(
        remote.updatePet('p', pet('stale'), expectedUpdatedAt: DateTime(2000)),
        throwsA(isA<PetVersionConflict>()),
      );
      expect((await remote.getPet('p'))!.name, 'initial');
      await remote.updatePet(
        'p',
        pet('accepted'),
        expectedUpdatedAt: current.updatedAt,
      );
      expect((await remote.getPet('p'))!.name, 'accepted');
    },
  );
  test(
    'create cannot overwrite an existing pet and update checks owner',
    () async {
      final remote = PetRemoteDataSource(
        firestore: FakeFirebaseFirestore(),
        storage: Storage(),
      );
      await remote.setPet('p', pet('initial'));
      await expectLater(
        remote.setPet('p', pet('overwrite')),
        throwsA(isA<PetVersionConflict>()),
      );
      final current = (await remote.getPet('p'))!;
      await expectLater(
        remote.updatePet(
          'p',
          pet('other').copyWith(ownerId: 'b'),
          expectedUpdatedAt: current.updatedAt,
        ),
        throwsA(isA<PetVersionConflict>()),
      );
    },
  );
}
