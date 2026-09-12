import 'dart:convert';
import '../domain/pilot_request.dart';
import '../../community/domain/community_post.dart';
import '../../weekly_review/domain/weekly_review.dart';

/// The only mapping between typed feature requests and callable wire names.
(String, Map<String, dynamic>) encodePilotRequest(
  PilotRequest request,
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
  GetCommunityAccess() => ('getPilotAccess', {}),
  ListCommunityPosts r => (
    'listCommunityPosts',
    {
      'topic': r.topic,
      'mine': r.mine,
      if (r.cursor != null)
        'cursor': {'id': r.cursor!.id, 'time': r.cursor!.time},
    },
  ),
  GetCommunityPost r => ('getCommunityPost', {'postId': r.postId}),
  ListCommunityComments r => (
    'listCommunityComments',
    {
      'postId': r.postId,
      if (r.cursor != null)
        'cursor': {'id': r.cursor!.id, 'time': r.cursor!.time},
    },
  ),
  ListCommunityBlocks r => (
    'listCommunityBlocks',
    {
      if (r.cursor != null)
        'cursor': {'id': r.cursor!.id, 'time': r.cursor!.time},
    },
  ),
  PublishCommunityPost r => (
    'publishCommunityPost',
    {
      'petId': r.petId,
      'entryId': r.entryId,
      'expectedRevision': r.expectedRevision,
      'text': r.text,
      'alias': r.alias,
      'topic': r.topic,
      'mediaIds': r.mediaIds,
      'confirmed': r.confirmed,
    },
  ),
  EditCommunityPost r => (
    'editCommunityPost',
    {
      'postId': r.postId,
      'text': r.text,
      'topic': r.topic,
      'expectedRevision': r.expectedRevision,
    },
  ),
  WithdrawCommunityPost r => (
    'withdrawCommunityPost',
    {'postId': r.postId, 'expectedRevision': r.expectedRevision},
  ),
  EncourageCommunityPost r => ('encourageCommunityPost', {'postId': r.postId}),
  AddCommunityComment r => (
    'addCommunityComment',
    {'postId': r.postId, 'alias': r.alias, 'text': r.text},
  ),
  DeleteCommunityComment r => (
    'deleteCommunityComment',
    {
      'postId': r.postId,
      'commentId': r.commentId,
      'expectedRevision': r.expectedRevision,
    },
  ),
  ReportCommunityContent r => (
    'reportCommunityContent',
    {
      'postId': r.postId,
      if (r.commentId != null) 'commentId': r.commentId,
      'reason': r.reason,
    },
  ),
  BlockCommunityAuthor r => (
    'blockCommunityAuthor',
    {'postId': r.postId, if (r.commentId != null) 'commentId': r.commentId},
  ),
  UnblockCommunityAuthor r => (
    'unblockCommunityAuthor',
    {'blockId': r.blockId},
  ),
  GetCommunityImage r => (
    r.reportId == null ? 'getCommunityImage' : 'adminGetReportedImage',
    {
      if (r.reportId == null) 'postId': r.postId,
      'mediaId': r.mediaId,
      if (r.reportId != null) 'reportId': r.reportId,
    },
  ),
};

T decodePilotResponse<T>(PilotRequest<T> request, Map<String, dynamic> data) {
  final Object? value = switch (request) {
    GetWeeklyReview() => _review(data),
    GetWeeklyReviewSource() => ReviewSource(
      context: _string(data, 'context'),
      observation: _string(data, 'observation'),
      action: _string(data, 'action'),
      outcome: _string(data, 'outcome'),
    ),
    GetCommunityAccess() => CommunityAccess(
      enabled: data['communityEnabled'] == true,
      canWrite: data['communityWriteEnabled'] == true,
    ),
    ListCommunityPosts() => _page(data, _post),
    GetCommunityPost() => _post(data),
    ListCommunityComments() => _page(
      data,
      (row) => CommunityComment(
        id: _id(row),
        text: _string(row, 'text'),
        alias: _string(row, 'alias'),
        revision: _int(row, 'revision'),
        own: row['own'] == true,
      ),
    ),
    ListCommunityBlocks() => _page(
      data,
      (row) => CommunityBlock(id: _id(row), alias: _string(row, 'alias')),
    ),
    GetCommunityImage() => base64Decode(data['base64'] as String),
    _ => null,
  };
  return value as T;
}

String _string(Map data, String key) => data[key] as String? ?? '';
int _int(Map data, String key) => (data[key] as num?)?.toInt() ?? 0;
String _id(Map data) {
  final id = data['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Missing record id');
  }
  return id;
}

Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value as Map);
CommunityPage<T> _page<T>(Map data, T Function(Map<String, dynamic>) parse) {
  final cursor = data['cursor'];
  return CommunityPage(
    items: [for (final row in data['items'] as List? ?? []) parse(_map(row))],
    cursor: cursor == null
        ? null
        : PageCursor(id: _id(_map(cursor)), time: _int(_map(cursor), 'time')),
  );
}

CommunityPost _post(Map<String, dynamic> row) => CommunityPost(
  id: _id(row),
  text: _string(row, 'text'),
  alias: _string(row, 'alias'),
  topic: _string(row, 'topic'),
  status: _string(row, 'status'),
  own: row['own'] == true,
  encouraged: row['encouraged'] == true,
  revision: _int(row, 'revision'),
  createdAtMs: _int(row, 'createdAtMs'),
  commentCount: _int(row, 'commentCount'),
  encouragementCount: _int(row, 'encouragementCount'),
  mediaIds: List<String>.from(row['mediaIds'] as List? ?? []),
);
WeeklyReview _review(Map<String, dynamic> data) {
  final stats = _map(data['stats'] ?? {});
  final status = data['status'] as String? ?? 'not_started';
  ReviewResult? result;
  if (status == 'ready') {
    final raw = _map(data['result']);
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
    safetyMessage: _string(data, 'safetyMessage'),
    days: _int(stats, 'days'),
    entries: _int(stats, 'entries'),
    textDays: _int(stats, 'textDays'),
    attempts: _int(data, 'attempts'),
    trialEndsAtMs: _int(data, 'trialEndsAtMs'),
    analysisEnabled: data['analysisEnabled'] == true,
    canGenerate: data['canGenerate'] == true,
    result: result,
  );
}
