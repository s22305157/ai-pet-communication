import 'journal_text_fields.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../application/journal_editor_controller.dart';
import '../domain/journal_drafts.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';
import 'journal_image.dart';

class JournalEditor extends StatefulWidget {
  final JournalRepository repository;
  final JournalDrafts drafts;
  final String petId;
  final JournalEntry? entry;
  const JournalEditor({
    super.key,
    required this.repository,
    required this.drafts,
    required this.petId,
    this.entry,
  });
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  final _observation = TextEditingController();
  final _action = TextEditingController();
  final _outcome = TextEditingController();
  late final JournalEditorController _editor;
  @override
  void initState() {
    super.initState();
    _editor = JournalEditorController(
      repository: widget.repository,
      drafts: widget.drafts,
      petId: widget.petId,
      original: widget.entry,
    );
    _editor.addListener(_refresh);
    unawaited(_restore());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _restore() async {
    await _editor.restore();
    if (!mounted || !_editor.current) return;
    _observation.text = _editor.observation;
    _action.text = _editor.action;
    _outcome.text = _editor.outcome;
  }

  void _changed() => _editor.changed(
    observation: _observation.text,
    action: _action.text,
    outcome: _outcome.text,
  );
  Future<void> _photo() => _editor.addPhoto(() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    if (await picked.length() > 10 * 1024 * 1024) {
      throw StateError('照片不得超過 10 MiB');
    }
    return picked.readAsBytes();
  });
  Future<void> _save() async {
    if (await _editor.save() && mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _editor.removeListener(_refresh);
    _editor.dispose();
    _observation.dispose();
    _action.dispose();
    _outcome.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _editor.occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_editor.occurredAt),
    );
    if (time == null || !mounted) return;
    final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (date.isAfter(DateTime.now())) {
      setState(() => _editor.error = '日期不可晚於目前時間');
      return;
    }
    _editor.occurredAt = date;
    _changed();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_editor.busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? '記下今天的小事' : '編輯日記')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed:
                _editor.busy ||
                    _editor.loading ||
                    _editor.conflict ||
                    !widget.repository.isCurrentSession
                ? null
                : _save,
            child: Text(_editor.busy ? '處理中…' : '儲存到私人日記'),
          ),
        ),
      ),
      body: _editor.loading
          ? const Center(child: CircularProgressIndicator())
          : !widget.repository.isCurrentSession
          ? const Center(child: Text('帳號已變更，請返回首頁'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('只有你能閱讀這則日記。照片需連線上傳；不會自動發布。'),
                    const Text('登出會清除這個帳號的裝置草稿，請先儲存需要保留的日記。'),
                    if (kIsWeb)
                      const Text('共用電腦請避免保留私人草稿。同網站程式仍可能讀取解密後內容，離開時請登出。'),
                    const SizedBox(height: 12),
                    Text(
                      _editor.status,
                      style: TextStyle(
                        color: _editor.dirty ? Colors.orange.shade900 : null,
                      ),
                    ),
                    if (_editor.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _editor.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_editor.conflict)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '這份草稿與雲端版本不同。請返回時間軸閱讀新版本；草稿不會自動覆蓋它。可在右下方捨棄本機草稿後重新編輯。',
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _editor.busy ? null : _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        DateFormat(
                          'yyyy/MM/dd HH:mm',
                        ).format(_editor.occurredAt),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _editor.context,
                      decoration: const InputDecoration(labelText: '情境'),
                      items: journalContexts
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _editor.busy
                          ? null
                          : (value) {
                              _editor.context = value!;
                              _changed();
                            },
                    ),
                    const SizedBox(height: 12),
                    JournalTextFields(
                      observation: _observation,
                      action: _action,
                      outcome: _outcome,
                      enabled: !_editor.busy,
                      onChanged: _changed,
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _editor.mediaIds
                          .map(
                            (id) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                JournalImage(
                                  key: ValueKey(id),
                                  repository: widget.repository,
                                  mediaId: id,
                                ),
                                TextButton(
                                  onPressed: _editor.busy
                                      ? null
                                      : () {
                                          _editor.removePhoto(id);
                                        },
                                  child: const Text('移除'),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                    OutlinedButton.icon(
                      onPressed: _editor.busy || _editor.mediaIds.length >= 3
                          ? null
                          : _photo,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('加入照片（${_editor.mediaIds.length}/3）'),
                    ),
                    const Text('JPEG／PNG，每張最多 10 MiB。未存入日記的照片會在 24 小時後清除。'),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _editor.busy
                          ? null
                          : () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('捨棄本機草稿？'),
                                  content: const Text('雲端日記不會被刪除。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('保留'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('捨棄'),
                                    ),
                                  ],
                                ),
                              );
                              if (remove != true) return;
                              await _editor.discard();
                              if (context.mounted) {
                                Navigator.pop(context, false);
                              }
                            },
                      child: const Text('捨棄本機草稿'),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
