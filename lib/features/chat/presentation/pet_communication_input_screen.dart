// lib/features/chat/presentation/pet_communication_input_screen.dart
// ============================================================
// PAWLINK - 寵物溝通輸入頁
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/features/chat/application/prompt_manager.dart';
import 'package:ai_pet_communication/features/chat/application/safety_router.dart';
import 'package:ai_pet_communication/features/chat/application/chat_controller.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_request_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/chat_ui_texts.dart';
import 'package:ai_pet_communication/features/chat/presentation/communication_result_screen.dart';
import 'package:ai_pet_communication/services/credit_service.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';

class PetCommunicationInputScreen extends StatefulWidget {
  final PetModel pet;
  final String? creditReservationId;

  const PetCommunicationInputScreen({
    super.key,
    required this.pet,
    this.creditReservationId,
  });

  @override
  State<PetCommunicationInputScreen> createState() =>
      _PetCommunicationInputScreenState();
}

class _PetCommunicationInputScreenState
    extends State<PetCommunicationInputScreen> {
  final TextEditingController _storyController = TextEditingController();
  final List<TextEditingController> _questionControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  bool _isLoading = false;
  bool _hasRedFlags = false;
  int _wordCount = 0;
  bool _creditFinalized = false;
  Future<void>? _releaseFuture;

  @override
  void initState() {
    super.initState();
    _storyController.addListener(_onTextChanged);
    for (var controller in _questionControllers) {
      controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    if (!_creditFinalized && widget.creditReservationId != null) {
      unawaited(
        _releaseReservation().catchError((Object error) {
          debugPrint('Credit release on screen close failed: $error');
        }),
      );
    }
    _storyController.removeListener(_onTextChanged);
    _storyController.dispose();
    for (var controller in _questionControllers) {
      controller.removeListener(_onTextChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final storyText = _storyController.text.trim();
    final questionsText = _questionControllers
        .map((c) => c.text.trim())
        .join(' ');

    setState(() {
      _wordCount = storyText.length;
      _hasRedFlags =
          PromptManager.detectRedFlags(
            storyText,
            species: widget.pet.species,
          ) ||
          PromptManager.detectRedFlags(
            questionsText,
            species: widget.pet.species,
          );
    });
  }

  bool get _useSafeMode =>
      _hasRedFlags ||
      PromptManager.shouldUseSafeMode(
        story: _storyController.text.trim(),
        questions: _questionControllers
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
        species: widget.pet.species,
      );

  bool get _isDeepAnalysis => _wordCount >= SafetyRouter.deepAnalysisThreshold;

  CreditService get _creditService => getIt<CreditService>();

  Future<void> _releaseReservation() {
    final requestId = widget.creditReservationId;
    if (requestId == null || _creditFinalized) return Future<void>.value();
    return _releaseFuture ??= _performRelease(requestId);
  }

  Future<void> _performRelease(String requestId) async {
    try {
      await _creditService.releaseCommunication(requestId);
      _creditFinalized = true;
    } finally {
      if (!_creditFinalized) _releaseFuture = null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (_storyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先分享一些關於毛孩的故事吧！')));
      return;
    }
    final questions = _questionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請至少輸入一個想詢問的問題。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 準備依賴 (使用 DI)
      final controller = getIt<ChatController>();

      final user = await getIt<AuthService>().getUserData();
      if (user == null) throw StateError('請先登入');
      final birthday = DateTime.tryParse(widget.pet.birthday);
      final age = birthday == null || birthday.isAfter(DateTime.now())
          ? null
          : DateTime.now().difference(birthday).inDays / 365.25;
      // 尚未提供的飼主資訊保留空值，不編造人格或生活習慣。
      final request = AiRequestModel(
        ownerProfile: const OwnerProfile(
          experienceLevel: '',
          careStyle: '',
          emotionStyle: '',
          dailyRoutine: '',
          mainConcern: '',
        ),
        petProfile: PetProfile(
          name: widget.pet.name,
          species: widget.pet.species,
          breed: widget.pet.breed,
          age: age,
          coatColor: widget.pet.color,
          personalityTraits: [widget.pet.personality],
        ),
        story: _storyController.text.trim(),
        questions: questions,
        inputMode: user.membershipTier,
      );

      // 3. 發送請求
      final outcome = await controller.handleCommunicationWithPersistence(
        widget.pet.petId,
        request,
        requestId: widget.creditReservationId,
      );

      if (outcome.isFallback) {
        throw StateError('AI 目前無法完成回覆，請稍後再試');
      }

      // 本階段不計費；後端已保存回覆以供重試去重。
      _creditFinalized = true;
      await _showPersistenceWarning(controller, outcome);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CommunicationResultScreen(
              result: outcome.response,
              pet: widget.pet,
            ),
          ),
        );
      }
    } catch (e) {
      Object? releaseError;
      try {
        await _releaseReservation();
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
        // 預留已結束；重新開始時必須取得新的 request ID。
        if (widget.creditReservationId != null) {
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPersistenceWarning(
    ChatController controller,
    CommunicationOutcome outcome,
  ) async {
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
                await controller.retryPersistence(outcome);
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
