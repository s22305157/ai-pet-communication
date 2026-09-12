import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../pilot/domain/pilot_repository.dart';
import '../../pilot/domain/pilot_request.dart';

import 'package:ai_pet_communication/widgets/pilot_surface.dart';
import '../../pilot/application/pilot_controller.dart';
import '../domain/weekly_review.dart';

class WeeklyReviewScreen extends StatefulWidget {
  final PilotRepository repository;
  final String petId;
  final String? initialWeek;
  const WeeklyReviewScreen({
    super.key,
    required this.repository,
    required this.petId,
    this.initialWeek,
  });
  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late String week;
  late List<String> weeks;
  @override
  void initState() {
    super.initState();
    final taipei = DateTime.now().toUtc().add(const Duration(hours: 8));
    final monday = DateTime.utc(
      taipei.year,
      taipei.month,
      taipei.day,
    ).subtract(Duration(days: taipei.weekday - 1));
    weeks = List.generate(
      52,
      (i) => DateFormat(
        'yyyy-MM-dd',
      ).format(monday.subtract(Duration(days: (i + 1) * 7))),
    );
    week = widget.initialWeek ?? weeks.first;
    if (!weeks.contains(week)) weeks.insert(0, week);
  }

  Future<WeeklyReview> _load() async {
    final result = await widget.repository.execute(
      GetWeeklyReview(petId: widget.petId, week: week),
    );
    if (result.status == 'ready') {
      await widget.repository.execute(
        MarkWeeklyReviewViewed(petId: widget.petId, week: week),
        operationId:
            'view_${widget.petId}_${week}_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    return result;
  }

  Future<void> _source(PilotController<WeeklyReview> c, String id) async {
    try {
      final source = await widget.repository.execute(
        GetWeeklyReviewSource(petId: widget.petId, week: week, entryId: id),
      );
      if (!mounted || !c.current) return;
      await showDialog<void>(
        context: context,
        builder: (context) => StreamBuilder<bool>(
          stream: widget.repository.sessionChanges,
          initialData: widget.repository.isCurrentSession,
          builder: (context, session) => AlertDialog(
            title: const Text('主人留下的原始紀錄'),
            content: SingleChildScrollView(
              child: Text(
                session.data != true
                    ? '帳號已變更'
                    : '${source.context}\n${source.observation}\n\n做過的事\n${source.action}\n\n後續結果\n${source.outcome}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        await c.load();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(pilotError(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => PilotSurface<WeeklyReview>(
    title: '每週回顧',
    repository: widget.repository,
    loader: _load,
    builder: (context, c) {
      final review = c.value;
      if (review == null) return const SizedBox.shrink();
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: week,
            decoration: const InputDecoration(labelText: '週別（週一開始）'),
            items: weeks
                .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                .toList(),
            onChanged: c.busy
                ? null
                : (v) {
                    if (v != null) {
                      setState(() => week = v);
                      c.load();
                    }
                  },
          ),
          const SizedBox(height: 16),
          if (c.value != null) ...[
            Text(
              '記錄 ${review.days} 天，共 ${review.entries} 則；文字紀錄 ${review.textDays} 天。',
            ),
            const SizedBox(height: 12),
            Text(review.message),
            if (review.safetyMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(review.safetyMessage),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允許 AI 分析日記文字'),
              subtitle: const Text('照片不送入模型。停用後仍可記日記、參與同伴圈及閱讀有效既有回顧。'),
              value: review.analysisEnabled,
              onChanged: c.busy
                  ? null
                  : (enabled) async {
                      if (enabled &&
                          !await pilotConfirm(
                            context,
                            '啟用 AI 日記分析',
                            '同意將所選週次的日記文字傳送至 OpenAI，整理有來源的回顧。AI 可能出錯，不能診斷或讀取毛孩心念。照片不會傳送。',
                          )) {
                        return;
                      }
                      await c.submit(SetReviewPreference(enabled: enabled));
                    },
            ),
            if (review.trialEndsAtMs > 0)
              Text(
                'AI 試用至 ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(review.trialEndsAtMs))}',
              ),
            const Text('試用為啟用日記後一次性 28 天，不影響原有會員與點數。到期後保留日記與有效既有回顧。'),
            if (review.trialEndsAtMs <= DateTime.now().millisecondsSinceEpoch)
              const Text('進階回顧方案預計 NT\$199／月，尚未開放購買。'),
            const SizedBox(height: 12),
            if (review.result == null)
              FilledButton(
                onPressed:
                    !c.busy &&
                        review.canGenerate &&
                        review.status != 'processing'
                    ? () => c.submit(
                        RequestWeeklyReview(petId: widget.petId, week: week),
                      )
                    : null,
                child: Text('產生／重試回顧（已嘗試 ${review.attempts}/2 次）'),
              ),
            if (review.result != null) ...[
              for (final section in [
                (review.result!.happenings, '這週發生的事'),
                (review.result!.observations, '值得繼續觀察（AI 推測）'),
                (review.result!.tips, '下週的小提示'),
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    section.$2,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final row in section.$1)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(row.text),
                          Wrap(
                            children: [
                              for (final id in row.entryIds)
                                TextButton(
                                  onPressed: c.busy
                                      ? null
                                      : () => _source(c, id),
                                  child: Text(
                                    '原始紀錄 ${id.toString().substring(0, id.toString().length.clamp(0, 6))}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (review.result!.petVoice.isNotEmpty)
                ExpansionTile(
                  title: const Text('毛孩小語 · AI 創作'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(review.result!.petVoice),
                    ),
                  ],
                ),
            ],
          ],
        ],
      );
    },
  );
}
