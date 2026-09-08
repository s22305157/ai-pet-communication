import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';

enum SafetyLevel { general, caution, emergency }

class SafetyDecision {
  final SafetyLevel level;
  final bool isLowInformation;
  final List<String> matchedRules;

  const SafetyDecision({
    required this.level,
    required this.isLowInformation,
    this.matchedRules = const [],
  });

  bool get useSafeMode => isLowInformation || level != SafetyLevel.general;
  bool get needsImmediateAction => level == SafetyLevel.emergency;

  Map<String, dynamic> toPromptMap() => {
    'level': level.name,
    'is_low_information': isLowInformation,
    'matched_rules': matchedRules,
    'needs_immediate_action': needsImmediateAction,
  };
}

class _SafetyRule {
  final String id;
  final RegExp pattern;
  final SafetyLevel level;
  final bool catsOnly;

  _SafetyRule(this.id, String expression, this.level, {this.catsOnly = false})
    : pattern = RegExp(expression, caseSensitive: false);
}

class SafetyRouter {
  static const int deepAnalysisThreshold = 300;

  static final List<_SafetyRule> _rules = [
    _SafetyRule(
      'breathing_emergency',
      r'呼吸困難|呼吸急促|無法呼吸|張口呼吸|嘴巴呼吸|發紺|舌頭.*(藍|紫)',
      SafetyLevel.emergency,
    ),
    _SafetyRule(
      'neurologic_emergency',
      r'抽搐|昏迷|失去意識|叫不醒|無法站立',
      SafetyLevel.emergency,
    ),
    _SafetyRule('bleeding_emergency', r'大出血|血流不止|持續出血', SafetyLevel.emergency),
    _SafetyRule(
      'urinary_obstruction',
      r'尿不出|沒有尿|無尿|一直[^。！？\n]{0,12}用力[^。！？\n]{0,8}尿|反覆[^。！？\n]{0,12}貓砂盆[^。！？\n]{0,8}(沒尿|無尿)',
      SafetyLevel.emergency,
      catsOnly: true,
    ),
    _SafetyRule(
      'toxin_or_foreign_body',
      r'(吃到|舔到|誤食|吞下)[^。！？\n]{0,12}(百合|人藥|清潔劑|殺蟲劑|毒物|針|牙線|線|繩)',
      SafetyLevel.emergency,
    ),
    _SafetyRule('major_trauma', r'被車撞|遭車撞|墜樓|高處墜落', SafetyLevel.emergency),
    _SafetyRule(
      'medical_caution',
      r'嘔吐|腹瀉|血尿|血便|疼痛|嗜睡|拒食|不吃東西|傷口|突然攻擊|突然咬人',
      SafetyLevel.caution,
    ),
  ];

  static SafetyDecision evaluate(AiRequestModel request) {
    return evaluateText(
      story: request.story,
      questions: request.questions,
      species: request.petProfile.species,
    );
  }

  static SafetyDecision evaluateText({
    required String story,
    required Iterable<String> questions,
    String species = '',
  }) {
    final questionText = questions.join(' ');
    final text = '$story $questionText'.trim();
    final isCat =
        species.toLowerCase().contains('貓') ||
        species.toLowerCase().contains('cat') ||
        text.contains('貓');
    final matchedEmergency = <String>[];
    final matchedCaution = <String>[];

    for (final rule in _rules) {
      if (rule.catsOnly && !isCat) continue;
      if (_hasNonNegatedMatch(rule.pattern, text)) {
        if (rule.level == SafetyLevel.emergency) {
          matchedEmergency.add(rule.id);
        } else {
          matchedCaution.add(rule.id);
        }
      }
    }

    final isLowInformation = story.trim().length < deepAnalysisThreshold;
    if (matchedEmergency.isNotEmpty) {
      return SafetyDecision(
        level: SafetyLevel.emergency,
        isLowInformation: isLowInformation,
        matchedRules: matchedEmergency,
      );
    }
    if (matchedCaution.isNotEmpty) {
      return SafetyDecision(
        level: SafetyLevel.caution,
        isLowInformation: isLowInformation,
        matchedRules: matchedCaution,
      );
    }
    return SafetyDecision(
      level: SafetyLevel.general,
      isLowInformation: isLowInformation,
    );
  }

  static bool containsEmergency(String text, {String species = ''}) {
    return evaluateText(
      story: text,
      questions: const [],
      species: species,
    ).needsImmediateAction;
  }

  static bool _hasNonNegatedMatch(RegExp pattern, String text) {
    for (final match in pattern.allMatches(text)) {
      final start = match.start;
      final prefix = text.substring(start > 6 ? start - 6 : 0, start);
      if (!RegExp(r'(沒有|並無|未見|未出現|沒有出現)\s*$').hasMatch(prefix)) {
        return true;
      }
    }
    return false;
  }
}
