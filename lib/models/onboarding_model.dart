enum QuestionType {
  singleChoice,
  multipleChoice,
  text,
  dropdown,
}

class OnboardingQuestion {
  final String id;
  final String title;
  final String? subtitle;
  final QuestionType type;
  final bool isRequired;
  final List<QuestionOption> options;

  const OnboardingQuestion({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.isRequired = true,
    this.options = const [],
  });
}

class QuestionOption {
  final String value;
  final String label;
  final String? description;

  const QuestionOption({
    required this.value,
    required this.label,
    this.description,
  });
}

const onboardingQuestions = <OnboardingQuestion>[
  OnboardingQuestion(
    id: 'pet_type',
    title: '你主要想和哪種毛孩互動？',
    subtitle: '這會幫助我們提供更貼近的內容與建議。',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(value: 'dog', label: '狗狗'),
      QuestionOption(value: 'cat', label: '貓咪'),
      QuestionOption(value: 'other', label: '其他寵物'),
      QuestionOption(value: 'undecided', label: '還沒有固定對象'),
    ],
  ),
  OnboardingQuestion(
    id: 'main_goal',
    title: '你目前最想從 App 得到什麼？',
    subtitle: '我們會依你的目標調整導引內容。',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(value: 'understand', label: '理解毛孩想表達什麼'),
      QuestionOption(value: 'knowledge', label: '補充寵物照顧知識'),
      QuestionOption(value: 'companionship', label: '取得日常陪伴建議'),
      QuestionOption(value: 'communication', label: '改善互動與溝通'),
      QuestionOption(value: 'explore', label: '先看看再說'),
    ],
  ),
  OnboardingQuestion(
    id: 'concern_area',
    title: '你現在最在意的是哪一類問題？',
    subtitle: '這會影響 AI 回應與內容推薦的方向。',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(value: 'emotion', label: '情緒與行為'),
      QuestionOption(value: 'health', label: '飲食與健康'),
      QuestionOption(value: 'care', label: '日常照顧'),
      QuestionOption(value: 'interaction', label: '互動與陪伴'),
      QuestionOption(value: 'beginner', label: '新手入門'),
    ],
  ),
  OnboardingQuestion(
    id: 'help_style',
    title: '你希望 App 主要怎麼幫助你？',
    subtitle: '可用來調整首頁功能順序。',
    type: QuestionType.singleChoice,
    options: [
      QuestionOption(value: 'ai_response', label: 'AI 即時回應'),
      QuestionOption(value: 'knowledge', label: '寵物知識補充'),
      QuestionOption(value: 'personalized', label: '個人化建議'),
      QuestionOption(value: 'simple', label: '簡單快速操作'),
      QuestionOption(value: 'all', label: '全部都要'),
    ],
  ),
  OnboardingQuestion(
    id: 'experience',
    title: '你養毛孩多久了？',
    subtitle: '這會幫助我們調整回答深度。',
    type: QuestionType.singleChoice,
    isRequired: false,
    options: [
      QuestionOption(value: 'preparing', label: '準備飼養中'),
      QuestionOption(value: 'new', label: '新手'),
      QuestionOption(value: 'under1', label: '1 年內'),
      QuestionOption(value: 'one_to_three', label: '1～3 年'),
      QuestionOption(value: 'over_three', label: '3 年以上'),
    ],
  ),
];

class OnboardingAnswer {
  final String questionId;
  final dynamic value;

  const OnboardingAnswer({
    required this.questionId,
    required this.value,
  });
}
