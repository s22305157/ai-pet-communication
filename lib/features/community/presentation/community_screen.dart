import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../pilot/domain/pilot_repository.dart';
import '../../pilot/domain/pilot_request.dart';

import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../domain/community_post.dart';
import 'package:ai_pet_communication/widgets/community_image.dart';
import 'community_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  final PilotRepository repository;
  const CommunityScreen({super.key, required this.repository});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String topic = '';
  bool mine = false;
  PageCursor? cursor;
  final previous = <PageCursor?>[];
  @override
  Widget build(
    BuildContext context,
  ) => PilotSurface<CommunityPage<CommunityPost>>(
    title: '同伴圈',
    repository: widget.repository,
    loader: () => widget.repository.execute(
      ListCommunityPosts(topic: topic, mine: mine, cursor: cursor),
    ),
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('受邀會員限定 · 從毛孩日記選擇一則紀錄，即可預覽並分享。'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('只看自己的貼文'),
          value: mine,
          onChanged: c.busy
              ? null
              : (v) {
                  setState(() {
                    mine = v;
                    cursor = null;
                    previous.clear();
                  });
                  c.load();
                },
        ),
        if (!mine)
          DropdownButtonFormField<String>(
            initialValue: topic,
            decoration: const InputDecoration(labelText: '依主題查看'),
            items: ['', ...communityTopics]
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.isEmpty ? '所有主題' : v),
                  ),
                )
                .toList(),
            onChanged: c.busy
                ? null
                : (v) {
                    setState(() {
                      topic = v!;
                      cursor = null;
                      previous.clear();
                    });
                    c.load();
                  },
          ),
        TextButton.icon(
          icon: const Icon(Icons.block),
          label: const Text('管理封鎖名單'),
          onPressed: c.busy
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommunityBlocksScreen(repository: widget.repository),
                    ),
                  );
                  await c.load();
                },
        ),
        if (!c.busy && (c.value?.items ?? []).isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('這一頁沒有可查看的貼文。'),
          ),
        for (final post in c.value?.items ?? <CommunityPost>[])
          Builder(
            builder: (context) {
              return Card(
                child: InkWell(
                  onTap: c.busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPostScreen(
                                repository: widget.repository,
                                postId: post.id,
                              ),
                            ),
                          );
                          await c.load();
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${post.alias} · ${post.topic}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat('MM/dd HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              post.createdAtMs,
                            ),
                          ),
                        ),
                        if (post.status == 'hidden') const Text('此貼文已被管理者隱藏'),
                        const SizedBox(height: 10),
                        Text(post.text),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final id in post.mediaIds)
                              CommunityImage(
                                key: ValueKey('${post.id}_$id'),
                                repository: widget.repository,
                                postId: post.id,
                                mediaId: id,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${post.commentCount} 則留言 · ${post.encouragementCount} 次鼓勵',
                        ),
                        const Text('查看貼文與留言'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Wrap(
          spacing: 16,
          children: [
            if (previous.isNotEmpty)
              OutlinedButton(
                onPressed: c.busy
                    ? null
                    : () {
                        cursor = previous.removeLast();
                        c.load();
                      },
                child: const Text('上一頁'),
              ),
            if (c.value?.cursor != null)
              OutlinedButton(
                onPressed: c.busy
                    ? null
                    : () {
                        previous.add(cursor);
                        cursor = c.value?.cursor;
                        c.load();
                      },
                child: const Text('下一頁'),
              ),
          ],
        ),
      ],
    ),
  );
}

class CommunityBlocksScreen extends StatefulWidget {
  final PilotRepository repository;
  const CommunityBlocksScreen({super.key, required this.repository});
  @override
  State<CommunityBlocksScreen> createState() => _CommunityBlocksScreenState();
}

class _CommunityBlocksScreenState extends State<CommunityBlocksScreen> {
  PageCursor? cursor;
  @override
  Widget build(BuildContext context) =>
      PilotSurface<CommunityPage<CommunityBlock>>(
        title: '封鎖名單',
        repository: widget.repository,
        loader: () =>
            widget.repository.execute(ListCommunityBlocks(cursor: cursor)),
        builder: (context, c) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('封鎖後，雙方都無法查看彼此內容或互動。解除自己的封鎖，不會解除對方的封鎖。'),
            for (final b in c.value?.items ?? <CommunityBlock>[])
              ListTile(
                title: Text(b.alias),
                trailing: TextButton(
                  onPressed: c.busy
                      ? null
                      : () => c.submit(UnblockCommunityAuthor(blockId: b.id)),
                  child: const Text('解除封鎖'),
                ),
              ),
            if ((c.value?.items ?? <CommunityBlock>[]).isEmpty && !c.busy)
              const Text('這一頁沒有封鎖的同伴。'),
            if (c.value?.cursor != null)
              TextButton(
                onPressed: c.busy
                    ? null
                    : () {
                        cursor = c.value?.cursor;
                        c.load();
                      },
                child: const Text('下一頁'),
              ),
            if (cursor != null)
              TextButton(
                onPressed: c.busy
                    ? null
                    : () {
                        cursor = null;
                        c.load();
                      },
                child: const Text('回第一頁'),
              ),
          ],
        ),
      );
}
