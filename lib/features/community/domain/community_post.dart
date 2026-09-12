const communityTopics = ['毛孩到家', '熟悉彼此', '今天的小進步'];

class PageCursor {
  final String id;
  final int time;
  const PageCursor({required this.id, required this.time});
}

class CommunityPage<T> {
  final List<T> items;
  final PageCursor? cursor;
  CommunityPage({required List<T> items, this.cursor})
    : items = List.unmodifiable(items);
}

class CommunityAccess {
  final bool enabled, canWrite;
  const CommunityAccess({required this.enabled, required this.canWrite});
}

class CommunityPost {
  final String id, text, alias, topic, status;
  final bool own, encouraged;
  final int revision, createdAtMs, commentCount, encouragementCount;
  final List<String> mediaIds;
  CommunityPost({
    required this.id,
    required this.text,
    required this.alias,
    required this.topic,
    required this.status,
    required this.own,
    required this.encouraged,
    required this.revision,
    required this.createdAtMs,
    required this.commentCount,
    required this.encouragementCount,
    required List<String> mediaIds,
  }) : mediaIds = List.unmodifiable(mediaIds);
}

class CommunityComment {
  final String id, text, alias;
  final int revision;
  final bool own;
  const CommunityComment({
    required this.id,
    required this.text,
    required this.alias,
    required this.revision,
    required this.own,
  });
}

class CommunityBlock {
  final String id, alias;
  const CommunityBlock({required this.id, required this.alias});
}

class CommunityDetail {
  final CommunityPost post;
  final CommunityPage<CommunityComment> comments;
  final bool canWrite;
  const CommunityDetail({
    required this.post,
    required this.comments,
    required this.canWrite,
  });
}
