import 'package:ai_pet_communication/core/session/current_session.dart';
import 'package:ai_pet_communication/core/storage/storage_policy.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/owned_pet_lookup.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';

import 'package:ai_pet_communication/features/readings/domain/local_readings_store.dart';
import 'package:ai_pet_communication/features/readings/domain/readings_repository.dart';

class AccountReadingsRepository implements ReadingsRepository {
  final CurrentSession _authService;
  final OwnedPetLookup _localPets;
  final LocalReadingsStore _localReadings;
  final ReadingsRepository _cloudReadings;

  AccountReadingsRepository({
    required CurrentSession authService,
    required OwnedPetLookup localPets,
    required LocalReadingsStore localReadings,
    required ReadingsRepository cloudReadings,
  }) : _authService = authService,
       _localPets = localPets,
       _localReadings = localReadings,
       _cloudReadings = cloudReadings;

  Future<({String uid, bool useLocal})> _scope(String petId) async {
    final user = await _authService.getUserData();
    if (user == null) throw StateError('Authentication required.');
    if (!const StoragePolicy().usesCloud(user.membershipType)) {
      final pet = await _localPets.getPet(user.uid, petId);
      if (pet == null || pet.ownerId != user.uid) {
        throw StateError('Local pet does not belong to the active user.');
      }
      return (uid: user.uid, useLocal: true);
    }
    return (uid: user.uid, useLocal: false);
  }

  @override
  Stream<List<Reading>> watchReadingsByPetId(String petId) async* {
    final scope = await _scope(petId);
    if (scope.useLocal) {
      yield* _localReadings.watchReadings(scope.uid, petId);
    } else {
      yield* _cloudReadings.watchReadingsByPetId(petId);
    }
  }

  @override
  Future<Reading?> getReadingById(String petId, String readingId) async {
    final scope = await _scope(petId);
    return scope.useLocal
        ? _localReadings.getReading(scope.uid, petId, readingId)
        : _cloudReadings.getReadingById(petId, readingId);
  }

  @override
  Future<void> addReading(Reading reading) async {
    final scope = await _scope(reading.petId);
    if (scope.useLocal) {
      await _localReadings.addReading(scope.uid, reading);
    } else {
      await _cloudReadings.addReading(reading);
    }
  }

  @override
  Future<void> deleteReading(String petId, String readingId) async {
    final scope = await _scope(petId);
    if (scope.useLocal) {
      await _localReadings.deleteReading(scope.uid, petId, readingId);
    } else {
      await _cloudReadings.deleteReading(petId, readingId);
    }
  }
}
