import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/pilot_repository.dart';
import '../domain/pilot_request.dart';
import '../domain/pilot_metrics.dart';
import '../../../widgets/pilot_surface.dart';

class PilotInterestScreen extends StatefulWidget {
  final PilotRepository repository;
  const PilotInterestScreen({super.key, required this.repository});
  @override
  State<PilotInterestScreen> createState() => _PilotInterestScreenState();
}

class _PilotInterestScreenState extends State<PilotInterestScreen> {
  bool _viewRecorded = false;
  String _viewOperation = const Uuid().v4();
  @override
  Widget build(BuildContext context) => PilotSurface<PilotInterest>(
    title: '回顧方案與量測設定',
    repository: widget.repository,
    loader: () => widget.repository.execute(const GetPilotInterest()),
    builder: (context, c) {
      final interest = c.value;
      if (interest == null) return const SizedBox.shrink();
      if (interest.metricsConsent &&
          interest.canExpressInterest &&
          !_viewRecorded) {
        _viewRecorded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !c.current) return;
          try {
            await widget.repository.execute(
              const MarkPilotPriceViewed(),
              operationId: _viewOperation,
            );
          } catch (_) {
            // Optional measurement must not prevent changing preferences.
            _viewRecorded = false;
          }
        });
      }
      if (!interest.metricsConsent && _viewRecorded) {
        _viewRecorded = false;
        _viewOperation = const Uuid().v4();
      }
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('進階回顧方案', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            '預計 NT\$199／月，尚未開放購買。',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('規劃提供持續生成 AI 回顧的權益；價格、額度與內容將於正式開放前確認。'),
          const Text('這次只記錄通知意願，不會扣款、訂閱或變更現有會員與點數。通知方式將於開放前另行說明。'),
          const SizedBox(height: 16),
          Text(interest.interested ? '目前已登記：願意收到付費方案開放通知。' : '目前尚未登記通知意願。'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('願意收到付費方案開放通知'),
            subtitle: const Text('可以隨時取消，量測同意不影響登記。'),
            value: interest.interested,
            onChanged:
                c.busy || (!interest.canExpressInterest && !interest.interested)
                ? null
                : (v) => c.submit(SetPilotInterest(v)),
          ),
          if (!interest.canExpressInterest)
            const Text('試營運資格已到期或停用；仍可取消原有通知意願與管理量測設定。'),
          const Divider(height: 32),
          const Text('日記啟用後有一次性 28 天 AI 回顧試用。到期仍可記日記、參與已開放的同伴圈及閱讀有效既有回顧。'),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('同意成效量測'),
            subtitle: const Text(
              '記錄新增日記、查看回顧、互動及價格預告的事件，不含日記、照片、留言正文或精確位置。個人事件保留 90 天，長期保留不含識別資訊的彙總。撤回後立即停止納入新統計，並排程清除個人事件。',
            ),
            value: interest.metricsConsent,
            onChanged: c.busy || interest.cleanupPending
                ? null
                : (v) => c.submit(SetPilotMetricsConsent(v)),
          ),
          if (interest.cleanupPending) const Text('先前量測資料正在清除，完成後可重新開啟量測。'),
          const Text('不同意量測仍可使用已開放的功能。已產生且不含識別資訊的彙總不會回溯刪除。'),
        ],
      );
    },
  );
}
