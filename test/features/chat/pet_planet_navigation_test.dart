import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_display.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/features/planet/presentation/pet_planet_screen.dart';
import 'package:ai_pet_communication/features/planet/domain/planet_card.dart';

Future<void> prepareCardImage(WidgetTester tester, String id) async {
  // Decode before the widget's fake clock starts an image request. Joining an
  // already pending request inside runAsync can otherwise wait on that clock.
  await tester.runAsync(() async {
    final card = planetCards.singleWhere((card) => card.id == id);
    final provider = AssetImage(card.imageAsset);
    // A previous catalog can leave an unfinished decode in its fake zone.
    await provider.evict();
    final stream = provider.resolve(ImageConfiguration.empty);
    final ready = Completer<void>();
    final listener = ImageStreamListener(
      (_, _) => ready.complete(),
      onError: (Object error, StackTrace? stack) =>
          ready.completeError(error, stack),
    );
    stream.addListener(listener);
    addTearDown(() => stream.removeListener(listener));
    await ready.future.timeout(const Duration(seconds: 20));
  });
}

Future<void> expectDecodedZoomImage(WidgetTester tester) async {
  final zoom = find.byType(InteractiveViewer);
  expect(zoom, findsOneWidget);
  await tester.pumpAndSettle();
  final decoded = tester
      .widget<RawImage>(
        find.descendant(of: zoom, matching: find.byType(RawImage)),
      )
      .image;
  expect(
    decoded,
    isNotNull,
    reason: 'The zoom view must render decoded pixels.',
  );
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('all 140 sequential card IDs have bundled images', () async {
    expect(
      planetCards.map((card) => card.id).toList(),
      List.generate(140, (index) => '${index + 1}'.padLeft(3, '0')),
    );
    expect(planetCards.map((card) => card.imageAsset).toSet().length, 140);
    for (final card in planetCards) {
      final bytes = await rootBundle.load(card.imageAsset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: card.id);
      expect(bytes.buffer.asUint8List(bytes.offsetInBytes, 8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ], reason: card.id);
    }
  });

  testWidgets('dog catalog card opens its details and zoom view', (
    tester,
  ) async {
    await prepareCardImage(tester, '021');
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'021'})),
    );
    await tester.scrollUntilVisible(
      find.text('021・聞聞再前進'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('021・聞聞再前進'));
    await tester.pumpAndSettle();
    final zoom = find.text('放大查看卡片');
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    await expectDecodedZoomImage(tester);
    expect(find.text('聞聞再前進'), findsOneWidget);
    expect(find.text('卡片圖片暫時無法載入'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card 060 opens details and zoom after scrolling', (
    tester,
  ) async {
    await prepareCardImage(tester, '060');
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'060'})),
    );
    await tester.scrollUntilVisible(
      find.text('060・花草先查清楚'),
      800,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('060・花草先查清楚'));
    await tester.pumpAndSettle();
    final zoom = find.text('放大查看卡片');
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    await expectDecodedZoomImage(tester);
    expect(find.text('花草先查清楚'), findsOneWidget);
    expect(find.text('卡片圖片暫時無法載入'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card 080 opens details and zoom after scrolling', (
    tester,
  ) async {
    await prepareCardImage(tester, '080');
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'080'})),
    );
    await tester.scrollUntilVisible(
      find.text('080・有個地方可以挖'),
      800,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('080・有個地方可以挖'));
    await tester.pumpAndSettle();
    final zoom = find.text('放大查看卡片');
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    await expectDecodedZoomImage(tester);
    expect(find.text('有個地方可以挖'), findsOneWidget);
    expect(find.text('卡片圖片暫時無法載入'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card 120 opens details and zoom after scrolling', (
    tester,
  ) async {
    await prepareCardImage(tester, '120');
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'120'})),
    );
    await tester.scrollUntilVisible(
      find.text('120・玩具回小籃子'),
      800,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 120,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('120・玩具回小籃子'));
    await tester.pumpAndSettle();
    final zoom = find.text('放大查看卡片');
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    await expectDecodedZoomImage(tester);
    expect(find.text('玩具回小籃子'), findsOneWidget);
    expect(find.text('卡片圖片暫時無法載入'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card 140 opens details and zoom at end of catalog', (
    tester,
  ) async {
    await prepareCardImage(tester, '140');
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'140'})),
    );
    await tester.scrollUntilVisible(
      find.text('140・紙箱先檢查'),
      800,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 140,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('140・紙箱先檢查'));
    await tester.pumpAndSettle();
    final zoom = find.text('放大查看卡片');
    await tester.ensureVisible(zoom);
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    await expectDecodedZoomImage(tester);
    expect(find.text('紙箱先檢查'), findsOneWidget);
    expect(find.text('卡片圖片暫時無法載入'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final response in [
    '{"petVoice":[],"knowledgeStation":{"title":"互動","content":"保持距離"},"summary":"等待靠近"}',
    '{"pet_voice":{"text":"我想休息"},"safety_alert":{"has_red_flags":true,"message":"立即聯絡獸醫"}}',
  ]) {
    testWidgets(
      'result links to catalog and returns without losing reply: $response',
      (tester) async {
        await prepareCardImage(tester, '001');
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
        await expectDecodedZoomImage(tester);
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
      await prepareCardImage(tester, '001');
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
        ).load('assets/cards/001-approach-v4.png');
        expect(image.lengthInBytes, greaterThan(1000));
      });
      expect(find.text('卡片圖片暫時無法載入'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
