import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/domain/chat_consultation.dart';

const sampleConsultation = ChatConsultation(
  requestId: 'request-0000000001',
  petId: 'pet1',
  useSafeMode: true,
  request: AiRequestModel(
    ownerProfile: OwnerProfile(
      experienceLevel: '新手',
      careStyle: '親密',
      emotionStyle: '平靜',
      dailyRoutine: '規律',
      mainConcern: '飲食',
    ),
    petProfile: PetProfile(
      name: '小花',
      species: '貓',
      breed: '',
      age: 2,
      coatColor: '',
      personalityTraits: [],
    ),
    story: '今天精神很好',
    questions: ['吃飯正常嗎？'],
    inputMode: 'free',
  ),
);
const sampleSafeResponse = '''
{"version":"1","mode":"safe_default","disclaimer":"依文字推論",
"pet_voice":{"text":"先觀察作息","tone":"gentle","is_inference":true},
"knowledge_tips":["持續觀察"],"safety_alert":{"has_red_flags":false,"message":"繼續觀察"},
"next_steps":["記錄作息"],"confidence":0.5,"needs_more_info":true}
''';
