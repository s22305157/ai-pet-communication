import 'package:flutter/material.dart';
import '../../pilot/domain/pilot_repository.dart';
import '../../pilot/domain/pilot_request.dart';

import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../domain/community_post.dart';
import 'package:ai_pet_communication/widgets/community_image.dart';

class CommunityPostScreen extends StatefulWidget {
  final PilotRepository repository;
  final String postId;
  const CommunityPostScreen({
    super.key,
    required this.repository,
    required this.postId,
  });
  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final comment = TextEditingController(),
      alias = TextEditingController(text: '毛孩同伴');
  PageCursor? cursor;
  @override
  void dispose() {
    comment.dispose();
    alias.dispose();
    super.dispose();
  }

  Future<CommunityDetail> _load() async {
    final post = await widget.repository.execute(
      GetCommunityPost(postId: widget.postId),
    );
    final comments = await widget.repository.execute(
      ListCommunityComments(postId: widget.postId, cursor: cursor),
    );
    final access = await widget.repository.execute(const GetCommunityAccess());
    return CommunityDetail(
      post: post,
      comments: comments,
      canWrite: access.canWrite,
    );
  }

  @override
  Widget build(BuildContext context) => PilotSurface<CommunityDetail>(
    title: '同伴的日常',
    repository: widget.repository,
    loader: _load,
    builder: (context, c) {
      final detail = c.value;
      if (detail == null) return const SizedBox.shrink();
      final post = detail.post;
      final write = detail.canWrite && post.status == 'published' && !c.busy;
      Future<void> reportOrBlock(String action, [String? commentId]) async {
        if (action == 'report') {
          final reason = await pilotTextDialog(context, '檢舉原因');
          if (reason != null) {
            await c.submit(
              ReportCommunityContent(
                postId: post.id,
                commentId: commentId,
                reason: reason,
              ),
            );
          }
        } else if (await pilotConfirm(
          context,
          '封鎖這位同伴？',
          '雙方將無法查看彼此內容或新增互動。',
        )) {
          final ok = await c.submit(
            BlockCommunityAuthor(postId: post.id, commentId: commentId),
          );
          if (ok && commentId == null && context.mounted) {
            Navigator.pop(context);
          }
        }
      }

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${post.alias} · ${post.topic}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SelectableText(post.text),
          Wrap(
            children: [
              for (final id in post.mediaIds)
                CommunityImage(
                  key: ValueKey('${post.revision}_$id'),
                  repository: widget.repository,
                  postId: post.id,
                  mediaId: id,
                ),
            ],
          ),
          if (post.own)
            Wrap(
              children: [
                TextButton(
                  onPressed: c.busy || !detail.canWrite
                      ? null
                      : () async {
                          final text = await pilotTextDialog(
                            context,
                            '編輯貼文文字',
                            initial: post.text,
                            maxLength: 3000,
                          );
                          if (text != null) {
                            await c.submit(
                              EditCommunityPost(
                                postId: post.id,
                                text: text,
                                topic: post.topic,
                                expectedRevision: post.revision,
                              ),
                            );
                          }
                        },
                  child: const Text('編輯文字'),
                ),
                TextButton(
                  onPressed: c.busy || !detail.canWrite
                      ? null
                      : () async {
                          final topic = await showDialog<String>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('變更主題'),
                              children: [
                                for (final t in communityTopics)
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, t),
                                    child: Text(t),
                                  ),
                              ],
                            ),
                          );
                          if (topic != null) {
                            await c.submit(
                              EditCommunityPost(
                                postId: post.id,
                                text: post.text,
                                topic: topic,
                                expectedRevision: post.revision,
                              ),
                            );
                          }
                        },
                  child: const Text('變更主題'),
                ),
                TextButton(
                  onPressed: c.busy
                      ? null
                      : () async {
                          if (!await pilotConfirm(
                            context,
                            '撤回貼文？',
                            '貼文與分享圖片將無法查看，原始私人日記會保留。',
                          )) {
                            return;
                          }
                          final ok = await c.submit(
                            WithdrawCommunityPost(
                              postId: post.id,
                              expectedRevision: post.revision,
                            ),
                          );
                          if (ok && context.mounted) Navigator.pop(context);
                        },
                  child: const Text('撤回貼文'),
                ),
              ],
            )
          else
            Wrap(
              children: [
                TextButton(
                  onPressed: c.busy ? null : () => reportOrBlock('report'),
                  child: const Text('檢舉貼文'),
                ),
                TextButton(
                  onPressed: c.busy ? null : () => reportOrBlock('block'),
                  child: const Text('封鎖作者'),
                ),
              ],
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.favorite_border),
            onPressed: write && post.encouraged != true
                ? () => c.submit(EncourageCommunityPost(postId: post.id))
                : null,
            label: Text(
              '${post.encouraged == true ? '已給你鼓勵' : '給你鼓勵'} · ${post.encouragementCount}',
            ),
          ),
          const SizedBox(height: 20),
          Text('留言', style: Theme.of(context).textTheme.titleMedium),
          for (final row in detail.comments.items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.alias),
                    SelectableText(row.text),
                    if (row.own == true)
                      TextButton(
                        onPressed: c.busy
                            ? null
                            : () async {
                                if (await pilotConfirm(
                                  context,
                                  '刪除留言？',
                                  '這則留言將無法復原。',
                                )) {
                                  await c.submit(
                                    DeleteCommunityComment(
                                      postId: post.id,
                                      commentId: row.id,
                                      expectedRevision: row.revision,
                                    ),
                                  );
                                }
                              },
                        child: const Text('刪除留言'),
                      )
                    else
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => reportOrBlock('report', row.id),
                            child: const Text('檢舉'),
                          ),
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => reportOrBlock('block', row.id),
                            child: const Text('封鎖'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (detail.comments.cursor != null)
            TextButton(
              onPressed: c.busy
                  ? null
                  : () {
                      cursor = detail.comments.cursor;
                      c.load();
                    },
              child: const Text('較早的留言'),
            ),
          if (cursor != null)
            TextButton(
              onPressed: c.busy
                  ? null
                  : () {
                      cursor = null;
                      c.load();
                    },
              child: const Text('最新留言'),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: alias,
            maxLength: 40,
            enabled: write,
            decoration: const InputDecoration(labelText: '公開別名'),
          ),
          TextField(
            controller: comment,
            maxLength: 500,
            minLines: 2,
            maxLines: 5,
            enabled: write,
            decoration: const InputDecoration(labelText: '留下一句回應'),
          ),
          FilledButton(
            onPressed: !write
                ? null
                : () async {
                    if (comment.text.trim().isEmpty ||
                        alias.text.trim().isEmpty) {
                      return;
                    }
                    if (await c.submit(
                      AddCommunityComment(
                        postId: post.id,
                        alias: alias.text.trim(),
                        text: comment.text.trim(),
                      ),
                    )) {
                      comment.clear();
                    }
                  },
            child: const Text('送出留言'),
          ),
        ],
      );
    },
  );
}
