import 'package:ai_pet_communication/features/pet/application/pet_form_controller.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Service extends Mock implements PetService {}

void main() {
  test(
    'save passes conflict to the caller without global authentication',
    () async {
      final service = Service();
      final draft = PetModel(
        petId: 'p',
        ownerId: 'u',
        name: 'draft',
        species: '',
        breed: '',
        gender: '',
        birthday: '',
        personality: '',
        avatarUrl: '',
      );
      when(
        () => service.updatePet('p', draft),
      ).thenAnswer((_) async => PetWriteResult.conflict);
      final controller = PetFormController(
        service: service,
        currentUid: () async => 'u',
      );
      expect(
        await controller.save(draft, isNew: false),
        PetWriteResult.conflict,
      );
      expect(draft.name, 'draft');
      expect(
        PetFormController.message(PetWriteResult.conflict),
        contains('草稿已保留'),
      );
    },
  );
}
