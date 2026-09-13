import 'dart:convert';
import 'package:ai_pet_communication/core/data/wire_values.dart';
import '../domain/community_request.dart';
import '../domain/community_post.dart';

(String, Map<String, dynamic>) encodeCommunityRequest(
  CommunityRequest request,
) => switch (request) {
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

T decodeCommunityResponse<T>(
  CommunityRequest<T> request,
  Map<String, dynamic> data,
) {
  final Object? value = switch (request) {
    GetCommunityAccess() => CommunityAccess(
      enabled: data['communityEnabled'] == true,
      canWrite: data['communityWriteEnabled'] == true,
    ),
    ListCommunityPosts() => _page(data, _post),
    GetCommunityPost() => _post(data),
    ListCommunityComments() => _page(
      data,
      (row) => CommunityComment(
        id: wireId(row),
        text: wireString(row, 'text'),
        alias: wireString(row, 'alias'),
        revision: wireInt(row, 'revision'),
        own: row['own'] == true,
      ),
    ),
    ListCommunityBlocks() => _page(
      data,
      (row) => CommunityBlock(id: wireId(row), alias: wireString(row, 'alias')),
    ),
    GetCommunityImage() => base64Decode(data['base64'] as String),
    _ => null,
  };
  return value as T;
}

CommunityPage<T> _page<T>(Map data, T Function(Map<String, dynamic>) parse) {
  final cursor = data['cursor'];
  return CommunityPage(
    items: [
      for (final row in data['items'] as List? ?? []) parse(wireMap(row)),
    ],
    cursor: cursor == null
        ? null
        : PageCursor(
            id: wireId(wireMap(cursor)),
            time: wireInt(wireMap(cursor), 'time'),
          ),
  );
}

CommunityPost _post(Map<String, dynamic> row) => CommunityPost(
  id: wireId(row),
  text: wireString(row, 'text'),
  alias: wireString(row, 'alias'),
  topic: wireString(row, 'topic'),
  status: wireString(row, 'status'),
  own: row['own'] == true,
  encouraged: row['encouraged'] == true,
  revision: wireInt(row, 'revision'),
  createdAtMs: wireInt(row, 'createdAtMs'),
  commentCount: wireInt(row, 'commentCount'),
  encouragementCount: wireInt(row, 'encouragementCount'),
  mediaIds: List<String>.from(row['mediaIds'] as List? ?? []),
);
