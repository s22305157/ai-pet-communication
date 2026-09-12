import 'package:flutter/material.dart';
import '../../journal/domain/journal_entry.dart';
import '../../pilot/domain/pilot_repository.dart';
import '../../pilot/domain/pilot_request.dart';

import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../domain/community_post.dart';

class CommunityShareScreen extends StatefulWidget {
  final PilotRepository repository;
  final Widget Function(String mediaId) sourceImageBuilder;
  final JournalEntry entry;
  final String petId;
  const CommunityShareScreen({
    super.key,
    required this.repository,
    required this.sourceImageBuilder,
    required this.entry,
    required this.petId,
  });
  @override
  State<CommunityShareScreen> createState() => _CommunityShareScreenState();
}

class _CommunityShareScreenState extends State<CommunityShareScreen> {
  late final text = TextEditingController(
    text: [
      widget.entry.observation,
      widget.entry.action,
      widget.entry.outcome,
    ].where((v) => v.isNotEmpty).join('\n\n'),
  );
  final alias = TextEditingController(text: '毛孩同伴');
  final selected = <String>{};
  String topic = communityTopics.first;
  bool preview = false;
  @override
  void dispose() {
    text.dispose();
    alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PilotSurface<CommunityAccess>(
    title: preview ? '確認分享內容' : '分享到同伴圈',
    repository: widget.repository,
    loader: () => widget.repository.execute(const GetCommunityAccess()),
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('同伴圈只有有效受邀會員可以查看。只分享下方文字與勾選的照片，請移除姓名、聯絡方式或其他不想分享的資訊。'),
        const SizedBox(height: 16),
        if (!preview) ...[
          TextField(
            controller: alias,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '公開別名'),
          ),
          DropdownButtonFormField<String>(
            initialValue: topic,
            items: communityTopics
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: c.busy ? null : (v) => setState(() => topic = v!),
            decoration: const InputDecoration(labelText: '主題'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            maxLength: 3000,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(labelText: '要分享的文字（可刪減、修改）'),
          ),
          for (final id in widget.entry.mediaIds)
            CheckboxListTile(
              value: selected.contains(id),
              title: widget.sourceImageBuilder(id),
              subtitle: const Text('分享這張照片'),
              onChanged: c.busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(id);
                      } else {
                        selected.remove(id);
                      }
                    }),
            ),
          FilledButton(
            onPressed: c.busy
                ? null
                : () {
                    if (alias.text.trim().isEmpty ||
                        (text.text.trim().isEmpty && selected.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請填寫別名，並選擇文字或照片')),
                      );
                      return;
                    }
                    setState(() => preview = true);
                  },
            child: const Text('預覽分享內容'),
          ),
        ] else ...[
          Text(
            '${alias.text.trim()} · $topic',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SelectableText(text.text.trim()),
          Wrap(
            children: [
              for (final id in selected) widget.sourceImageBuilder(id),
            ],
          ),
          const SizedBox(height: 16),
          const Text('發布後是一份獨立副本。日記編輯不會更新貼文；刪除來源日記會撤回貼文。'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                c.busy || c.value?.enabled != true || c.value?.canWrite != true
                ? null
                : () async {
                    final ok = await c.submit(
                      PublishCommunityPost(
                        petId: widget.petId,
                        entryId: widget.entry.id,
                        expectedRevision: widget.entry.revision,
                        text: text.text.trim(),
                        alias: alias.text.trim(),
                        topic: topic,
                        mediaIds: selected.toList(),
                        confirmed: true,
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context, true);
                  },
            child: const Text('確認發布到受邀同伴圈'),
          ),
          TextButton(
            onPressed: c.busy ? null : () => setState(() => preview = false),
            child: const Text('返回修改'),
          ),
        ],
      ],
    ),
  );
}
