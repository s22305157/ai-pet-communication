import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/pilot_repository.dart';
import 'pilot_metrics_screen.dart';
import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import 'package:ai_pet_communication/widgets/community_image.dart';

class PilotAdminScreen extends StatefulWidget {
  final PilotRepository repository;
  const PilotAdminScreen({super.key, required this.repository});
  @override
  State<PilotAdminScreen> createState() => _PilotAdminScreenState();
}

class _PilotAdminScreenState extends State<PilotAdminScreen> {
  String kind = 'reports';
  Map<String, dynamic>? cursor;
  @override
  Widget build(BuildContext context) => PilotSurface(
    title: '試營運管理',
    repository: widget.repository,
    loader: () async {
      final dashboard = await widget.repository.call('adminGetPilotDashboard');
      final page = await widget.repository.call('adminListPilotData', {
        'kind': kind,
        if (cursor != null) 'cursor': cursor,
      });
      return {...dashboard, ...page};
    },
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('管理受邀資格與社群分享內容。私人日記與 AI 回顧不在此介面提供。'),
        if (c.data['flags'] != null)
          TextButton.icon(
            icon: const Icon(Icons.insights),
            label: const Text('查看試營運成效與成本'),
            onPressed: c.busy
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PilotMetricsScreen(repository: widget.repository),
                    ),
                  ),
          ),
        if (c.data['flags'] != null) ...[
          Text(
            '受邀資料 ${c.data['participants']} 筆 · 待處理檢舉 ${c.data['openReports']} 件 · 停權 ${c.data['suspended']} 人',
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('功能開關'),
            children: [
              for (final flag in [
                ('journalEnabled', '日記新增／編輯'),
                ('reviewEnabled', '新增 AI 回顧與排程'),
                ('communityEnabled', '同伴圈開放'),
                ('communityWriteEnabled', '同伴圈發文與互動'),
              ])
                SwitchListTile(
                  title: Text(flag.$2),
                  value: c.data['flags'][flag.$1] == true,
                  onChanged: c.busy
                      ? null
                      : (v) async {
                          if (await pilotConfirm(
                            context,
                            '更新${flag.$2}？',
                            '此設定會立即影響連線到目前環境的試營運會員。',
                          )) {
                            await c.mutate('adminSetPilotFlags', {
                              'flags': {flag.$1: v},
                            });
                          }
                        },
                ),
            ],
          ),
          ExpansionTile(
            title: const Text('近七天已同意量測的事件'),
            subtitle: const Text('排除測試與管理帳號；此處為事件次數。'),
            children: [
              for (final e in (c.data['lastSevenDayEvents'] as Map).entries)
                ListTile(
                  title: Text(switch (e.key) {
                    'activated' => '啟用日記',
                    'pet_created' => '建立日記毛孩',
                    'entry_created' => '新增日記',
                    'entry_updated' => '編輯日記',
                    'review_generated' => '回顧完成',
                    'review_viewed' => '查看回顧',
                    'post_created' => '分享貼文',
                    'comment_created' => '新增留言',
                    'encouragement_created' => '給予鼓勵',
                    _ => '其他事件',
                  }),
                  trailing: Text('${e.value}'),
                ),
              if (c.data['truncated'] == true) const Text('資料超過本頁彙總上限，顯示部分統計。'),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: kind,
            items: const [
              DropdownMenuItem(value: 'reports', child: Text('檢舉處理')),
              DropdownMenuItem(value: 'participants', child: Text('試營運名單')),
              DropdownMenuItem(value: 'audit', child: Text('操作紀錄')),
            ],
            onChanged: c.busy
                ? null
                : (v) {
                    setState(() {
                      kind = v!;
                      cursor = null;
                    });
                    c.load();
                  },
          ),
          if (kind == 'participants')
            TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('邀請既有帳號'),
              onPressed: c.busy
                  ? null
                  : () async {
                      final uid = await pilotTextDialog(
                        context,
                        '輸入既有帳號的 Firebase UID',
                        maxLength: 128,
                      );
                      if (uid == null || !context.mounted) return;
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        await c.mutate('adminSetPilotParticipant', {
                          'uid': uid,
                          'status': 'invited',
                          'expiresAtMs': date
                              .add(const Duration(days: 1))
                              .millisecondsSinceEpoch,
                          'isTest': false,
                        });
                      }
                    },
            ),
          for (final row in c.data['items'] as List? ?? [])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kind == 'participants') ...[
                      SelectableText(row['id'] as String),
                      Text(
                        '${row['status'] == 'invited' ? '受邀' : '停用'} · 到期 ${DateFormat('yyyy/MM/dd').format(DateTime.fromMillisecondsSinceEpoch((row['expiresAtMs'] as num).toInt()))}',
                      ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (date != null) {
                                      await c
                                          .mutate('adminSetPilotParticipant', {
                                            'uid': row['id'],
                                            'status': 'invited',
                                            'expiresAtMs': date
                                                .add(const Duration(days: 1))
                                                .millisecondsSinceEpoch,
                                            'isTest': row['isTest'],
                                          });
                                    }
                                  },
                            child: const Text('邀請／更新期限'),
                          ),
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () async {
                                    if (await pilotConfirm(
                                      context,
                                      '停用此帳號的試營運資格？',
                                      '原有私人日記仍可閱讀、匯出與刪除。',
                                    )) {
                                      await c
                                          .mutate('adminSetPilotParticipant', {
                                            'uid': row['id'],
                                            'status': 'disabled',
                                            'expiresAtMs': DateTime.now()
                                                .add(const Duration(days: 1))
                                                .millisecondsSinceEpoch,
                                            'isTest': row['isTest'],
                                          });
                                    }
                                  },
                            child: const Text('停用資格'),
                          ),
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () async {
                                    final reason = await pilotTextDialog(
                                      context,
                                      row['postingSuspended'] == true
                                          ? '恢復發文的原因'
                                          : '暫停發文的原因',
                                    );
                                    if (reason != null) {
                                      await c
                                          .mutate('adminSetPostingSuspended', {
                                            'uid': row['id'],
                                            'suspended':
                                                row['postingSuspended'] != true,
                                            'reason': reason,
                                          });
                                    }
                                  },
                            child: Text(
                              row['postingSuspended'] == true ? '恢復發文' : '暫停發文',
                            ),
                          ),
                        ],
                      ),
                    ] else if (kind == 'reports') ...[
                      Text(row['status'] == 'open' ? '待處理' : '已處理'),
                      Text('檢舉原因：${row['reason']}'),
                      const Divider(),
                      Text('${row['alias']}'),
                      SelectableText(row['text'] as String),
                      Wrap(
                        children: [
                          for (final mediaId in row['mediaIds'] as List? ?? [])
                            CommunityImage(
                              key: ValueKey(
                                '${row['id']}_${row['contentRevision']}_$mediaId',
                              ),
                              repository: widget.repository,
                              postId: row['postId'] as String,
                              mediaId: mediaId as String,
                              reportId: row['id'] as String,
                            ),
                        ],
                      ),
                      Wrap(
                        children: [
                          for (final action in [
                            ('hide', '隱藏'),
                            ('restore', '恢復'),
                            ('dismiss', '結案'),
                          ])
                            TextButton(
                              onPressed:
                                  c.busy ||
                                      (action.$1 != 'dismiss' &&
                                          row['contentStatus'] == 'unavailable')
                                  ? null
                                  : () async {
                                      final reason = await pilotTextDialog(
                                        context,
                                        '${action.$2}處理說明（會通知當事人）',
                                      );
                                      if (reason != null) {
                                        await c.mutate(
                                          'adminModerateCommunity',
                                          {
                                            'reportId': row['id'],
                                            'expectedRevision': row['revision'],
                                            'contentRevision':
                                                row['contentRevision'],
                                            'action': action.$1,
                                            'reason': reason,
                                          },
                                        );
                                      }
                                    },
                              child: Text(action.$2),
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '${row['action']} · ${DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch((row['createdAtMs'] as num).toInt()))}',
                      ),
                      SelectableText('操作者：${row['actor']}\n${row['details']}'),
                    ],
                  ],
                ),
              ),
            ),
          if (c.data['cursor'] != null)
            TextButton(
              onPressed: c.busy
                  ? null
                  : () {
                      cursor = Map<String, dynamic>.from(
                        c.data['cursor'] as Map,
                      );
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
      ],
    ),
  );
}
