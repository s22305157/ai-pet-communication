import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_display.dart';

void main() {
  test('copied safe reply includes urgent steps without raw metadata', () {
    final response = parseCommunication(
      '{"pet_voice":{"text":"【推測】我需要幫忙。"},"safety_alert":{"has_red_flags":true,"message":"立即聯絡獸醫"},"next_steps":["前往急診"]}',
    );
    final text = communicationCopyText(response);
    expect(text, contains('我需要幫忙。'));
    expect(text, contains('立即聯絡獸醫'));
    expect(text, contains('前往急診'));
    expect(text, isNot(contains('【')));
    expect(text, isNot(contains('pet_voice')));
  });
  test(
    'historical voice removes wrapper without removing practical guidance',
    () {
      expect(
        naturalPetVoice('【以下是依描述做的想像，不能代表 Zena 真實心聲】「請陪我拉開距離。」'),
        '請陪我拉開距離。',
      );
      expect(naturalPetVoice('【立即就醫】請聯絡獸醫。'), '立即就醫請聯絡獸醫。');
    },
  );
  test('legacy text stays readable and malformed JSON never leaks as code', () {
    expect(readingPreview('今天一起散步。'), '今天一起散步。');
    expect(readingPreview('{"petVoice":'), '這筆紀錄暫時無法顯示，請稍後再試。');
    expect(readingPreview('{"internal":"metadata"}'), '這筆紀錄暫時無法顯示，請稍後再試。');
  });
  test('safe saved response produces a human-readable preview', () {
    expect(
      readingPreview('{"pet_voice":{"text":"我想安靜休息。","is_inference":true}}'),
      '我想安靜休息。',
    );
  });
}
