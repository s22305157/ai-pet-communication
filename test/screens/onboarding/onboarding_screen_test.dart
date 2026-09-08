import 'dart:async';

import 'package:ai_pet_communication/injection.dart';
import 'package:ai_pet_communication/models/onboarding_model.dart';
import 'package:ai_pet_communication/screens/onboarding/onboarding_screen.dart';
import 'package:ai_pet_communication/services/auth_service.dart';
import 'package:ai_pet_communication/services/onboarding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockOnboardingService extends Mock implements OnboardingService {}

Future<void> reachConclusion(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('立即開始'));

  for (final question in onboardingQuestions) {
    await tester.pumpAndSettle();
    await tester.tap(find.text(question.options.first.label));
    await tester.pump();
    await tester.tap(find.text('下一步'));
  }
  await tester.pumpAndSettle();
  expect(find.text('開始使用'), findsOneWidget);
}

void useLargeTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late MockAuthService authService;
  late MockOnboardingService onboardingService;

  setUp(() async {
    await getIt.reset();
    authService = MockAuthService();
    onboardingService = MockOnboardingService();
    getIt.registerSingleton<AuthService>(authService);
    getIt.registerSingleton<OnboardingService>(onboardingService);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('restores submit button after onboarding save fails', (
    tester,
  ) async {
    useLargeTestViewport(tester);
    when(
      () => authService.updateOnboardingStatus(true, any()),
    ).thenAnswer((_) async => throw Exception('save failed'));

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await reachConclusion(tester);

    await tester.tap(find.text('開始使用'));
    await tester.pumpAndSettle();

    expect(find.textContaining('儲存失敗'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
    verify(() => authService.updateOnboardingStatus(true, any())).called(1);
  });

  testWidgets('ignores duplicate taps while onboarding is submitting', (
    tester,
  ) async {
    useLargeTestViewport(tester);
    final saveCompleter = Completer<void>();
    when(
      () => authService.updateOnboardingStatus(true, any()),
    ).thenAnswer((_) => saveCompleter.future);
    when(() => onboardingService.saveAnswers(any())).thenAnswer((_) async {});
    when(() => onboardingService.markCompleted(true)).thenAnswer((_) async {});

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await reachConclusion(tester);

    await tester.tap(find.text('開始使用'));
    await tester.tap(find.text('開始使用'));
    await tester.pump();

    verify(() => authService.updateOnboardingStatus(true, any())).called(1);

    saveCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    verify(() => onboardingService.saveAnswers(any())).called(1);
    verify(() => onboardingService.markCompleted(true)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
