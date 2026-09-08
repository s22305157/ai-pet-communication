import 'package:ai_pet_communication/core/storage/account_cleanup.dart';
import 'package:ai_pet_communication/features/pet/domain/repositories/owned_pet_lookup.dart';
import 'package:ai_pet_communication/features/pet/data/mappers/pet_local_mapper.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';

class LocalPetService implements OwnedPetLookup, AccountCleanup {
  static const _scopePrefix = 'user/';

  final Box _box;

  LocalPetService({Box? box}) : _box = box ?? Hive.box('local_pets');

  String _userPrefix(String uid) {
    _validateUid(uid);
    return '$_scopePrefix${Uri.encodeComponent(uid)}/pet/';
  }

  String _scopedKey(String uid, String petId) => '${_userPrefix(uid)}$petId';

  String _syncPrefix(String uid) =>
      '$_scopePrefix${Uri.encodeComponent(uid)}/sync/';

  String _syncKey(String uid, String petId) => '${_syncPrefix(uid)}$petId';

  String _tombstonePrefix(String uid) =>
      '$_scopePrefix${Uri.encodeComponent(uid)}/tombstone/';

  String _tombstoneKey(String uid, String petId) =>
      '${_tombstonePrefix(uid)}$petId';

  void _validateUid(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'User ID must not be empty.');
    }
  }

  void _validateOwner(String uid, PetModel pet) {
    _validateUid(uid);
    if (pet.ownerId != uid) {
      throw StateError('Local pet owner does not match the active user.');
    }
  }

  PetModel? _decodePet(dynamic data) {
    if (data is! Map) return null;
    try {
      return PetLocalMapper.fromMap(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  List<PetModel> getAllPets(String uid) {
    final prefix = _userPrefix(uid);
    final petsById = <String, PetModel>{};

    for (final entry in _box.toMap().entries) {
      final pet = _decodePet(entry.value);
      if (pet == null || pet.ownerId != uid) continue;

      final key = entry.key;
      if (key is String && key.startsWith(prefix)) {
        petsById[pet.petId] = pet;
      } else if (key is! String || !key.startsWith(_scopePrefix)) {
        // Legacy unscoped entries remain readable only by their recorded owner.
        petsById.putIfAbsent(pet.petId, () => pet);
      }
    }

    return petsById.values.toList(growable: false);
  }

  @override
  Future<PetModel?> getPet(String uid, String petId) async {
    final scopedPet = _decodePet(_box.get(_scopedKey(uid, petId)));
    if (scopedPet != null && scopedPet.ownerId == uid) return scopedPet;

    final legacyPet = _decodePet(_box.get(petId));
    return legacyPet?.ownerId == uid ? legacyPet : null;
  }

  Stream<List<PetModel>> watchPets(String uid) async* {
    await migrateLegacyDataForUser(uid);
    yield getAllPets(uid);
    await for (final _ in _box.watch()) {
      yield getAllPets(uid);
    }
  }

  Future<void> createPet(String uid, PetModel pet) async {
    _validateOwner(uid, pet);
    final petId = pet.petId.isEmpty ? const Uuid().v4() : pet.petId;
    final newPet = pet.copyWith(petId: petId);
    await _box.put(_scopedKey(uid, petId), PetLocalMapper.toMap(newPet));
  }

  Future<void> updatePet(String uid, String petId, PetModel pet) async {
    _validateOwner(uid, pet);
    if (pet.petId.isNotEmpty && pet.petId != petId) {
      throw StateError('Local pet ID does not match the requested record.');
    }
    await _box.put(
      _scopedKey(uid, petId),
      PetLocalMapper.toMap(pet.copyWith(petId: petId)),
    );
  }

  Future<void> deletePet(String uid, String petId) async {
    await _box.delete(_scopedKey(uid, petId));

    final legacyPet = _decodePet(_box.get(petId));
    if (legacyPet?.ownerId == uid) {
      await _box.delete(petId);
    }
  }

  Future<void> markPendingUpsert(String uid, PetModel pet) async {
    _validateOwner(uid, pet);
    await _box.put(_syncKey(uid, pet.petId), {
      'operationId': const Uuid().v4(),
      'type': 'upsert',
      'petId': pet.petId,
      'ownerId': uid,
      'pet': PetLocalMapper.toMap(pet),
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markPendingDelete(
    String uid,
    String petId, {
    String? avatarUrl,
  }) async {
    _validateUid(uid);
    final now = DateTime.now().toIso8601String();
    await _box.put(_tombstoneKey(uid, petId), {
      'petId': petId,
      'ownerId': uid,
      'deletedAt': now,
    });
    await _box.put(_syncKey(uid, petId), {
      'operationId': const Uuid().v4(),
      'type': 'delete',
      'petId': petId,
      'ownerId': uid,
      'avatarUrl': avatarUrl,
      'queuedAt': now,
    });
    await deletePet(uid, petId);
  }

  Future<void> clearPendingOperationIfUnchanged(
    String uid,
    PendingPetOperation sent,
  ) async {
    final current = _box.get(_syncKey(uid, sent.petId));
    if (current is Map &&
        current['operationId'] == sent.operationId &&
        current['queuedAt'] == sent.queuedAt?.toIso8601String() &&
        current['type'] == sent.type) {
      await _box.delete(_syncKey(uid, sent.petId));
    }
  }

  String? pendingToken(String uid, String petId) {
    final current = _box.get(_syncKey(uid, petId));
    return current is Map
        ? '${current['operationId']}/${current['queuedAt']}/${current['type']}'
        : null;
  }

  bool isPendingOperationCurrent(String uid, PendingPetOperation sent) {
    final current = _box.get(_syncKey(uid, sent.petId));
    return current is Map &&
        current['operationId'] == sent.operationId &&
        current['queuedAt'] == sent.queuedAt?.toIso8601String() &&
        current['type'] == sent.type;
  }

  List<PendingPetOperation> getPendingOperations(String uid) {
    final prefix = _syncPrefix(uid);
    final operations = <PendingPetOperation>[];
    for (final entry in _box.toMap().entries) {
      if (entry.key is! String || !(entry.key as String).startsWith(prefix)) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) continue;
      final data = Map<String, dynamic>.from(value);
      if (data['ownerId'] != uid || data['petId'] is! String) continue;
      final type = data['type'];
      if (type != 'upsert' && type != 'delete') continue;
      operations.add(
        PendingPetOperation(
          operationId: data['operationId'] as String?,
          type: type as String,
          petId: data['petId'] as String,
          ownerId: uid,
          pet: data['pet'] is Map ? _decodePet(data['pet']) : null,
          avatarUrl: data['avatarUrl'] as String?,
          queuedAt: DateTime.tryParse(data['queuedAt'] as String? ?? ''),
        ),
      );
    }
    operations.sort(
      (a, b) => (a.queuedAt ?? DateTime(2000)).compareTo(
        b.queuedAt ?? DateTime(2000),
      ),
    );
    return operations;
  }

  Future<void> clearPendingOperation(String uid, String petId) async {
    await _box.delete(_syncKey(uid, petId));
  }

  bool hasTombstone(String uid, String petId) =>
      _box.containsKey(_tombstoneKey(uid, petId));

  Future<void> clearTombstone(String uid, String petId) async {
    await _box.delete(_tombstoneKey(uid, petId));
  }

  Future<void> reconcileCloudSnapshot(
    String uid,
    List<PetModel> cloudPets,
  ) async {
    final pendingIds = getPendingOperations(
      uid,
    ).map((operation) => operation.petId).toSet();
    for (final pet in cloudPets) {
      if (pet.ownerId != uid || hasTombstone(uid, pet.petId)) continue;
      if (pendingIds.contains(pet.petId)) continue;
      await cacheCloudPet(uid, pet);
    }
  }

  Future<void> cacheCloudPet(String uid, PetModel pet) async {
    _validateOwner(uid, pet);
    final data = PetLocalMapper.toMap(pet);
    if (pet.createdAt != null) {
      data['created_at'] = pet.createdAt!.toIso8601String();
    }
    if (pet.updatedAt != null) {
      data['updated_at'] = pet.updatedAt!.toIso8601String();
    }
    await _box.put(_scopedKey(uid, pet.petId), data);
  }

  @override
  Future<void> clearUser(String uid) async {
    _validateUid(uid);
    final prefix = '$_scopePrefix${Uri.encodeComponent(uid)}/';
    final keys = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      final key = entry.key;
      final pet = _decodePet(entry.value);
      if ((key is String && key.startsWith(prefix)) ||
          (pet?.ownerId == uid &&
              (key is! String || !key.startsWith(_scopePrefix)))) {
        keys.add(key);
      }
    }
    await _box.deleteAll(keys);
  }

  Future<void> migrateLegacyDataForUser(String uid) async {
    _validateUid(uid);
    final legacyEntries = _box
        .toMap()
        .entries
        .where((entry) {
          final key = entry.key;
          return key is! String || !key.startsWith(_scopePrefix);
        })
        .toList(growable: false);

    for (final entry in legacyEntries) {
      final pet = _decodePet(entry.value);
      if (pet == null || pet.ownerId != uid || pet.petId.isEmpty) continue;

      final scopedKey = _scopedKey(uid, pet.petId);
      if (!_box.containsKey(scopedKey)) {
        // Preserve legacy timestamps so migration cannot make stale local data
        // appear newer than its cloud counterpart.
        await _box.put(scopedKey, entry.value);
      }
      await _box.delete(entry.key);
    }
  }
}

class PendingPetOperation {
  final String? operationId;
  final String type;
  final String petId;
  final String ownerId;
  final PetModel? pet;
  final String? avatarUrl;
  final DateTime? queuedAt;

  const PendingPetOperation({
    this.operationId,
    required this.type,
    required this.petId,
    required this.ownerId,
    this.pet,
    this.avatarUrl,
    this.queuedAt,
  });

  bool get isDelete => type == 'delete';
}
