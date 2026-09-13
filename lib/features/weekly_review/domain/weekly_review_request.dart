import 'package:ai_pet_communication/core/domain/app_request.dart';
import 'weekly_review.dart';

sealed class WeeklyReviewRequest<T> extends AppRequest<T> {
  const WeeklyReviewRequest();
}

final class GetWeeklyReview extends WeeklyReviewRequest<WeeklyReview> {
  final String petId;
  final String week;
  const GetWeeklyReview({required this.petId, required this.week});
}

final class GetWeeklyReviewSource extends WeeklyReviewRequest<ReviewSource> {
  final String petId;
  final String week;
  final String entryId;
  const GetWeeklyReviewSource({
    required this.petId,
    required this.week,
    required this.entryId,
  });
}

final class MarkWeeklyReviewViewed extends WeeklyReviewRequest<void> {
  final String petId;
  final String week;
  const MarkWeeklyReviewViewed({required this.petId, required this.week});
}

final class SetReviewPreference extends WeeklyReviewRequest<void> {
  final bool enabled;
  const SetReviewPreference({required this.enabled});
}

final class RequestWeeklyReview extends WeeklyReviewRequest<void> {
  final String petId;
  final String week;
  const RequestWeeklyReview({required this.petId, required this.week});
}
