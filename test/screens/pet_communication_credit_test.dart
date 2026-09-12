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
import 'dart:convert';
import 'package:ai_pet_communication/features/chat/domain/communication_photo.dart';
import 'package:ai_pet_communication/features/chat/domain/communication_photo_repository.dart';

class MockCreditService extends Mock implements CreditService {}

class MockChatController extends Mock implements ChatController {}

class MockAuthService extends Mock implements AuthService {}

class FakePhotos implements CommunicationPhotoRepository {
  List<CommunicationPhoto> selection = [];
  List<String> removed = [];
  @override
  Future<List<CommunicationPhoto>> pick({int maxPhotos = 3}) async => selection;
  @override
  Future<List<String>> upload(
    List<CommunicationPhoto> photos,
    String uid,
    String requestId,
  ) async => List.generate(
    photos.length,
    (i) => 'communicationPhotos/$uid/$requestId/$i',
  );
  @override
  Future<void> remove(List<String> paths) async => removed.addAll(paths);
}

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
    getIt.registerSingleton<CommunicationPhotoRepository>(FakePhotos());
    final authService = MockAuthService();
    getIt.registerSingleton<AuthService>(authService);
    when(() => authService.getUserData()).thenAnswer(
      (_) async => UserModel(
        uid: 'user-1',
        email: 'test@example.com',
        displayName: 'test',
        subscriptionVerified: true,
        membershipEntitlements: {'plus': DateTime(2100)},
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
    'Plus selects three photos, removes one and sends image references with cleanup',
    (tester) async {
      final photos = FakePhotos();
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
      );
      photos.selection = List.generate(
        3,
        (_) => CommunicationPhoto.fromBytes(png),
      );
      AiRequestModel? sent;
      when(
        () => chatController.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((invocation) async {
        sent = invocation.positionalArguments[1] as AiRequestModel;
        return CommunicationOutcome(
          response: AiResponseModel.safeFallback(),
          isFallback: true,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PetCommunicationInputScreen(pet: pet, photoService: photos),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.tap(find.text('加入照片（0/3）'));
      await tester.pumpAndSettle();
      expect(find.text('加入照片（3/3）'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('移除照片 2'));
      await tester.tap(find.text('移除照片 2'));
      await tester.pumpAndSettle();
      expect(find.text('加入照片（2/3）'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '今天精神很好');
      await tester.enterText(find.byType(TextField).at(1), '牠開心嗎？');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('發送溝通請求'));
      await tester.pumpAndSettle();
      expect(sent?.media?.photos, hasLength(2));
      expect(photos.removed, sent!.media!.photos);
    },
  );

  testWidgets('Free cannot select photos', (tester) async {
    when(() => getIt<AuthService>().getUserData()).thenAnswer(
      (_) async => UserModel(uid: 'user-1', email: '', displayName: ''),
    );
    await tester.pumpWidget(
      MaterialApp(home: PetCommunicationInputScreen(pet: pet)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'selecting more than three photos is rejected without silently dropping images',
    (tester) async {
      final photos = FakePhotos()
        ..selection = List.generate(
          4,
          (_) => CommunicationPhoto(base64Decode('eA=='), 'image/png'),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: PetCommunicationInputScreen(pet: pet, photoService: photos),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(OutlinedButton));
      await tester.tap(find.text('加入照片（0/3）'));
      await tester.pumpAndSettle();
      expect(find.text('最多上傳 3 張照片，請重新選擇'), findsOneWidget);
      expect(find.text('加入照片（0/3）'), findsOneWidget);
    },
  );

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
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton));
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
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ElevatedButton));
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
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton));
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
