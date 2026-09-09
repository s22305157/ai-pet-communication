import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_display.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/features/planet/presentation/pet_planet_screen.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final response in [
    '{"petVoice":[],"knowledgeStation":{"title":"互動","content":"保持距離"},"summary":"等待靠近"}',
    '{"pet_voice":{"text":"我想休息"},"safety_alert":{"has_red_flags":true,"message":"立即聯絡獸醫"}}',
  ]) {
    testWidgets(
      'result links to catalog and returns without losing reply: $response',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunicationResultContent(
                  result: parseCommunication(response),
                ),
              ),
            ),
          ),
        );
        final entry = find.text('查看寵物星球圖鑑');
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.text('寵物星球圖鑑'), findsOneWidget);
        await tester.ensureVisible(find.text('001・等我靠近'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('001・等我靠近'));
        await tester.pumpAndSettle();
        final zoom = find.text('放大查看卡片');
        await tester.ensureVisible(zoom);
        await tester.pumpAndSettle();
        await tester.tap(zoom);
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        expect(entry, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'catalog fits narrow screens with large text and bundles the image',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const PetPlanetScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await DefaultAssetBundle.of(
          tester.element(find.byType(PetPlanetScreen)),
        ).load('assets/cards/001-approach-v2.png');
        expect(image.lengthInBytes, greaterThan(1000));
      });
      expect(find.text('卡片圖片暫時無法載入'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
