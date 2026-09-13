// lib/features/chat/presentation/pet_communication_input_screen.dart
// ============================================================
// PAWLINK - 寵物溝通輸入頁
// ============================================================

import 'dart:async';
import '../domain/communication_photo.dart';
import '../domain/communication_photo_repository.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final _questionControllers = List.generate(5, (_) => TextEditingController());
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
    for (final controller in _questionControllers) {
      controller.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
            backgroundColor: Colors.redAccent,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '與 ${widget.pet.name} 溝通',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyles.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModeBanner(),
                const SizedBox(height: 24),
                _buildSectionTitle('分享毛孩的故事', '盡可能詳細地描述近期發生的事'),
                _buildStoryInput(),
                const SizedBox(height: 32),
                _buildSectionTitle('想問毛孩的問題', '最多可以提問 5 個問題'),
                ...List.generate(5, (index) => _buildQuestionInput(index)),
                const SizedBox(height: 32),
                _buildPhotoInput(),
                const SizedBox(height: 40),
                _buildSubmitButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildModeBanner() {
    final isSafe = _useSafeMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSafe
            ? AppColors.secondary.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSafe
              ? AppColors.secondary.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSafe ? Icons.shield_outlined : Icons.auto_awesome,
                color: isSafe ? AppColors.secondary : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isSafe ? ChatUiTexts.safeModeTitle : '深度分析模式已準備',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: isSafe ? AppColors.secondary : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isSafe
                ? ChatUiTexts.safeModeSubtitle
                : '當前資訊充足，AI 將結合毛孩檔案進行多維度的深度分析。',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('毛孩照片（選填）', 'Plus／Pro 多模態視覺感知'),
        const Text('最多 3 張，每張上限 10 MB。支援 JPG、PNG。'),
        const SizedBox(height: 8),
        Text(
          _canUsePhotos
              ? '照片與故事會作為 AI 回答提問的參考素材。照片會傳送供 AI 分析。'
              : '升級 Plus／Pro 即可加入照片分析。',
        ),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _photos.length; i++)
              SizedBox(
                width: 96,
                child: Column(
                  children: [
                    Image.memory(
                      _photos[i].bytes,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      cacheWidth: 192,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 96,
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading || _pickingPhotos
                          ? null
                          : () => setState(() => _flow.removePhoto(i)),
                      child: Text('移除照片 ${i + 1}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
        OutlinedButton.icon(
          onPressed:
              _canUsePhotos &&
                  !_isLoading &&
                  !_pickingPhotos &&
                  _photos.length < 3
              ? _pickPhotos
              : null,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_pickingPhotos ? '讀取照片中…' : '加入照片（${_photos.length}/3）'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _storyController,
            maxLines: null,
            minLines: 6,
            style: GoogleFonts.outfit(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '描述毛孩最近的表現、食慾、心情或特別的事...',
              hintStyle: GoogleFonts.outfit(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$_wordCount 字',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDeepAnalysis
                        ? '已達 300 字，將啟用深度分析模式。'
                        : '(滿 300 字開啟深度分析模式)',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: _isDeepAnalysis
                          ? Colors.green
                          : AppColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: _isDeepAnalysis
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput(int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _questionControllers[index],
        style: GoogleFonts.outfit(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: index == 0 ? '問題 1 (必填)' : '問題 ${index + 1} (選填)',
          hintStyle: GoogleFonts.outfit(
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.help_outline,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        ),
        child: Text(
          '發送溝通請求',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                '連結感應中...',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在與 ${widget.pet.name} 建立跨時空連結',
                style: GoogleFonts.outfit(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
