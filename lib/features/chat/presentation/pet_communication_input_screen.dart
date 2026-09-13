// lib/features/chat/presentation/pet_communication_input_screen.dart
// ============================================================
// PAWLINK - 寵物溝通輸入頁
// ============================================================

import 'dart:async';
import '../domain/communication_photo.dart';
import '../domain/communication_photo_repository.dart';

import 'package:flutter/material.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/features/chat/application/safety_router.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/presentation/chat_ui_texts.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/services/credit_service.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';

import '../application/communication_input_controller.dart';

class PetCommunicationInputScreen extends StatefulWidget {
  final PetModel pet;
  final String? creditReservationId;
  final CommunicationPhotoRepository? photoService;
  final CommunicationInputController? controller;

  const PetCommunicationInputScreen({
    super.key,
    required this.pet,
    this.creditReservationId,
    this.photoService,
    this.controller,
  });

  @override
  State<PetCommunicationInputScreen> createState() =>
      _PetCommunicationInputScreenState();
}

class _PetCommunicationInputScreenState
    extends State<PetCommunicationInputScreen> {
  final _storyController = TextEditingController();
  final _questionFields = [_QuestionField(0)];
  Iterable<TextEditingController> get _questionControllers =>
      _questionFields.map((field) => field.controller);
  final _storyFocus = FocusNode();
  final _storyKey = GlobalKey();
  int _nextQuestionId = 1;
  bool _showValidation = false;
  late final CommunicationInputController _flow;
  bool _isLoading = false;
  bool _hasRedFlags = false;
  int _wordCount = 0;
  List<CommunicationPhoto> get _photos => _flow.selected;
  bool get _canUsePhotos => _flow.canUsePhotos;
  bool get _pickingPhotos => _flow.picking;

  @override
  void initState() {
    super.initState();
    _flow =
        widget.controller ??
        CommunicationInputController(
          session: getIt<AuthService>(),
          chat: getIt<ChatController>(),
          photos: widget.photoService ?? getIt<CommunicationPhotoRepository>(),
          releaseCredit: (id) =>
              getIt<CreditService>().releaseCommunication(id),
          reservationId: widget.creditReservationId,
        );
    _flow.addListener(_refresh);
    unawaited(_flow.loadPhotoAccess());
    _storyController.addListener(_onTextChanged);
    for (final controller in _questionControllers) {
      controller.addListener(_onTextChanged);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickPhotos() async {
    if (_isLoading) return;
    try {
      await _flow.pickPhotos();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException ? error.message : '無法讀取照片，請重新選擇',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    unawaited(
      _flow.releaseReservation().catchError((Object error) {
        debugPrint('Credit release on screen close failed: $error');
      }),
    );
    _flow.removeListener(_refresh);
    _flow.dispose();
    _storyController.dispose();
    _storyFocus.dispose();
    for (final field in _questionFields) {
      field.dispose();
    }
    super.dispose();
  }

  List<String> get _questions => _questionControllers
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  void _onTextChanged() {
    setState(() {
      _wordCount = _storyController.text.trim().length;
      _hasRedFlags = SafetyRouter.containsEmergency(
        [_storyController.text, ..._questions].join(' '),
        species: widget.pet.species,
      );
    });
  }

  bool get _useSafeMode =>
      _hasRedFlags ||
      SafetyRouter.evaluateText(
        story: _storyController.text.trim(),
        questions: _questions,
        species: widget.pet.species,
      ).useSafeMode;
  bool get _isDeepAnalysis => _wordCount >= SafetyRouter.deepAnalysisThreshold;

  Future<void> _handleSubmit() async {
    if (_isLoading || _pickingPhotos) return;
    final message = _storyController.text.trim().isEmpty
        ? '請先分享一些關於毛孩的故事吧！'
        : _questions.isEmpty
        ? '請至少輸入一個想詢問的問題。'
        : null;
    if (message != null) {
      setState(() => _showValidation = true);
      final storyMissing = _storyController.text.trim().isEmpty;
      _revealField(
        storyMissing ? _storyKey : _questionFields.first.anchor,
        storyMissing ? _storyFocus : _questionFields.first.focus,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final outcome = await _flow.submit(
        pet: widget.pet,
        story: _storyController.text,
        questions: _questions,
      );
      if (outcome == null || !mounted) return;
      await _showPersistenceWarning(outcome);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CommunicationResultScreen(
              result: outcome.response,
              pet: widget.pet,
            ),
          ),
        );
      }
    } catch (e) {
      Object? releaseError;
      try {
        await _flow.releaseReservation();
      } catch (error) {
        releaseError = error;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.creditReservationId == null
                  ? '溝通暫時無法完成，請稍後再試。'
                  : releaseError == null
                  ? '溝通失敗，既有預留點數已退回: $e'
                  : '溝通失敗，點數退回待重試，請稍後查看餘額: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        if (widget.creditReservationId != null) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPersistenceWarning(CommunicationOutcome outcome) async {
    if (!mounted || outcome.persistenceFailure == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('紀錄尚未儲存'),
        content: const Text('AI 回應已完成，但溝通紀錄儲存失敗。您可以立即重試，或先查看結果。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('先查看結果'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _flow.retryPersistence(outcome);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('溝通紀錄已儲存')));
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('仍無法儲存，請稍後再試: $error')),
                  );
                }
              }
            },
            child: const Text('重試儲存'),
          ),
        ],
      ),
    );
  }

  void _revealField(GlobalKey anchor, FocusNode focus) {
    focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || anchor.currentContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          anchor.currentContext!,
          duration: const Duration(milliseconds: 200),
          alignment: 0.15,
        ),
      );
    });
  }

  void _addQuestion() {
    if (_isLoading || _pickingPhotos || _questionFields.length >= 5) return;
    final field = _QuestionField(_nextQuestionId++);
    field.controller.addListener(_onTextChanged);
    setState(() => _questionFields.add(field));
    _revealField(field.anchor, field.focus);
  }

  Future<void> _removeQuestion(_QuestionField field) async {
    if (_isLoading || _pickingPhotos || _questionFields.length == 1) return;
    if (field.controller.text.trim().isNotEmpty) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('刪除這個問題？'),
          content: const Text('這個問題的文字會被移除，其他問題會保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留問題'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('刪除問題'),
            ),
          ],
        ),
      );
      if (remove != true || !mounted || _isLoading || _pickingPhotos) return;
    }
    field.focus.unfocus();
    field.controller.removeListener(_onTextChanged);
    setState(() => _questionFields.remove(field));
    _onTextChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) => field.dispose());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(
        '與 ${widget.pet.name} 溝通',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      top: false,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: AppContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildModeBanner(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('分享毛孩的故事', '描述近期發生的事，讓回覆更貼近你們'),
                        _buildStoryInput(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('想問毛孩的問題', '至少填寫一題，最多五題'),
                        for (
                          var index = 0;
                          index < _questionFields.length;
                          index++
                        )
                          _buildQuestionInput(_questionFields[index], index),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('add-question'),
                            onPressed:
                                _isLoading ||
                                    _pickingPhotos ||
                                    _questionFields.length >= 5
                                ? null
                                : _addQuestion,
                            icon: const Icon(Icons.add),
                            label: Text('新增問題（${_questionFields.length}/5）'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPhotoInput(),
                      ],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.outline)),
                ),
                child: AppContent(
                  verticalPadding: 12,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('submit-communication'),
                      onPressed: _isLoading || _pickingPhotos
                          ? null
                          : _handleSubmit,
                      style: AppStyles.primaryButton,
                      child: const Text('發送溝通請求', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.black54),
            ),
            Center(
              child: SingleChildScrollView(
                child: AppContent(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            liveRegion: true,
                            child: const Text(
                              '正在整理回覆…',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '正在整理你與 ${widget.pet.name} 的故事與問題',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildModeBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _useSafeMode ? AppColors.surfaceMint : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _useSafeMode ? Icons.shield_outlined : Icons.auto_awesome,
              color: AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _useSafeMode ? ChatUiTexts.safeModeTitle : '深度分析模式已準備',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _useSafeMode ? ChatUiTexts.safeModeSubtitle : '資訊已充足，AI 將結合毛孩檔案整理回覆。',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _buildPhotoInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionTitle('毛孩照片（選填）', 'Plus／Pro 可加入照片作為回答參考'),
      const Text(
        '最多 3 張，每張上限 10 MB。支援 JPG、PNG。',
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 8),
      Text(
        _canUsePhotos
            ? '照片與故事會作為 AI 回答提問的參考素材。照片會傳送供 AI 分析。'
            : '升級 Plus／Pro 即可加入照片分析。',
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _photos.length; i++)
            SizedBox(
              width: 104,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photos[i].bytes,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      cacheWidth: 208,
                      semanticLabel: '照片 ${i + 1} 預覽',
                      errorBuilder: (_, error, stack) => const SizedBox(
                        height: 104,
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading || _pickingPhotos
                        ? null
                        : () => setState(() => _flow.removePhoto(i)),
                    child: Text('移除照片 ${i + 1}', textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
        ],
      ),
      OutlinedButton.icon(
        key: const Key('add-photos'),
        onPressed:
            _canUsePhotos &&
                !_isLoading &&
                !_pickingPhotos &&
                _photos.length < 3
            ? _pickPhotos
            : null,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          _pickingPhotos ? '讀取照片中…' : '加入照片（${_photos.length}/3）',
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );

  Widget _buildSectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  InputDecoration _decoration(
    String label, {
    String? hint,
    String? error,
  }) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    alignLabelWithHint: true,
    hintText: hint,
    errorText: error,
    errorMaxLines: 3,
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 14),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.textSecondary),
    ),
    contentPadding: const EdgeInsets.all(16),
  );

  Widget _buildStoryInput() => Column(
    key: _storyKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('communication-story'),
        controller: _storyController,
        focusNode: _storyFocus,
        enabled: !_isLoading,
        minLines: 4,
        maxLines: null,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        decoration: _decoration(
          '毛孩的故事（必填）',
          hint: '描述毛孩最近的表現、食慾、心情或特別的事…',
          error: _showValidation && _storyController.text.trim().isEmpty
              ? '請先分享一些關於毛孩的故事。'
              : null,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$_wordCount 字 · ${_isDeepAnalysis ? '已達 300 字，將啟用深度分析模式。' : '滿 300 字開啟深度分析模式'}',
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );

  Widget _buildQuestionInput(_QuestionField field, int index) => Padding(
    key: field.anchor,
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('question-${field.id}'),
          controller: field.controller,
          focusNode: field.focus,
          enabled: !_isLoading,
          minLines: 1,
          maxLines: null,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textPrimary,
          ),
          decoration: _decoration(
            '問題 ${index + 1}',
            error: _showValidation && index == 0 && _questions.isEmpty
                ? '請至少輸入一個想詢問的問題。'
                : null,
          ),
        ),
        if (_questionFields.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('remove-question-${field.id}'),
              onPressed: _isLoading || _pickingPhotos
                  ? null
                  : () => _removeQuestion(field),
              icon: const Icon(Icons.delete_outline),
              label: Text('移除問題 ${index + 1}'),
            ),
          ),
      ],
    ),
  );
}

class _QuestionField {
  final int id;
  final controller = TextEditingController();
  final focus = FocusNode();
  final anchor = GlobalKey();
  _QuestionField(this.id);
  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
