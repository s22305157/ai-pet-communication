import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../journal/domain/journal_entry.dart';

class PilotOnboarding extends StatefulWidget {
  final bool activated;
  final List<String> existingNames;
  final Future<void> Function(
    String name,
    String focus,
    DateTime? arrivedAt,
    bool metricsConsent,
  )
  onSubmit;
  const PilotOnboarding({
    super.key,
    required this.activated,
    required this.existingNames,
    required this.onSubmit,
  });
  @override
  State<PilotOnboarding> createState() => _PilotOnboardingState();
}

class _PilotOnboardingState extends State<PilotOnboarding> {
  final _name = TextEditingController();
  String _focus = journalFocuses.first;
  DateTime? _arrivedAt;
  bool _consent = false;
  bool _metrics = false;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('留下你們熟悉彼此的過程', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
        '這一版先提供私人日記。日記只供本人閱讀；不會自動分享到社群，也不會將日記送入 AI。回顧與同伴圈尚未開放。\n\n免費提供一份日記毛孩資料、300 則日記與 200 MiB 圖片空間。這與原有完整毛孩檔案、溝通紀錄的付費同步分開。',
      ),
      const SizedBox(height: 12),
      if (widget.existingNames.isNotEmpty)
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '從現有毛孩帶入名字（選填）'),
          items: widget.existingNames
              .toSet()
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: _busy
              ? null
              : (value) => setState(() => _name.text = value ?? ''),
        ),
      TextField(
        controller: _name,
        maxLength: 80,
        enabled: !_busy,
        decoration: const InputDecoration(labelText: '貓咪的名字'),
      ),
      const Text('帶入只會複製名字；建立獨立的日記資料，不會上傳原有私人檔案或對話。'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _focus,
        decoration: const InputDecoration(labelText: '現在最關注的事'),
        items: journalFocuses
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: _busy ? null : (value) => setState(() => _focus = value!),
      ),
      TextButton.icon(
        icon: const Icon(Icons.event),
        label: Text(
          _arrivedAt == null
              ? '到家日期（選填）'
              : DateFormat('yyyy/MM/dd').format(_arrivedAt!),
        ),
        onPressed: _busy
            ? null
            : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _arrivedAt ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null && mounted) setState(() => _arrivedAt = date);
              },
      ),
      if (!widget.activated) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: _busy ? null : (v) => setState(() => _consent = v!),
          title: const Text('我已閱讀並同意日記試營運說明'),
          subtitle: const Text('資料儲存於雲端；可自行閱讀、匯出與刪除。本站不提供寵物心念讀取或醫療診斷。'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _metrics,
          onChanged: _busy ? null : (v) => setState(() => _metrics = v!),
          title: const Text('同意匿名彙總使用成效（選填）'),
          subtitle: const Text('個人事件會保留最多 90 天，僅記錄操作時間與類型，不包含日記正文或照片。拒絕不影響使用。'),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy || (!widget.activated && !_consent)
            ? null
            : () async {
                if (_name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('請填寫貓咪名字')));
                  return;
                }
                setState(() => _busy = true);
                try {
                  await widget.onSubmit(
                    _name.text.trim(),
                    _focus,
                    _arrivedAt,
                    _metrics,
                  );
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Text(_busy ? '建立中…' : '開始我的私人日記'),
      ),
    ],
  );
}
