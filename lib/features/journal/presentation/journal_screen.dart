import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_pet_communication/app/injection.dart';
import '../application/journal_controller.dart';
import '../domain/journal_drafts.dart';
import 'journal_download.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';
import 'pilot_onboarding.dart';
import 'journal_editor.dart';
import 'journal_entry_card.dart';
import '../../pilot/domain/pilot_repository.dart';
import '../../../app/pilot_routes.dart';

class JournalScreen extends StatefulWidget {
  final JournalRepository? repository;
  final JournalDrafts? drafts;
  const JournalScreen({super.key, this.repository, this.drafts});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final JournalRepository _repository =
      widget.repository ?? getIt<JournalRepository>();
  late final JournalDrafts _drafts = widget.drafts ?? getIt<JournalDrafts>();
  late final JournalController _controller = JournalController(_repository);
  bool _operating = false;
  Future<void> _openPilot(
    Future<void> Function(PilotRoutes, PilotRepository) navigate,
  ) async {
    if (!_repository.isCurrentSession ||
        !getIt.isRegistered<PilotRepository>() ||
        !getIt.isRegistered<PilotRoutes>()) {
      return;
    }
    final pilot = getIt<PilotRepository>();
    if (pilot.uid != _repository.uid || !pilot.isCurrentSession) return;
    await navigate(getIt<PilotRoutes>(), pilot);
  }

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _operation(Future<void> Function() action) async {
    setState(() => _operating = true);
    try {
      await action();
      if (mounted) await _controller.load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(journalError(error))));
      }
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  Future<void> _edit([JournalEntry? entry]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEditor(
          repository: _repository,
          drafts: _drafts,
          petId: _controller.pet!.id,
          entry: entry,
        ),
      ),
    );
    if (mounted) await _controller.load();
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final c = _controller;
      return Scaffold(
        appBar: AppBar(
          title: const Text('毛孩日記'),
          actions: [
            if (c.access?.isAdmin == true)
              IconButton(
                tooltip: '試營運管理',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () =>
                    _openPilot((routes, pilot) => routes.admin(context, pilot)),
              ),
            if (c.access?.activated == true &&
                getIt.isRegistered<PilotRepository>())
              IconButton(
                tooltip: '站內通知',
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _openPilot(
                  (routes, pilot) => routes.notifications(context, pilot),
                ),
              ),
            IconButton(
              onPressed: c.busy || _operating ? null : () => c.load(),
              tooltip: '重新整理',
              icon: const Icon(Icons.refresh),
            ),
            if (c.pet != null)
              PopupMenuButton<String>(
                enabled: !_operating && !c.busy,
                onSelected: (value) async {
                  if (value == 'export') {
                    await _operation(() async {
                      final data = await _repository.exportJournal(c.pet!.id);
                      if (!_repository.isCurrentSession) return;
                      await downloadJournalFile(
                        Uint8List.fromList(
                          utf8.encode(
                            const JsonEncoder.withIndent('  ').convert(data),
                          ),
                        ),
                        'pawlink-journal.json',
                        'application/json',
                      );
                    });
                  } else if (value == 'deletePet') {
                    if (await _confirm(
                      '刪除這份日記毛孩資料？',
                      '這份日記的全部文字與照片將刪除。原有毛孩檔案與溝通紀錄不受影響。',
                    )) {
                      await _operation(() async {
                        await _repository.deletePet(c.pet!.id);
                        await _drafts.clearUser(_repository.uid);
                      });
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'export', child: Text('匯出文字與照片索引 JSON')),
                  PopupMenuItem(value: 'deletePet', child: Text('刪除日記毛孩資料')),
                ],
              ),
          ],
        ),
        body: !_repository.isCurrentSession
            ? const Center(child: Text('帳號已變更，請返回首頁'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: RefreshIndicator(
                    onRefresh: () => c.load(),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (c.busy || _operating)
                          const LinearProgressIndicator(),
                        if (c.error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              c.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        if (!c.busy && c.access != null && c.pet == null) ...[
                          if (c.access?.enabled != true ||
                              c.access?.invited != true)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text('毛孩日記目前採邀請試營運。\n這個帳號尚未開放或資格已到期。'),
                            )
                          else
                            PilotOnboarding(
                              activated: c.access?.activated == true,
                              existingPets:
                                  getIt.isRegistered<JournalPetBasics>()
                                  ? getIt<JournalPetBasics>()(_repository.uid)
                                  : [],
                              onSubmit:
                                  (name, species, focus, arrivedAt, metrics) =>
                                      _operation(() async {
                                        if (c.access?.activated != true) {
                                          await _repository.activatePilot(
                                            metricsConsent: metrics,
                                          );
                                        }
                                        await _repository.createPet(
                                          JournalPetInput(
                                            name: name,
                                            species: species,
                                            focus: focus,
                                            arrivedAt: arrivedAt,
                                          ),
                                        );
                                      }),
                            ),
                        ],
                        if (c.pet != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${c.pet!.name} 的相處日記',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '本週記錄 ${c.weekDays} 天 · ${c.pet!.entryCount}/300 則\n圖片 ${(c.pet!.usedBytes / 1048576).toStringAsFixed(1)} / 200 MiB',
                          ),
                          const Text('私人雲端日記 · 照片可點選放大與下載'),
                          if (c.access?.activated == true &&
                              getIt.isRegistered<PilotRepository>())
                            Wrap(
                              spacing: 12,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.auto_stories_outlined),
                                  label: Text(
                                    c.latestReviewWeek == null
                                        ? '每週回顧'
                                        : '最新回顧 · ${c.latestReviewWeek}',
                                  ),
                                  onPressed: () => _openPilot(
                                    (routes, pilot) => routes.review(
                                      context,
                                      pilot,
                                      c.pet!.id,
                                      week: c.latestReviewWeek,
                                    ),
                                  ),
                                ),
                                if (c.access?.communityEnabled == true &&
                                    c.access?.invited == true)
                                  TextButton.icon(
                                    icon: const Icon(Icons.people_outline),
                                    label: const Text('同伴圈'),
                                    onPressed: () => _openPilot(
                                      (routes, pilot) =>
                                          routes.community(context, pilot),
                                    ),
                                  ),
                              ],
                            ),
                          if (!c.canWrite)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('目前暫停新增與編輯。仍可閱讀、匯出與刪除已有資料。'),
                            ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: c.canWrite && !_operating && !c.busy
                                ? () => _edit()
                                : null,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('記下一件小事'),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: c.contextFilter ?? '',
                            decoration: const InputDecoration(
                              labelText: '依情境查看',
                            ),
                            items: ['', ...journalContexts]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v.isEmpty ? '所有情境' : v),
                                  ),
                                )
                                .toList(),
                            onChanged: c.busy
                                ? null
                                : (v) {
                                    c.contextFilter = v == '' ? null : v;
                                    c.load();
                                  },
                          ),
                          Wrap(
                            spacing: 10,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  c.from == null
                                      ? '選擇日期範圍'
                                      : '${DateFormat('MM/dd').format(c.from!)}–${DateFormat('MM/dd').format(c.to!)}',
                                ),
                                onPressed: c.busy
                                    ? null
                                    : () async {
                                        final range = await showDateRangePicker(
                                          context: context,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime.now(),
                                        );
                                        if (range != null && mounted) {
                                          c.from = range.start;
                                          c.to = range.end
                                              .add(const Duration(days: 1))
                                              .subtract(
                                                const Duration(milliseconds: 1),
                                              );
                                          c.load();
                                        }
                                      },
                              ),
                              if (c.from != null)
                                TextButton(
                                  onPressed: c.busy
                                      ? null
                                      : () {
                                          c.from = null;
                                          c.to = null;
                                          c.load();
                                        },
                                  child: const Text('清除日期'),
                                ),
                            ],
                          ),
                          if (c.entries.isEmpty && !c.busy)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('這裡還沒有紀錄。今天的一件小事，就能成為開始。'),
                            ),
                          ...c.entries.map(
                            (entry) => JournalEntryCard(
                              entry: entry,
                              repository: _repository,
                              enabled: !c.busy && !_operating,
                              canWrite: c.canWrite,
                              canShare:
                                  c.access?.invited == true &&
                                  c.access?.communityEnabled == true &&
                                  c.access?.communityWriteEnabled == true,
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _edit(entry);
                                } else if (value == 'share') {
                                  await _openPilot(
                                    (routes, pilot) => routes.share(
                                      context,
                                      pilot,
                                      _repository,
                                      c.pet!.id,
                                      entry,
                                    ),
                                  );
                                  await c.load();
                                } else if (await _confirm(
                                  '刪除這則日記？',
                                  '文字與照片將刪除，無法復原。',
                                )) {
                                  await _operation(() async {
                                    await _repository.deleteEntry(
                                      petId: c.pet!.id,
                                      entryId: entry.id,
                                      expectedRevision: entry.revision,
                                    );
                                    await _drafts.remove(
                                      _repository.uid,
                                      c.pet!.id,
                                      entry.id,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                          if (c.cursor != null)
                            OutlinedButton(
                              onPressed: c.busy
                                  ? null
                                  : () => c.load(more: true),
                              child: const Text('載入較早的紀錄'),
                            ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
