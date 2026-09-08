// test/features/chat/chat_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/data/chat_service.dart';
import 'package:ai_pet_communication/features/readings/application/reading_service.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/knowledge/application/knowledge_retrieval_service.dart';

class MockChatService extends Mock implements ChatService {}

class MockReadingService extends Mock implements ReadingService {}

class MockKnowledgeRetrievalService extends Mock
    implements KnowledgeRetrievalService {}

void main() {
  late MockChatService mockChatService;
  late MockReadingService mockReadingService;
  late MockKnowledgeRetrievalService mockKnowledgeRetrievalService;
  late ChatController chatController;

  setUp(() {
    mockChatService = MockChatService();
    mockReadingService = MockReadingService();
    mockKnowledgeRetrievalService = MockKnowledgeRetrievalService();
    chatController = ChatController(
      mockChatService,
      mockReadingService,
      mockKnowledgeRetrievalService,
    );
    when(
      () => mockKnowledgeRetrievalService.search(
        query: any(named: 'query'),
        species: any(named: 'species'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);

    // Register fallback values for mocktail
    registerFallbackValue('pet123');
  });

  group('ChatController - Behavioral Tests', () {
    const String petId = 'pet123';

    // Helper to build a request model
    AiRequestModel buildRequest({
      required String story,
      String inputMode = 'free',
    }) {
      return AiRequestModel(
        ownerProfile: const OwnerProfile(
          experienceLevel: '新手',
          careStyle: '親密',
          emotionStyle: '理智',
          dailyRoutine: '朝九晚五',
          mainConcern: '飲食健康',
        ),
        petProfile: const PetProfile(
          name: 'Buddy',
          species: '狗',
          breed: '黃金獵犬',
          age: 2.0,
          coatColor: '金色',
          personalityTraits: ['溫和', '活潑'],
        ),
        story: story,
        questions: const ['他今天開心嗎？'],
        inputMode: inputMode,
      );
    }

    test('標準模式 (無急症且資訊充足) 成功溝通並記錄至資料庫', () async {
      // 故事長度超過 300 字
      final longStory = 'A' * 310;
      final request = buildRequest(story: longStory);

      const normalResponseJson = '''
{
  "petVoice": [
    {
      "question": "他今天開心嗎？",
      "answer": "看到你搖尾巴，超開心！"
    }
  ],
  "knowledgeStation": {
    "title": "心情觀察",
    "content": "搖尾巴代表開心。"
  },
  "summary": "溝通順暢",
  "tags": ["開心"],
  "confidence": 0.95,
  "tone": "warm",
  "version": "p3-ai-1",
  "inputMode": "free"
}
''';

      when(
        () => mockChatService.sendMessage(any()),
      ).thenAnswer((_) async => normalResponseJson);
      when(
        () => mockReadingService.recordAiResponse(
          petId: any(named: 'petId'),
          aiText: any(named: 'aiText'),
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async => {});

      final result = await chatController.handleCommunication(petId, request);

      expect(result, isA<AiResponseModel>());
      expect((result as AiResponseModel).summary, '溝通順暢');
      expect(result.petVoice[0].answer, '看到你搖尾巴，超開心！');

      verify(() => mockChatService.sendMessage(any())).called(1);
      verify(
        () => mockReadingService.recordAiResponse(
          petId: petId,
          aiText: result.toJson(),
          source: 'pro_chat',
        ),
      ).called(1);
    });

    test('安全模式 (低資訊量) 成功溝通並記錄至資料庫', () async {
      // 故事長度低於 300 字
      final shortStory = 'A' * 10;
      final request = buildRequest(story: shortStory);

      const safeResponseJson = '''
{
  "version": "1.0",
  "mode": "safe_default",
  "disclaimer": "這是一份基於文字的保守推論。",
  "pet_voice": {
    "text": "主人，我今天感覺很平靜。",
    "tone": "gentle",
    "is_inference": true
  },
  "knowledge_tips": ["定時餵食重要"],
  "safety_alert": {
    "has_red_flags": false,
    "message": "一切正常"
  },
  "next_steps": ["繼續觀察"],
  "confidence": 0.9,
  "needs_more_info": false
}
''';

      when(
        () => mockChatService.sendMessage(any()),
      ).thenAnswer((_) async => safeResponseJson);
      when(
        () => mockReadingService.recordAiResponse(
          petId: any(named: 'petId'),
          aiText: any(named: 'aiText'),
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async => {});

      final result = await chatController.handleCommunication(petId, request);

      expect(result, isA<AiSafeResponseModel>());
      expect((result as AiSafeResponseModel).mode, 'safe_default');
      expect(result.petVoice.text, '主人，我今天感覺很平靜。');

      verify(() => mockChatService.sendMessage(any())).called(1);
      verify(
        () => mockReadingService.recordAiResponse(
          petId: petId,
          aiText: result.toJson(),
          source: 'safe_chat',
        ),
      ).called(1);
    });

    test('第一次呼叫失敗時，自動重試一次並成功完成', () async {
      final request = buildRequest(story: 'A' * 10);
      const safeResponseJson = '''
{
  "version": "1.0",
  "mode": "safe_default",
  "disclaimer": "D",
  "pet_voice": {"text": "平靜", "tone": "gentle", "is_inference": true},
  "knowledge_tips": ["K"],
  "safety_alert": {"has_red_flags": false, "message": "OK"},
  "next_steps": ["N"],
  "confidence": 0.9,
  "needs_more_info": false
}
''';

      int callCount = 0;
      when(() => mockChatService.sendMessage(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception("API Rate Limit");
        }
        return safeResponseJson;
      });

      when(
        () => mockReadingService.recordAiResponse(
          petId: any(named: 'petId'),
          aiText: any(named: 'aiText'),
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async => {});

      final result = await chatController.handleCommunication(petId, request);

      expect(result, isA<AiSafeResponseModel>());
      expect((result as AiSafeResponseModel).petVoice.text, '平靜');

      expect(callCount, 2); // 呼叫了兩次
      verify(
        () => mockReadingService.recordAiResponse(
          petId: petId,
          aiText: result.toJson(),
          source: 'safe_chat',
        ),
      ).called(1);
    });

    test('兩次重試均完全失敗時，返回 Fallback 預設降級回應且不記錄至資料庫', () async {
      final request = buildRequest(story: 'A' * 10);

      when(
        () => mockChatService.sendMessage(any()),
      ).thenThrow(Exception("Network Timeout"));

      final result = await chatController.handleCommunication(petId, request);

      expect(result, isA<AiResponseModel>());
      expect((result as AiResponseModel).summary, contains("Network Timeout"));
      expect(result.petVoice[0].answer, contains("對不起，我剛剛稍微分神了"));

      verify(() => mockChatService.sendMessage(any())).called(2); // 重試一次，共兩次
      verifyNever(
        () => mockReadingService.recordAiResponse(
          petId: any(named: 'petId'),
          aiText: any(named: 'aiText'),
          source: any(named: 'source'),
        ),
      );
    });
  });
}
