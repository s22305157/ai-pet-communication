import 'package:ai_pet_communication/features/chat/application/safety_router.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AiRequestModel request({
    required String species,
    required String story,
    List<String> questions = const ['我該怎麼做？'],
  }) {
    return AiRequestModel(
      ownerProfile: const OwnerProfile(
        experienceLevel: 'intermediate',
        careStyle: 'gentle',
        emotionStyle: 'calm',
        dailyRoutine: 'stable',
        mainConcern: 'behavior',
      ),
      petProfile: PetProfile(
        name: '毛孩',
        species: species,
        breed: '',
        age: 4,
        coatColor: '',
        personalityTraits: const [],
      ),
      story: story,
      questions: questions,
      inputMode: 'free',
    );
  }

  group('SafetyRouter', () {
    test('貓反覆用力卻無尿會分流為急症', () {
      final decision = SafetyRouter.evaluate(
        request(species: '貓', story: '今天反覆進貓砂盆，一直用力尿但尿不出。'),
      );

      expect(decision.level, SafetyLevel.emergency);
      expect(decision.needsImmediateAction, isTrue);
      expect(decision.matchedRules, contains('urinary_obstruction'));
    });

    test('呼吸困難會分流為急症', () {
      final decision = SafetyRouter.evaluate(
        request(species: '狗', story: '狗狗突然持續呼吸急促，而且舌頭發紫。'),
      );

      expect(decision.level, SafetyLevel.emergency);
      expect(decision.matchedRules, contains('breathing_emergency'));
    });

    test('否定症狀不會誤判為急症', () {
      final decision = SafetyRouter.evaluate(
        request(
          species: '狗',
          story: '今天精神正常，沒有呼吸困難，也沒有嘔吐。',
          questions: const ['只是想了解日常活動安排。'],
        ),
      );

      expect(decision.level, SafetyLevel.general);
    });

    test('嘔吐等非立即紅旗會進入謹慎模式', () {
      final decision = SafetyRouter.evaluate(
        request(species: '狗', story: '今天嘔吐一次，現在仍有精神，想知道要記錄什麼。'),
      );

      expect(decision.level, SafetyLevel.caution);
      expect(decision.useSafeMode, isTrue);
    });

    test('故事滿 300 字且無症狀時使用一般模式', () {
      final decision = SafetyRouter.evaluate(
        request(
          species: '貓',
          story: '新貓適應紀錄正常，食慾、排泄與活動都穩定。' * 20,
          questions: const ['下一步如何逐漸讓兩隻貓看見彼此？'],
        ),
      );

      expect(decision.level, SafetyLevel.general);
      expect(decision.isLowInformation, isFalse);
      expect(decision.useSafeMode, isFalse);
    });

    test('故事未滿 300 字時保留安全模式', () {
      final decision = SafetyRouter.evaluate(
        request(species: '狗', story: '日常狀況穩定，想了解互動方式。'),
      );

      expect(decision.level, SafetyLevel.general);
      expect(decision.isLowInformation, isTrue);
      expect(decision.useSafeMode, isTrue);
    });
  });
}
