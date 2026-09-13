import 'package:ai_pet_communication/core/data/wire_values.dart';
import '../domain/weekly_review_request.dart';
import '../domain/weekly_review.dart';

(String, Map<String, dynamic>) encodeWeeklyReviewRequest(
  WeeklyReviewRequest request,
) => switch (request) {
  GetWeeklyReview r => ('getWeeklyReview', {'petId': r.petId, 'week': r.week}),
  GetWeeklyReviewSource r => (
    'getWeeklyReviewSource',
    {'petId': r.petId, 'week': r.week, 'entryId': r.entryId},
  ),
  MarkWeeklyReviewViewed r => (
    'markWeeklyReviewViewed',
    {'petId': r.petId, 'week': r.week},
  ),
  SetReviewPreference r => (
    'setReviewPreference',
    {'enabled': r.enabled, 'consentVersion': 'weekly-review-v1'},
  ),
  RequestWeeklyReview r => (
    'requestWeeklyReview',
    {'petId': r.petId, 'week': r.week},
  ),
};

T decodeWeeklyReviewResponse<T>(
  WeeklyReviewRequest<T> request,
  Map<String, dynamic> data,
) {
  final Object? value = switch (request) {
    GetWeeklyReview() => _review(data),
    GetWeeklyReviewSource() => ReviewSource(
      context: wireString(data, 'context'),
      observation: wireString(data, 'observation'),
      action: wireString(data, 'action'),
      outcome: wireString(data, 'outcome'),
    ),
    _ => null,
  };
  return value as T;
}

WeeklyReview _review(Map<String, dynamic> data) {
  final stats = wireMap(data['stats'] ?? {});
  final status = data['status'] as String? ?? 'not_started';
  ReviewResult? result;
  if (status == 'ready') {
    final raw = wireMap(data['result']);
    List<ReviewStatement> statements(String field) => [
      for (final row in raw[field] as List)
        ReviewStatement(
          text: row['text'] as String,
          entryIds: List<String>.from(row['entryIds'] as List),
        ),
    ];
    result = ReviewResult(
      happenings: statements('happenings'),
      observations: statements('observations'),
      tips: statements('tips'),
      petVoice: raw['petVoice'] as String,
    );
  }
  return WeeklyReview(
    status: status,
    safetyMessage: wireString(data, 'safetyMessage'),
    days: wireInt(stats, 'days'),
    entries: wireInt(stats, 'entries'),
    textDays: wireInt(stats, 'textDays'),
    attempts: wireInt(data, 'attempts'),
    trialEndsAtMs: wireInt(data, 'trialEndsAtMs'),
    analysisEnabled: data['analysisEnabled'] == true,
    canGenerate: data['canGenerate'] == true,
    result: result,
  );
}
