import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/features/planet/presentation/pet_planet_screen.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('award receipt survives standard and safe reading serialization', () {
    final award = {
      'matchedCardIds': ['020', '100'],
      'newCardIds': ['020', '100'],
    };
    final standard = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': award,
    });
    expect(AiResponseModel.fromMap(standard.toMap()).newCardIds, [
      '020',
      '100',
    ]);
    final safe = AiSafeResponseModel.fromMap({'planetAward': award});
    expect(AiSafeResponseModel.fromMap(safe.toMap()).matchedCardIds, [
      '020',
      '100',
    ]);
    expect(AiSafeResponseModel.fromMap({}).newCardIds, isEmpty);
  });
  testWidgets('receipt shows card title and new collection status', (
    tester,
  ) async {
    final result = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': {
        'matchedCardIds': ['020', '100'],
        'newCardIds': ['020', '100'],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunicationResultContent(result: result),
          ),
        ),
      ),
    );
    expect(find.textContaining('看看我的小肚肚（本次新收藏）'), findsOneWidget);
    expect(find.textContaining('啟動前先找找我（本次新收藏）'), findsOneWidget);
  });
  testWidgets('catalog distinguishes collection from preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'001'})),
    );
    expect(find.textContaining('已收藏 1／140'), findsOneWidget);
    expect(find.text('已收藏'), findsOneWidget);
    expect(find.text('尚未收藏・預覽'), findsWidgets);
  });

  testWidgets('new cat receipt displays card 121 and 140 titles', (
    tester,
  ) async {
    final result = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': {
        'matchedCardIds': ['121', '140'],
        'newCardIds': ['121', '140'],
      },
    });
    expect(AiResponseModel.fromMap(result.toMap()).newCardIds, ['121', '140']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunicationResultContent(result: result),
          ),
        ),
      ),
    );
    expect(find.textContaining('鼻子輕碰一下（本次新收藏）'), findsOneWidget);
    expect(find.textContaining('紙箱先檢查（本次新收藏）'), findsOneWidget);
  });

  testWidgets('dog receipt displays the new dog card title', (tester) async {
    final result = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': {
        'matchedCardIds': ['021', '040', '080'],
        'newCardIds': ['021', '040', '080'],
      },
    });
    expect(AiResponseModel.fromMap(result.toMap()).newCardIds, [
      '021',
      '040',
      '080',
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunicationResultContent(result: result),
          ),
        ),
      ),
    );
    expect(find.textContaining('聞聞再前進（本次新收藏）'), findsOneWidget);
    expect(find.textContaining('一步一步慢慢上（本次新收藏）'), findsOneWidget);
    expect(find.textContaining('有個地方可以挖（本次新收藏）'), findsOneWidget);
  });
}
