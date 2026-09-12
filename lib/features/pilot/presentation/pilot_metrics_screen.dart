import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/pilot_metrics.dart';
import '../domain/pilot_repository.dart';
import '../domain/pilot_request.dart';
import '../../../widgets/pilot_surface.dart';
import 'pilot_cost_screen.dart';

class PilotMetricsScreen extends StatelessWidget {
  final PilotRepository repository;
  const PilotMetricsScreen({super.key, required this.repository});
  @override
  Widget build(BuildContext context) => PilotSurface<PilotMetricsReport>(
    title: '試營運成效',
    repository: repository,
    loader: () => repository.execute(const GetPilotMetrics()),
    builder: (context, c) {
      final report = c.value;
      if (report == null) return const SizedBox.shrink();
      final m = report.metrics;
      final costs = report.costs;
      String date(int ms) => DateFormat('yyyy/MM/dd').format(
        DateTime.fromMillisecondsSinceEpoch(
          ms,
          isUtc: true,
        ).add(const Duration(hours: 8)),
      );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('只納入目前同意量測的一般會員；排除測試與管理帳號。統計以台北時間計算，不提供私人內容。'),
          if (report.truncated)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('資料超過統計上限，暫不顯示比率。請由工程人員調整彙總方式後再查看。'),
            ),
          if (m != null) ...[
            Text(
              '${date(m.fromMs)}–${date(m.toMs)} · 同意量測 ${m.measuredParticipants} 人',
            ),
            const Text('等待完整觀察期後才納入分母。「觀察中」不當成失敗，沒有可計算資料時不顯示 0%。'),
            for (final row in [
              ('48 小時啟用率', '同意加入日記後 48 小時內完成第一則日記', m.activation),
              ('第四週持續使用率', '加入後第 22–28 天，至少兩個台北日期新增日記或查看回顧', m.retention),
              ('回顧查看率', '成功生成後 7 天內被查看的回顧', m.reviewViews),
              ('社群回應率', '發布後 7 天內收到其他同意量測的一般會員留言或鼓勵', m.communityResponses),
              ('升級意願率', '看過价格預告者，目前仍願意收到付費通知的比例', m.upgradeInterest),
            ])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(row.$2),
                      const SizedBox(height: 8),
                      Text(
                        row.$3.rate == null
                            ? '尚無可計算資料'
                            : '${(row.$3.rate! * 100).toStringAsFixed(1)}% · ${row.$3.numerator}/${row.$3.denominator}',
                      ),
                      if (row.$3.pending > 0) Text('觀察中 ${row.$3.pending}'),
                    ],
                  ),
                ),
              ),
            if (m.incompleteCohorts > 0)
              Text('${m.incompleteCohorts} 人在加入後才同意或重新同意量測，早期資料不足，未納入啟用與留存比率。'),
            if (m.legacyUnlinkedEvents > 0)
              Text('${m.legacyUnlinkedEvents} 筆舊回顧／貼文事件沒有關聯資料，未納入 7 天比率。'),
          ],
          const SizedBox(height: 20),
          Text('服務成本與人工時間', style: Theme.of(context).textTheme.titleLarge),
          const Text('以下為管理者依帳務與營運紀錄登錄的最近 90 天資料，不是即時帳單。未登錄日期不當成零成本。'),
          if (costs.recordedDays == 0)
            const Text('尚未登錄成本與用量。')
          else ...[
            Text('已登錄 ${costs.recordedDays} 天'),
            Text(
              '模型 NT\$${costs.modelTwd.toStringAsFixed(2)} · 儲存 NT\$${costs.storageTwd.toStringAsFixed(2)}',
            ),
            Text('請求 ${costs.requests} 次 · 人工管理 ${costs.minutes} 分鐘'),
          ],
          TextButton.icon(
            icon: const Icon(Icons.edit_note),
            label: const Text('登錄每日成本與管理時間'),
            onPressed: c.busy
                ? null
                : () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PilotCostScreen(repository: repository),
                      ),
                    );
                    if (context.mounted) await c.load();
                  },
          ),
        ],
      );
    },
  );
}
