import 'dart:convert';

import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/application/safety_router.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockReadingService extends Mock implements ReadingService {}

class RecordingChatService extends ChatService {
  final String response;
  String? lastRequest;

  RecordingChatService(this.response);

  @override
  Future<String> sendMessage(String message) async {
    lastRequest = message;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReadingService readingService;

  setUp(() {
    readingService = MockReadingService();
    when(
      () => readingService.recordAiResponse(
        petId: any(named: 'petId'),
        aiText: any(named: 'aiText'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async => {});
  });

  AiRequestModel buildRequest({
    required String species,
    required String story,
    required String question,
  }) {
    return AiRequestModel(
      ownerProfile: const OwnerProfile(
        experienceLevel: 'intermediate',
        careStyle: 'gentle',
        emotionStyle: 'calm',
        dailyRoutine: 'stable',
        mainConcern: 'behavior and health',
      ),
      petProfile: PetProfile(
        name: '毛孩',
        species: species,
        breed: '',
        age: 5,
        coatColor: '',
        personalityTraits: const ['親人'],
      ),
      story: story,
      questions: [question],
      inputMode: story.length >= SafetyRouter.deepAnalysisThreshold
          ? 'pro'
          : 'free',
    );
  }

  test('排尿急症傳原始資料至後端且驗證安全回覆', () async {
    const response = '''
{
  "version": "rag-safe-1",
  "mode": "safe_default",
  "disclaimer": "這是安全分流資訊，不能代替獸醫診斷。",
  "pet_voice": {"text": "無法從文字確定感受。", "tone": "calm", "is_inference": true},
  "knowledge_tips": ["反覆用力卻無尿可能是急症。"],
  "safety_alert": {"has_red_flags": true, "message": "請立即聯絡獸醫急診。", "red_flags": ["可能尿道阻塞"]},
  "next_steps": ["立即聯絡獸醫急診", "準備排尿時間與頻率紀錄"],
  "confidence": 0.95,
  "needs_more_info": false,
  "tags": ["排尿", "急症"]
}
''';
    final chatService = RecordingChatService(response);
    final controller = ChatController(chatService, readingService);
    final request = buildRequest(
      species: '貓',
      story: '今天反覆進貓砂盆，一直用力尿但尿不出。',
      question: '牠是不是在鬧脾氣？',
    );

    final result = await controller.handleCommunication('cat-1', request);

    expect(result, isA<AiSafeResponseModel>());
    expect((result as AiSafeResponseModel).safetyAlert.hasRedFlags, isTrue);
    final envelope =
        jsonDecode(chatService.lastRequest!) as Map<String, dynamic>;
    expect(envelope['petId'], 'cat-1');
    expect(envelope['request'], request.toMap());
    expect(envelope.keys.toSet(), {'petId', 'requestId', 'request'});
    verify(
      () => readingService.recordAiResponse(
        petId: 'cat-1',
        aiText: result.toJson(),
        source: 'safe_chat',
      ),
    ).called(1);
  });

  test('犬隻獨處問題傳原始資料並保留一般問答格式', () async {
    const response = '''
{
  "petVoice": [{"question": "獨處時一直叫怎麼辦？", "answer": "先記錄離家後何時開始與持續多久，再安排漸進練習。"}],
  "knowledgeStation": {"title": "獨處觀察", "content": "錄影可協助區分觸發時點，明顯困擾需尋求專業協助。"},
  "summary": "先記錄再漸進練習",
  "tags": ["獨處", "吠叫"],
  "confidence": 0.8,
  "tone": "calm",
  "version": "rag-1",
  "inputMode": "pro"
}
''';
    final chatService = RecordingChatService(response);
    final controller = ChatController(chatService, readingService);
    final request = buildRequest(
      species: '狗',
      story:
          '狗狗平常和家人相處穩定，但最近獨自在家時會持續叫。'
          '我們已錄影三天，通常在離家五分鐘後開始，回家前才停止；進食和散步都正常。'
          '${'每天也記錄離家時間、叫聲開始時間、持續長度、是否進食、是否休息，以及家人回家後的恢復狀況。' * 8}',
      question: '獨處時一直叫怎麼辦？',
    );

    final result = await controller.handleCommunication('dog-1', request);

    expect(result, isA<AiResponseModel>());
    expect((result as AiResponseModel).knowledgeStation.title, '獨處觀察');
    final envelope =
        jsonDecode(chatService.lastRequest!) as Map<String, dynamic>;
    expect(envelope['request'], request.toMap());
    expect(envelope.containsKey('model'), isFalse);
    verify(
      () => readingService.recordAiResponse(
        petId: 'dog-1',
        aiText: result.toJson(),
        source: 'pro_chat',
      ),
    ).called(1);
  });
}
