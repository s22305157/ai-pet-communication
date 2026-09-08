import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/pet_communication_input_screen.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/services/credit_service.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockCreditService extends Mock implements CreditService {}

class MockChatController extends Mock implements ChatController {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  const reservationId = 'reservation-123456';
  late MockCreditService creditService;
  late MockChatController chatController;
  late PetModel pet;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(
      AiRequestModel(
        ownerProfile: const OwnerProfile(
          experienceLevel: 'test',
          careStyle: 'test',
          emotionStyle: 'test',
          dailyRoutine: 'test',
          mainConcern: 'test',
        ),
        petProfile: const PetProfile(
          name: 'Buddy',
          species: 'dog',
          breed: 'mix',
          age: 3,
          coatColor: 'brown',
          personalityTraits: <String>['friendly'],
        ),
        story: 'story',
        questions: const <String>['question'],
        inputMode: 'free',
      ),
    );
  });

  setUp(() async {
    await getIt.reset();
    creditService = MockCreditService();
    chatController = MockChatController();
    getIt.registerSingleton<CreditService>(creditService);
    getIt.registerSingleton<ChatController>(chatController);
    final authService = MockAuthService();
    getIt.registerSingleton<AuthService>(authService);
    when(() => authService.getUserData()).thenAnswer(
      (_) async => UserModel(
        uid: 'user-1',
        email: 'test@example.com',
        displayName: 'test',
        membershipTier: 'plus',
      ),
    );
    when(
      () => creditService.releaseCommunication(reservationId),
    ).thenAnswer((_) async {});
    pet = PetModel(
      petId: 'pet-1',
      ownerId: 'user-1',
      name: 'Buddy',
      species: '狗',
      breed: '米克斯',
      gender: '公',
      birthday: '2023-01-01',
      personality: '親人',
      avatarUrl: '',
    );
  });

  tearDown(() async => getIt.reset());

  testWidgets(
    'without a reservation AI failure does not call any credit operation',
    (tester) async {
      when(
        () => chatController.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: null,
        ),
      ).thenAnswer(
        (_) async => CommunicationOutcome(
          response: AiResponseModel.safeFallback(),
          isFallback: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: PetCommunicationInputScreen(pet: pet)),
      );
      await tester.enterText(find.byType(TextField).at(0), '今天精神不錯');
      await tester.enterText(find.byType(TextField).at(1), '牠開心嗎？');
      await tester.ensureVisible(find.text('發送溝通請求'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('發送溝通請求'));
      await tester.pumpAndSettle();
      verifyZeroInteractions(creditService);
      expect(find.text('溝通暫時無法完成，請稍後再試。'), findsOneWidget);
    },
  );

  testWidgets('closing the input screen releases reserved credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PetCommunicationInputScreen(
          pet: pet,
          creditReservationId: reservationId,
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    verify(() => creditService.releaseCommunication(reservationId)).called(1);
  });

  testWidgets('AI failure releases credit and exits the spent reservation', (
    tester,
  ) async {
    when(
      () => chatController.handleCommunicationWithPersistence(
        any(),
        any(),
        requestId: reservationId,
      ),
    ).thenAnswer((_) async => throw Exception('AI unavailable'));

    await tester.pumpWidget(
      MaterialApp(
        home: PetCommunicationInputScreen(
          pet: pet,
          creditReservationId: reservationId,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), '今天精神不錯');
    await tester.enterText(find.byType(TextField).at(1), '牠想告訴我什麼？');
    await tester.ensureVisible(find.text('發送溝通請求'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送溝通請求'));
    await tester.pumpAndSettle();

    verify(() => creditService.releaseCommunication(reservationId)).called(1);
    verify(
      () => chatController.handleCommunicationWithPersistence(
        'pet-1',
        any(),
        requestId: reservationId,
      ),
    ).called(1);
  });

  testWidgets(
    'fallback refunds points and Plus tier is not inferred from story length',
    (tester) async {
      when(
        () => chatController.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: reservationId,
        ),
      ).thenAnswer(
        (_) async => CommunicationOutcome(
          response: AiResponseModel.safeFallback(),
          isFallback: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PetCommunicationInputScreen(
            pet: pet,
            creditReservationId: reservationId,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), '今天精神不錯');
      await tester.enterText(find.byType(TextField).at(1), '牠想告訴我什麼？');
      await tester.ensureVisible(find.text('發送溝通請求'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('發送溝通請求'));
      await tester.pumpAndSettle();
      final request =
          verify(
                () => chatController.handleCommunicationWithPersistence(
                  'pet-1',
                  captureAny(),
                  requestId: reservationId,
                ),
              ).captured.single
              as AiRequestModel;
      expect(request.inputMode, 'plus');
      expect(request.ownerProfile.experienceLevel, isEmpty);
      verify(() => creditService.releaseCommunication(reservationId)).called(1);
      verifyNever(() => creditService.settleCommunication(any()));
    },
  );
}
