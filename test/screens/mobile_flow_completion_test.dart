import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/pet_communication_input_screen.dart';
import 'package:ai_pet_communication/features/home/presentation/home_screen.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_detail_screen.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_form_sheet.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import '../support/mobile_ui_fixture.dart';
import 'package:ai_pet_communication/services/membership_action_handler.dart';

class _Request extends Fake implements AiRequestModel {}

void main() {
  late MobileUiFixture fixture;
  setUpAll(() => registerFallbackValue(_Request()));
  setUp(() async {
    fixture = MobileUiFixture();
    await fixture.install();
  });
  tearDown(() => fixture.dispose());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      fixture.app(PetCommunicationInputScreen(pet: MobileUiFixture.pet)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('communication-story')),
      '今天一起散步',
    );
    await tester.enterText(find.byKey(const Key('question-0')), '第一題');
  }

  for (final count in [1, 5]) {
    testWidgets('$count nonempty questions complete and display the response', (
      tester,
    ) async {
      when(
        () => fixture.chat.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer(
        (_) async => CommunicationOutcome(response: MobileUiFixture.response),
      );
      await open(tester);
      for (var i = 1; i < count; i++) {
        await tap(tester, find.byKey(const Key('add-question')));
        await tester.enterText(find.byKey(Key('question-$i')), '問題 $i');
      }
      await tap(tester, find.byKey(const Key('submit-communication')));
      final sent =
          verify(
                () => fixture.chat.handleCommunicationWithPersistence(
                  any(),
                  captureAny(),
                  requestId: any(named: 'requestId'),
                ),
              ).captured.single
              as AiRequestModel;
      expect(sent.questions.length, count);
      expect(find.text('溝通結果'), findsOneWidget);
      expect(find.text(MobileUiFixture.response.summary), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('persistence retry does not generate another response', (
    tester,
  ) async {
    final outcome = CommunicationOutcome(
      response: MobileUiFixture.response,
      persistenceFailure: ReadingPersistenceException(
        Reading(
          id: 'demo',
          petId: 'demo-pet',
          title: '',
          content: '',
          createdAt: DateTime(2026),
        ),
        StateError('offline'),
        StackTrace.current,
      ),
    );
    when(
      () => fixture.chat.handleCommunicationWithPersistence(
        any(),
        any(),
        requestId: any(named: 'requestId'),
      ),
    ).thenAnswer((_) async => outcome);
    when(() => fixture.chat.retryPersistence(outcome)).thenAnswer((_) async {});
    await open(tester);
    await tester.tap(find.byKey(const Key('submit-communication')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('紀錄尚未儲存'), findsOneWidget);
    await tester.tap(find.text('重試儲存'));
    await tester.pumpAndSettle();
    verify(() => fixture.chat.retryPersistence(outcome)).called(1);
    verify(
      () => fixture.chat.handleCommunicationWithPersistence(
        any(),
        any(),
        requestId: any(named: 'requestId'),
      ),
    ).called(1);
    expect(find.text('溝通結果'), findsOneWidget);
  });

  for (final tier in ['free', 'plus', 'pro']) {
    testWidgets(
      '$tier photo access, cancellation and picker failure preserve input',
      (tester) async {
        await fixture.install(tier: tier);
        await open(tester);
        final finder = find.byKey(const Key('add-photos'));
        expect(
          tester.widget<OutlinedButton>(finder).onPressed != null,
          tier != 'free',
        );
        if (tier != 'free') {
          await tap(tester, finder);
          expect(find.text('加入照片（0/3）'), findsOneWidget);
          fixture.photos.pickError = const FormatException('無法讀取照片，請重新選擇');
          await tap(tester, finder);
          expect(find.text('無法讀取照片，請重新選擇'), findsOneWidget);
        }
        expect(find.text('今天一起散步'), findsOneWidget);
        expect(find.text('第一題'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'home add entry opens pet form and pet detail starts communication',
    (tester) async {
      await fixture.install(items: []);
      await tester.pumpWidget(fixture.app(HomeScreen(user: fixture.user)));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('empty-add-pet')));
      expect(find.byType(PetFormSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        fixture.app(
          PetDetailScreen(
            pet: MobileUiFixture.pet,
            membershipHandler: MembershipActionHandler(
              fixture.auth,
              fixture.ads,
              UiCredit(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('start-pet-communication')));
      expect(find.byType(PetCommunicationInputScreen), findsOneWidget);
    },
  );

  testWidgets('profile and point balance expose screen reader tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(fixture.app(HomeScreen(user: fixture.user)));
      await tester.pumpAndSettle();
      for (final label in ['開啟個人頁，小米的家人', '點數餘額 120 點，查看點數與會員方案']) {
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }
    } finally {
      semantics.dispose();
    }
  });
}
