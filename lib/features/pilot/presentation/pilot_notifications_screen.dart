import 'package:flutter/material.dart';
import '../domain/pilot_repository.dart';
import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../../../app/pilot_routes.dart';

class PilotNotificationsScreen extends StatefulWidget {
  final PilotRepository repository;
  final PilotRoutes routes;
  const PilotNotificationsScreen({
    super.key,
    required this.repository,
    required this.routes,
  });
  @override
  State<PilotNotificationsScreen> createState() =>
      _PilotNotificationsScreenState();
}

class _PilotNotificationsScreenState extends State<PilotNotificationsScreen> {
  Map<String, dynamic>? cursor;
  @override
  Widget build(BuildContext context) => PilotSurface(
    title: '站內通知',
    repository: widget.repository,
    loader: () => widget.repository.call('listPilotNotifications', {
      if (cursor != null) 'cursor': cursor,
    }),
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final n in c.data['items'] as List? ?? [])
          ListTile(
            leading: Icon(
              n['read'] == true
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            title: Text(switch (n['type']) {
              'review' => '${n['week']} 的每週回顧完成了',
              'comment' => '你的貼文有新留言',
              'encouragement' => '${n['count']} 位同伴給你鼓勵',
              _ => n['message'] as String? ?? '管理結果已更新',
            }),
            onTap: c.busy
                ? null
                : () async {
                    if (!await c.mutate('markPilotNotificationRead', {
                          'notificationId': n['id'],
                        }) ||
                        !context.mounted ||
                        !c.current) {
                      return;
                    }
                    if (n['type'] == 'review') {
                      await widget.routes.review(
                        context,
                        widget.repository,
                        n['petId'] as String,
                        week: n['week'] as String,
                      );
                    } else if (n['postId'] != null) {
                      await widget.routes.post(
                        context,
                        widget.repository,
                        n['postId'] as String,
                      );
                    }
                    await c.load();
                  },
          ),
        if (!c.busy && (c.data['items'] as List? ?? []).isEmpty)
          const Text('這一頁沒有新通知。'),
        if (c.data['cursor'] != null)
          TextButton(
            onPressed: c.busy
                ? null
                : () {
                    cursor = Map<String, dynamic>.from(c.data['cursor'] as Map);
                    c.load();
                  },
            child: const Text('較早的通知'),
          ),
        if (cursor != null)
          TextButton(
            onPressed: c.busy
                ? null
                : () {
                    cursor = null;
                    c.load();
                  },
            child: const Text('最新通知'),
          ),
      ],
    ),
  );
}
