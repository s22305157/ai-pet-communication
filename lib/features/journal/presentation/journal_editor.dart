import 'journal_text_fields.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../application/journal_controller.dart';
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
  late String _entryId;
  late int _revision;
  String _operationId = const Uuid().v4();
  String _context = journalContexts.first;
  DateTime _occurredAt = DateTime.now();
  List<String> _mediaIds = [];
  bool _busy = false;
  bool _loading = true;
  bool _dirty = false;
  bool _conflict = false;
  String? _error;
  String _status = '草稿加密保存在裝置，登出會清除；共用裝置請記得登出';
  String get _draftKey => widget.entry?.id ?? 'new';
  @override
  void initState() {
    super.initState();
    _entryId = widget.entry?.id ?? const Uuid().v4();
    _revision = widget.entry?.revision ?? 0;
    _restore();
  }

  Map<String, dynamic> _input() => {
    'petId': widget.petId,
    'entryId': _entryId,
    'operationId': _operationId,
    'expectedRevision': _revision,
    'context': _context,
    'occurredAtMs': _occurredAt.millisecondsSinceEpoch,
    'observation': _observation.text,
    'action': _action.text,
    'outcome': _outcome.text,
    'mediaIds': _mediaIds,
  };

  Future<void> _restore() async {
    try {
      final draft = await widget.drafts.read(
        widget.repository.uid,
        widget.petId,
        _draftKey,
      );
      if (!mounted || !widget.repository.isCurrentSession) return;
      final data = draft ?? widget.entry?.toInput();
      if (data != null) {
        _observation.text = data['observation'] as String? ?? '';
        _action.text = data['action'] as String? ?? '';
        _outcome.text = data['outcome'] as String? ?? '';
        _entryId = data['entryId'] as String? ?? _entryId;
        _revision = data['expectedRevision'] as int? ?? _revision;
        _context = data['context'] as String? ?? journalContexts.first;
        _occurredAt = DateTime.fromMillisecondsSinceEpoch(
          data['occurredAtMs'] as int,
        );
        _mediaIds = List<String>.from(data['mediaIds'] as List? ?? []);
        _operationId = data['operationId'] as String? ?? _operationId;
        _dirty = draft != null;
        _conflict =
            draft != null &&
            widget.entry != null &&
            _revision != widget.entry!.revision;
        if (draft != null) _status = '已還原本機草稿・尚未同步';
      }
    } catch (_) {
      _error = '無法讀取本機草稿';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _persist() async {
    if (!widget.repository.isCurrentSession) return;
    await widget.drafts.save(
      widget.repository.uid,
      widget.petId,
      _draftKey,
      _input(),
    );
  }

  void _changed() {
    _operationId = const Uuid().v4();
    setState(() {
      _dirty = true;
      _status = '尚未同步・正在保留文字草稿';
    });
    unawaited(
      _persist()
          .then((_) {
            if (mounted && widget.repository.isCurrentSession) {
              setState(() => _status = '尚未同步・文字草稿已保留在這個裝置');
            }
          })
          .catchError((Object _) {
            if (mounted) setState(() => _status = '本機空間不足，草稿尚未保存，請勿關閉');
          }),
    );
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (date.isAfter(DateTime.now())) {
      setState(() => _error = '日期不可晚於目前時間');
      return;
    }
    _occurredAt = date;
    _changed();
  }

  Future<void> _photo() async {
    if (_mediaIds.length >= 3) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (await picked.length() > 10 * 1024 * 1024) {
        throw StateError('照片不得超過 10 MiB');
      }
      final bytes = await picked.readAsBytes();
      final png =
          bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpeg) throw StateError('請選擇 JPEG 或 PNG 照片');
      final id = await widget.repository.upload(
        widget.petId,
        bytes,
        png ? 'image/png' : 'image/jpeg',
      );
      if (!mounted || !widget.repository.isCurrentSession) return;
      _mediaIds.add(id);
      _changed();
    } catch (error) {
      if (mounted) setState(() => _error = journalError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_observation.text.trim().isEmpty &&
        _action.text.trim().isEmpty &&
        _outcome.text.trim().isEmpty &&
        _mediaIds.isEmpty) {
      setState(() => _error = '請至少加入文字或一張照片');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _persist();
      await widget.repository.saveEntry(
        JournalEntryInput(
          petId: widget.petId,
          operationId: _operationId,
          entry: JournalEntry(
            id: _entryId,
            occurredAt: _occurredAt,
            context: _context,
            observation: _observation.text,
            action: _action.text,
            outcome: _outcome.text,
            mediaIds: List.of(_mediaIds),
            revision: _revision,
          ),
        ),
      );
      await widget.drafts.remove(
        widget.repository.uid,
        widget.petId,
        _draftKey,
      );
      if (mounted && widget.repository.isCurrentSession) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = journalError(error);
          _conflict = error.toString().contains('aborted');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _observation.dispose();
    _action.dispose();
    _outcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? '記下今天的小事' : '編輯日記')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed:
                _busy ||
                    _loading ||
                    _conflict ||
                    !widget.repository.isCurrentSession
                ? null
                : _save,
            child: Text(_busy ? '處理中…' : '儲存到私人日記'),
          ),
        ),
      ),
      body: _loading
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
                      _status,
                      style: TextStyle(
                        color: _dirty ? Colors.orange.shade900 : null,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_conflict)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '這份草稿與雲端版本不同。請返回時間軸閱讀新版本；草稿不會自動覆蓋它。可在右下方捨棄本機草稿後重新編輯。',
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _busy ? null : _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(_occurredAt),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _context,
                      decoration: const InputDecoration(labelText: '情境'),
                      items: journalContexts
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) {
                              _context = value!;
                              _changed();
                            },
                    ),
                    const SizedBox(height: 12),
                    JournalTextFields(
                      observation: _observation,
                      action: _action,
                      outcome: _outcome,
                      enabled: !_busy,
                      onChanged: _changed,
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _mediaIds
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
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          _mediaIds.remove(id);
                                          _changed();
                                        },
                                  child: const Text('移除'),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || _mediaIds.length >= 3 ? null : _photo,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text('加入照片（${_mediaIds.length}/3）'),
                    ),
                    const Text('JPEG／PNG，每張最多 10 MiB。未存入日記的照片會在 24 小時後清除。'),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _busy
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
                              await widget.drafts.remove(
                                widget.repository.uid,
                                widget.petId,
                                _draftKey,
                              );
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
