import 'dart:typed_data';
import '../../community/domain/community_post.dart';
import '../../weekly_review/domain/weekly_review.dart';

sealed class PilotRequest<T> {
  const PilotRequest();
}

final class GetWeeklyReview extends PilotRequest<WeeklyReview> {
  final String petId;
  final String week;
  const GetWeeklyReview({required this.petId, required this.week});
}

final class GetWeeklyReviewSource extends PilotRequest<ReviewSource> {
  final String petId;
  final String week;
  final String entryId;
  const GetWeeklyReviewSource({
    required this.petId,
    required this.week,
    required this.entryId,
  });
}

final class MarkWeeklyReviewViewed extends PilotRequest<void> {
  final String petId;
  final String week;
  const MarkWeeklyReviewViewed({required this.petId, required this.week});
}

final class SetReviewPreference extends PilotRequest<void> {
  final bool enabled;
  const SetReviewPreference({required this.enabled});
}

final class RequestWeeklyReview extends PilotRequest<void> {
  final String petId;
  final String week;
  const RequestWeeklyReview({required this.petId, required this.week});
}

final class GetCommunityAccess extends PilotRequest<CommunityAccess> {
  const GetCommunityAccess();
}

final class ListCommunityPosts
    extends PilotRequest<CommunityPage<CommunityPost>> {
  final String topic;
  final bool mine;
  final PageCursor? cursor;
  const ListCommunityPosts({
    required this.topic,
    required this.mine,
    this.cursor,
  });
}

final class GetCommunityPost extends PilotRequest<CommunityPost> {
  final String postId;
  const GetCommunityPost({required this.postId});
}

final class ListCommunityComments
    extends PilotRequest<CommunityPage<CommunityComment>> {
  final String postId;
  final PageCursor? cursor;
  const ListCommunityComments({required this.postId, this.cursor});
}

final class ListCommunityBlocks
    extends PilotRequest<CommunityPage<CommunityBlock>> {
  final PageCursor? cursor;
  const ListCommunityBlocks({this.cursor});
}

final class PublishCommunityPost extends PilotRequest<void> {
  final String petId;
  final String entryId;
  final int expectedRevision;
  final String text;
  final String alias;
  final String topic;
  final List<String> mediaIds;
  final bool confirmed;
  const PublishCommunityPost({
    required this.petId,
    required this.entryId,
    required this.expectedRevision,
    required this.text,
    required this.alias,
    required this.topic,
    required this.mediaIds,
    required this.confirmed,
  });
}

final class EditCommunityPost extends PilotRequest<void> {
  final String postId;
  final String text;
  final String topic;
  final int expectedRevision;
  const EditCommunityPost({
    required this.postId,
    required this.text,
    required this.topic,
    required this.expectedRevision,
  });
}

final class WithdrawCommunityPost extends PilotRequest<void> {
  final String postId;
  final int expectedRevision;
  const WithdrawCommunityPost({
    required this.postId,
    required this.expectedRevision,
  });
}

final class EncourageCommunityPost extends PilotRequest<void> {
  final String postId;
  const EncourageCommunityPost({required this.postId});
}

final class AddCommunityComment extends PilotRequest<void> {
  final String postId;
  final String alias;
  final String text;
  const AddCommunityComment({
    required this.postId,
    required this.alias,
    required this.text,
  });
}

final class DeleteCommunityComment extends PilotRequest<void> {
  final String postId;
  final String commentId;
  final int expectedRevision;
  const DeleteCommunityComment({
    required this.postId,
    required this.commentId,
    required this.expectedRevision,
  });
}

final class ReportCommunityContent extends PilotRequest<void> {
  final String postId;
  final String? commentId;
  final String reason;
  const ReportCommunityContent({
    required this.postId,
    this.commentId,
    required this.reason,
  });
}

final class BlockCommunityAuthor extends PilotRequest<void> {
  final String postId;
  final String? commentId;
  const BlockCommunityAuthor({required this.postId, this.commentId});
}

final class UnblockCommunityAuthor extends PilotRequest<void> {
  final String blockId;
  const UnblockCommunityAuthor({required this.blockId});
}

final class GetCommunityImage extends PilotRequest<Uint8List> {
  final String postId;
  final String mediaId;
  final String? reportId;
  const GetCommunityImage({
    required this.postId,
    required this.mediaId,
    this.reportId,
  });
}
