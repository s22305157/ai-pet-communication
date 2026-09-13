import '../domain/pilot_admin.dart';
import '../domain/pilot_request.dart';
import 'package:flutter/material.dart';
import 'package:ai_pet_communication/core/domain/request_repository.dart';
import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../../../app/pilot_routes.dart';

class PilotNotificationsScreen extends StatefulWidget {
  final RequestRepository repository;
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
  PilotCursor? cursor;
  @override
  Widget build(BuildContext context) => PilotSurface<PilotNotificationPage>(
    title: '站內通知',
    repository: widget.repository,
    loader: () =>
        widget.repository.execute(ListPilotNotifications(cursor: cursor)),
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final n in c.value?.items ?? [])
          ListTile(
            leading: Icon(
              n.read == true
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            title: Text(switch (n.type) {
              'review' => '${n.week} 的每週回顧完成了',
              'comment' => '你的貼文有新留言',
              'encouragement' => '${n.count} 位同伴給你鼓勵',
              _ => n.message.isEmpty ? '管理結果已更新' : n.message,
            }),
            onTap: c.busy
                ? null
                : () async {
                    if (!await c.submit(MarkPilotNotificationRead(n.id)) ||
                        !context.mounted ||
                        !c.current) {
                      return;
                    }
                    if (n.type == 'review') {
                      await widget.routes.review(
                        context,
                        widget.repository,
                        n.petId,
                        week: n.week,
                      );
                    } else if (n.postId != null) {
                      await widget.routes.post(
                        context,
                        widget.repository,
                        n.postId!,
                      );
                    }
                    await c.load();
                  },
          ),
        if (!c.busy && (c.value?.items ?? []).isEmpty) const Text('這一頁沒有新通知。'),
        if (c.value?.cursor != null)
          TextButton(
            onPressed: c.busy
                ? null
                : () {
                    cursor = c.value?.cursor;
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
