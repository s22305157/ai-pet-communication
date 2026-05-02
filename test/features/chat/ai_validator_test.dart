// test/features/chat/ai_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communicator/features/chat/application/ai_validator.dart';
import 'package:ai_pet_communicator/features/chat/domain/ai_response_model.dart';

void main() {
  group('AiValidator - Response Validation', () {
    test('應該能正確解析標準 JSON 回應', () {
      const raw = '''
{
  "petVoice": [
    {
      "question": "你好嗎？",
      "answer": "我很好，謝謝主人！"
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
      final response = AiValidator.validateResponse(raw);
      expect(response.petVoice.length, 1);
      expect(response.petVoice[0].answer, "我很好，謝謝主人！");
      expect(response.confidence, 0.95);
    });

    test('應該能從 Markdown 代碼塊中擷取 JSON', () {
      const raw = '''
這是我感受到的結果：
```json
{
  "petVoice": [{"question": "Q", "answer": "A"}],
  "knowledgeStation": {"title": "T", "content": "C"},
  "summary": "S",
  "tags": ["T1"],
  "confidence": 0.8,
  "tone": "gentle",
  "version": "v1",
  "inputMode": "pro"
}
```
希望這對你有幫助。
''';
      final response = AiValidator.validateResponse(raw);
      expect(response.petVoice[0].answer, "A");
      expect(response.inputMode, "pro");
    });

    test('應該能修復頭尾帶有雜質的 JSON', () {
      const raw = '一些廢話... {"petVoice": [{"question": "Q", "answer": "A"}], "knowledgeStation": {"title": "T", "content": "C"}, "summary": "S", "tags": [], "confidence": 0.5, "tone": "calm", "version": "v1", "inputMode": "free"} ...又是廢話';
      final response = AiValidator.validateResponse(raw);
      expect(response.summary, "S");
    });

    test('當缺少必要欄位時應拋出 AiValidationException', () {
      const raw = '{"summary": "incomplete"}';
      expect(() => AiValidator.validateResponse(raw), throwsA(isA<AiValidationException>()));
    });

    test('當型別錯誤時應拋出 AiValidationException', () {
      const raw = '{"petVoice": "not a list", "knowledgeStation": {}, "summary": "S", "tags": [], "confidence": "high", "tone": "warm", "version": "v1", "inputMode": "free"}';
      expect(() => AiValidator.validateResponse(raw), throwsA(isA<AiValidationException>()));
    });
  });

  group('AiValidator - Safe Response Validation', () {
    test('應該能正確解析安全版 JSON 回應', () {
      const raw = '''
{
  "version": "1.0",
  "mode": "safe_default",
  "disclaimer": "這是一份基於文字的保守推論。",
  "pet_voice": {
    "text": "主人，我今天感覺很平靜。",
    "tone": "gentle",
    "is_inference": true
  },
  "knowledge_tips": ["定時餵食很重要"],
  "safety_alert": {
    "has_red_flags": false,
    "message": "一切正常"
  },
  "next_steps": ["繼續觀察"],
  "confidence": 0.9,
  "needs_more_info": false
}
''';
      final response = AiValidator.validateSafeResponse(raw);
      expect(response.mode, "safe_default");
      expect(response.petVoice.text, "主人，我今天感覺很平靜。");
      expect(response.safetyAlert.hasRedFlags, false);
    });

    test('當缺少必要欄位時應拋出 AiValidationException', () {
      const raw = '{"version": "1.0", "mode": "safe_default"}';
      expect(() => AiValidator.validateSafeResponse(raw), throwsA(isA<AiValidationException>()));
    });
  });
}
