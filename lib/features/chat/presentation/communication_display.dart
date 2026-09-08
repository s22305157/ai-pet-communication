import 'dart:convert';
import '../domain/ai_response_model.dart';
import '../domain/ai_safe_response_model.dart';

// Historical answers included a disclaimer inside the voice. The shared view
// labels the conversation as AI; keep the stored response intact.
String naturalPetVoice(String value) {
  var text = value.trim().replaceFirst(
    RegExp(r'^【[^】]*(?:推測|想像|心聲)[^】]*】\s*'),
    '',
  );
  if (text.startsWith('「') && text.endsWith('」')) {
    text = text.substring(1, text.length - 1);
  }
  return text.replaceAll('【', '').replaceAll('】', '').trim();
}

dynamic parseCommunication(String content) {
  try {
    final value = jsonDecode(content);
    if (value is! Map<String, dynamic>) return null;
    if (value['petVoice'] is List) return AiResponseModel.fromMap(value);
    if (value['pet_voice'] is Map) return AiSafeResponseModel.fromMap(value);
  } catch (_) {
    // Legacy plain text remains readable; malformed structured data stays hidden.
  }
  return null;
}

String readingPreview(String content) {
  final result = parseCommunication(content);
  if (result is AiResponseModel && result.petVoice.isNotEmpty) {
    return naturalPetVoice(result.petVoice.first.answer);
  }
  if (result is AiSafeResponseModel) {
    return naturalPetVoice(result.petVoice.text);
  }
  if (content.trimLeft().startsWith('{') ||
      content.trimLeft().startsWith('[')) {
    return '這筆紀錄暫時無法顯示，請稍後再試。';
  }
  return content;
}

String communicationCopyText(dynamic result) {
  if (result is AiResponseModel) {
    return [
      for (final voice in result.petVoice)
        '你：${voice.question}\n毛孩：${naturalPetVoice(voice.answer)}',
      '${result.knowledgeStation.title}\n${result.knowledgeStation.content}',
      '重點摘要\n${result.summary}',
    ].join('\n\n');
  }
  if (result is AiSafeResponseModel) {
    return [
      naturalPetVoice(result.petVoice.text),
      if (result.safetyAlert.hasRedFlags) result.safetyAlert.message,
      ...result.knowledgeTips,
      ...result.nextSteps,
    ].join('\n\n');
  }
  return '';
}
