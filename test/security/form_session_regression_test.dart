// Existing drafts remain owned by the account that opened the form.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/pet/application/pet_form_controller.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';

class Service extends Mock implements PetService {}

void main() {
  final original = PetModel(
    petId: 'pet-a',
    ownerId: 'a',
    name: 'A private draft',
    species: '貓',
    breed: '米克斯',
    gender: '公',
    birthday: '2020-01-01',
    personality: '活潑',
    avatarUrl: '',
    weight: 4,
  );
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(original);
  });
  testWidgets('old account form cannot save content into the next account', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var uid = 'a';
    final service = Service();
    PetModel? saved;
    when(() => service.updatePet('pet-a', any())).thenAnswer((call) async {
      saved = call.positionalArguments[1] as PetModel;
      return PetWriteResult.conflict;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetFormSheet(
            existingPet: original,
            formController: PetFormController(
              service: service,
              currentUid: () async => uid,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    uid = 'b';
    await tester.ensureVisible(find.text('儲存資料'));
    await tester.tap(find.text('儲存資料'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    verifyNever(() => service.updatePet(any(), any()));
  });
}
