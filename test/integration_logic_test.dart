import 'package:ai_pet_communication/features/pet/application/pet_sync_manager.dart';
import 'package:ai_pet_communication/features/pet/data/local_pet_service.dart';
import 'package:ai_pet_communication/features/pet/data/sources/pet_remote_data_source.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPetService extends Mock implements LocalPetService {}

class MockPetRemoteDataSource extends Mock implements PetRemoteDataSource {}

PetModel pet(DateTime updatedAt) => PetModel(
  petId: 'pet-1',
  ownerId: 'owner-a',
  name: 'pet',
  species: 'cat',
  breed: '',
  gender: '',
  birthday: '',
  personality: '',
  avatarUrl: '',
  updatedAt: updatedAt,
);

void main() {
  group('PetSyncManager conflict resolution', () {
    final manager = PetSyncManager(
      localService: MockLocalPetService(),
      remoteDataSource: MockPetRemoteDataSource(),
    );

    test('newer local revision wins', () {
      expect(
        manager.resolveConflict(pet(DateTime(2026, 2)), pet(DateTime(2026, 1))),
        true,
      );
    });

    test('equal or newer cloud revision wins', () {
      expect(
        manager.resolveConflict(pet(DateTime(2026, 1)), pet(DateTime(2026, 2))),
        false,
      );
      expect(
        manager.resolveConflict(pet(DateTime(2026, 1)), pet(DateTime(2026, 1))),
        false,
      );
    });
  });
}
