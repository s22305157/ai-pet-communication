import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/home/presentation/home_screen.dart';
import 'package:ai_pet_communication/features/pet/presentation/pet_detail_screen.dart';
import 'package:ai_pet_communication/features/onboarding/presentation/onboarding_screen.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_display.dart';
import 'package:ai_pet_communication/features/readings/presentation/reading_detail_screen.dart';
import 'package:ai_pet_communication/features/readings/domain/reading.dart';
import 'package:ai_pet_communication/models/onboarding_model.dart';
import '../support/mobile_ui_fixture.dart';

void main() {
  late MobileUiFixture fixture;
  setUp(() async {
    fixture = MobileUiFixture();
    await fixture.install(name: '名字很長的毛孩家人一起來散步', points: 123456789);
  });
  tearDown(() => fixture.dispose());
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1280, 900),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'mobile pages ${size.width}x${size.height} text $scale remain reachable',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            fixture.app(HomeScreen(user: fixture.user), scale: scale),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const Key('sync-status'))).shortestSide,
            greaterThanOrEqualTo(48),
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('open-journal')),
            200,
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('open-journal'))).bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const Key('add-pet'))).top,
            ),
          );
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            fixture.app(
              PetDetailScreen(
                pet: MobileUiFixture.pet.copyWith(name: '喜歡散步的小米與家人'),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(find.byKey(const Key('start-pet-communication')))
                .bottom,
            lessThanOrEqualTo(size.height),
          );
          expect(tester.takeException(), isNull);

          for (final result in [
            MobileUiFixture.response,
            MobileUiFixture.safeResponse,
          ]) {
            await tester.pumpWidget(
              fixture.app(
                CommunicationResultScreen(
                  result: result,
                  pet: MobileUiFixture.pet,
                ),
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tap(tester, find.byKey(const Key('result-knowledge')));
            await tap(tester, find.byKey(const Key('copy-response')));
            expect(tester.takeException(), isNull);
          }

          await tester.pumpWidget(
            fixture.app(const OnboardingScreen(), scale: scale),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ElevatedButton>(
                  find.byKey(const Key('onboarding-next')),
                )
                .onPressed,
            isNull,
          );
          await tap(tester, find.byKey(const Key('onboarding-consent')));
          await tap(tester, find.byKey(const Key('onboarding-next')));
          for (var index = 0; index < onboardingQuestions.length; index++) {
            final question = onboardingQuestions[index];
            expect(find.text('第 ${index + 1}／5 題'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (question.isRequired) {
              await tap(tester, find.text(question.options.first.label));
            } else {
              expect(find.text('選填，可以直接前往下一步'), findsOneWidget);
            }
            await tap(tester, find.byKey(const Key('onboarding-next')));
          }
          expect(find.text('開始使用'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'empty home provides an add action and many pets can reach journal',
    (tester) async {
      await fixture.install(items: []);
      await tester.pumpWidget(fixture.app(HomeScreen(user: fixture.user)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('empty-add-pet')), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('empty-add-pet')))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      await fixture.install(
        items: List.generate(
          20,
          (i) => MobileUiFixture.pet.copyWith(petId: 'pet-$i', name: '毛孩 $i'),
        ),
      );
      await tester.pumpWidget(fixture.app(HomeScreen(user: fixture.user)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-journal')),
        400,
        maxScrolls: 30,
      );
      expect(find.text('毛孩 19'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary and safety lead, copying includes collapsed knowledge in display order',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      for (final result in [
        MobileUiFixture.response,
        MobileUiFixture.safeResponse,
      ]) {
        await tester.pumpWidget(
          fixture.app(
            CommunicationResultScreen(result: result, pet: MobileUiFixture.pet),
          ),
        );
        await tester.pumpAndSettle();
        if (result == MobileUiFixture.response) {
          expect(
            tester.getTopLeft(find.byKey(const Key('result-summary'))).dy,
            lessThan(tester.getTopLeft(find.text('毛孩想對你說')).dy),
          );
          expect(
            find.text(MobileUiFixture.response.knowledgeStation.content),
            findsNothing,
          );
        } else {
          expect(
            tester.getTopLeft(find.byKey(const Key('result-safety'))).dy,
            lessThan(
              tester.getTopLeft(find.byKey(const Key('result-next-steps'))).dy,
            ),
          );
          expect(
            tester.getTopLeft(find.byKey(const Key('result-next-steps'))).dy,
            lessThan(
              tester.getTopLeft(find.byKey(const Key('result-voice'))).dy,
            ),
          );
        }
        await tap(tester, find.byKey(const Key('copy-response')));
        expect(copied, communicationCopyText(result));
        expect(
          copied,
          contains(
            result == MobileUiFixture.response
                ? MobileUiFixture.response.knowledgeStation.content
                : MobileUiFixture.safeResponse.knowledgeTips.first,
          ),
        );
      }
    },
  );

  testWidgets(
    'onboarding previous preserves selection and optional answer can stay absent',
    (tester) async {
      when(
        () => fixture.auth.updateOnboardingStatus(true, any()),
      ).thenAnswer((_) async {});
      when(
        () => fixture.onboarding.saveAnswers(any()),
      ).thenAnswer((_) async {});
      when(
        () => fixture.onboarding.markCompleted(true),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(fixture.app(const OnboardingScreen()));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('onboarding-consent')));
      await tap(tester, find.byKey(const Key('onboarding-next')));
      await tap(
        tester,
        find.text(onboardingQuestions.first.options.first.label),
      );
      await tap(tester, find.byKey(const Key('onboarding-next')));
      await tap(tester, find.text('上一步'));
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('onboarding-next')))
            .onPressed,
        isNotNull,
      );
      await tap(tester, find.byKey(const Key('onboarding-next')));
      for (final question in onboardingQuestions.skip(1)) {
        if (question.isRequired) {
          await tap(tester, find.text(question.options.first.label));
        }
        await tap(tester, find.byKey(const Key('onboarding-next')));
      }
      await tester.tap(find.text('開始使用'));
      await tester.pump(const Duration(milliseconds: 300));
      final answers =
          verify(
                () => fixture.auth.updateOnboardingStatus(true, captureAny()),
              ).captured.single
              as Map;
      expect(answers.keys, [
        'pet_type',
        'main_goal',
        'concern_area',
        'help_style',
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('historical structured and plain replies stay readable', (
    tester,
  ) async {
    for (final content in [
      MobileUiFixture.response.toJson(),
      MobileUiFixture.safeResponse.toJson(),
      '舊的文字紀錄',
    ]) {
      await tester.pumpWidget(
        fixture.app(
          ReadingDetailScreen(
            key: ValueKey(content),
            petId: 'demo-pet',
            readingId: 'demo-reading',
            readingsRepository: fixture.readings,
            reading: Reading(
              id: 'demo-reading',
              petId: 'demo-pet',
              title: '合成紀錄',
              content: content,
              createdAt: DateTime(2026, 9, 13),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成紀錄'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('shared foreground and background colors meet readable contrast', () {
    for (final background in [
      AppColors.surface,
      AppColors.surfaceSoft,
      AppColors.surfaceMint,
    ]) {
      for (final foreground in [
        AppColors.textPrimary,
        AppColors.textSecondary,
      ]) {
        expect(
          (background.computeLuminance() + .05) /
              (foreground.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
    expect(
      (Colors.white.computeLuminance() + .05) /
          (AppColors.accent.computeLuminance() + .05),
      greaterThanOrEqualTo(4.5),
    );
  });
}
