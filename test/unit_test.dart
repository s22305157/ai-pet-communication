import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communicator/models/pet_model.dart';
import 'package:ai_pet_communicator/models/user_model.dart';

void main() {
  group('PetModel Tests', () {
    test('PetModel toMap 轉換驗證', () {
      final pet = PetModel(
        ownerId: 'user123',
        name: '小乖',
        species: '狗',
        breed: '柴犬',
        gender: '公',
        birthday: '2023-01-01',
        personality: '活潑',
        avatarUrl: 'https://example.com/avatar.jpg',
        color: '奶油色',
        weight: 10.5,
      );

      final map = pet.toMap();
      expect(map['name'], '小乖');
      expect(map['weight'], 10.5);
      expect(map['owner_id'], 'user123');
      expect(map['avatar_url'], 'https://example.com/avatar.jpg');
    });

    test('PetModel copyWith 驗證', () {
      final pet = PetModel(
        ownerId: 'user123',
        name: '小乖',
        species: '狗',
        breed: '柴犬',
        gender: '公',
        birthday: '2023-01-01',
        personality: '活潑',
        avatarUrl: 'url1',
      );

      final updatedPet = pet.copyWith(name: '大乖', weight: 12.0);
      expect(updatedPet.name, '大乖');
      expect(updatedPet.weight, 12.0);
      expect(updatedPet.ownerId, 'user123'); // 保持不變
    });
  });

  group('UserModel Tests', () {
    test('UserModel 點數初始化驗證', () {
      final user = UserModel(
        uid: 'uid1',
        email: 'test@test.com',
        displayName: 'Tester',
        points: 5,
      );
      expect(user.points, 5);
      expect(user.membershipType, 'free'); // 預設應為 free
    });
  });
}
