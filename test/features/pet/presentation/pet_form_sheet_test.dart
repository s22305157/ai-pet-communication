import 'dart:async';
import 'package:ai_pet_communication/features/pet/application/pet_form_controller.dart';
import 'package:ai_pet_communication/features/pet/application/pet_service.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_write_result.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class Service extends Mock implements PetService {}

void main() {
  final pet = PetModel(
    petId: 'p',
    ownerId: 'u',
    name: 'draft',
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
    registerFallbackValue(pet);
  });
  Future<void> showForm(WidgetTester tester, Service service) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetFormSheet(
            existingPet: pet,
            formController: PetFormController(
              service: service,
              currentUid: () async => 'u',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('儲存資料'));
  }

  testWidgets(
    'conflict keeps the form and its draft without Firebase or GetIt',
    (tester) async {
      final service = Service();
      when(
        () => service.updatePet('p', any()),
      ).thenAnswer((_) async => PetWriteResult.conflict);
      await showForm(tester, service);
      await tester.tap(find.text('儲存資料'));
      await tester.pumpAndSettle();
      expect(find.byType(PetFormSheet), findsOneWidget);
      expect(find.textContaining('草稿已保留'), findsOneWidget);
      expect(find.text('draft'), findsOneWidget);
    },
  );
  testWidgets('closing the form during save never updates disposed state', (
    tester,
  ) async {
    final service = Service();
    final saved = Completer<PetWriteResult>();
    when(() => service.updatePet('p', any())).thenAnswer((_) => saved.future);
    await showForm(tester, service);
    await tester.tap(find.text('儲存資料'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    saved.complete(PetWriteResult.saved);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
