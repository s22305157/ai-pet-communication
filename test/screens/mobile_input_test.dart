import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/pet_communication_input_screen.dart';
import '../support/mobile_ui_fixture.dart';

class _Request extends Fake implements AiRequestModel {}

void main() {
  late MobileUiFixture fixture;
  setUpAll(() => registerFallbackValue(_Request()));
  setUp(() async {
    fixture = MobileUiFixture();
    await fixture.install();
  });
  tearDown(() => fixture.dispose());
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      fixture.app(
        PetCommunicationInputScreen(pet: MobileUiFixture.pet),
        scale: scale,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'questions add to five, confirm deletion and retain other text in order',
    (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const Key('communication-story')),
        '一起散步',
      );
      await tester.enterText(find.byKey(const Key('question-0')), '第一題');
      for (var i = 1; i < 5; i++) {
        await tap(tester, find.byKey(const Key('add-question')));
        await tester.enterText(find.byKey(Key('question-$i')), '第 $i 題');
      }
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('add-question')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.byKey(const Key('remove-question-2')));
      await tester.tap(find.text('保留問題'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 題'), findsOneWidget);
      await tap(tester, find.byKey(const Key('remove-question-2')));
      await tester.tap(find.text('刪除問題'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 題'), findsNothing);
      expect(find.text('第 3 題'), findsOneWidget);
      expect(find.text('一起散步'), findsOneWidget);
      when(
        () => fixture.chat.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: any(named: 'requestId'),
        ),
      ).thenThrow(StateError('offline'));
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
      expect(sent.questions, ['第一題', '第 1 題', '第 3 題', '第 4 題']);
      expect(find.text('一起散步'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing fields show inline errors and focus, busy request sends once',
    (tester) async {
      await open(tester);
      await tap(tester, find.byKey(const Key('submit-communication')));
      expect(find.text('請先分享一些關於毛孩的故事。'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('communication-story')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const Key('communication-story')),
        '今天精神很好',
      );
      await tap(tester, find.byKey(const Key('submit-communication')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('question-0')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const Key('question-0')), '開心嗎？');
      final pending = Completer<CommunicationOutcome>();
      when(
        () => fixture.chat.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((_) => pending.future);
      await tester.tap(find.byKey(const Key('submit-communication')));
      await tester.pump();
      expect(find.text('正在整理回覆…'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('submit-communication')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('add-question')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('add-photos')))
            .onPressed,
        isNull,
      );
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      verify(
        () => fixture.chat.handleCommunicationWithPersistence(
          any(),
          any(),
          requestId: any(named: 'requestId'),
        ),
      ).called(1);
      expect(find.text('開心嗎？'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'input ${size.width}x${size.height} text $scale keyboard stays above inset',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await open(tester, scale: scale);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = FakeViewPadding(
            bottom: size.height < 500 ? 120 : 280,
          );
          addTearDown(tester.view.resetViewInsets);
          await tester.enterText(
            find.byKey(const Key('communication-story')),
            '合成測試故事',
          );
          await tester.pumpAndSettle();
          final button = tester.getRect(
            find.byKey(const Key('submit-communication')),
          );
          expect(
            button.bottom,
            lessThanOrEqualTo(size.height - tester.view.viewInsets.bottom),
          );
          expect(button.height, greaterThanOrEqualTo(52));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
