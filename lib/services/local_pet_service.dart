import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/pet_model.dart';

class LocalPetService {
  final Box _box = Hive.box('local_pets');

  // 取得所有本地寵物列表
  List<PetModel> getAllPets() {
    return _box.values.map((data) {
      final map = Map<String, dynamic>.from(data as Map);
      return PetModel.fromMap(map);
    }).toList();
  }

  // 取得單一本地寵物
  Future<PetModel?> getPet(String petId) async {
    final data = _box.get(petId);
    if (data == null) return null;
    return PetModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // 監聽本地寵物資料流 (立即發送初始值)
  Stream<List<PetModel>> watchPets() async* {
    yield getAllPets();
    await for (final _ in _box.watch()) {
      yield getAllPets();
    }
  }

  // 建立本地寵物
  Future<void> createPet(PetModel pet) async {
    final petId = pet.petId.isEmpty ? const Uuid().v4() : pet.petId;
    final newPet = pet.copyWith(petId: petId);
    await _box.put(petId, newPet.toMap(isLocal: true));
  }

  // 更新本地寵物
  Future<void> updatePet(String petId, PetModel pet) async {
    await _box.put(petId, pet.toMap(isLocal: true));
  }

  // 刪除本地寵物
  Future<void> deletePet(String petId) async {
    await _box.delete(petId);
  }

  // 清空所有本地資料
  Future<void> clearAll() async {
    await _box.clear();
  }
}
