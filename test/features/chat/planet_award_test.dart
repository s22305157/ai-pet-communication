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
      'matchedCardIds': ['020'],
      'newCardIds': ['020'],
    };
    final standard = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': award,
    });
    expect(AiResponseModel.fromMap(standard.toMap()).newCardIds, ['020']);
    final safe = AiSafeResponseModel.fromMap({'planetAward': award});
    expect(AiSafeResponseModel.fromMap(safe.toMap()).matchedCardIds, ['020']);
    expect(AiSafeResponseModel.fromMap({}).newCardIds, isEmpty);
  });
  testWidgets('receipt shows card title and new collection status', (
    tester,
  ) async {
    final result = AiResponseModel.fromMap({
      ...AiResponseModel.safeFallback().toMap(),
      'planetAward': {
        'matchedCardIds': ['020'],
        'newCardIds': ['020'],
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
  });
  testWidgets('catalog distinguishes collection from preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlanetCatalog(collectedIds: {'001'})),
    );
    expect(find.textContaining('已收藏 1／20'), findsOneWidget);
    expect(find.text('已收藏'), findsOneWidget);
    expect(find.text('尚未收藏・預覽'), findsWidgets);
  });
}
