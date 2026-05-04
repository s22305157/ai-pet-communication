// lib/features/chat/presentation/pet_communication_input_screen.dart
// ============================================================
// PAWLINK - 寵物溝通輸入頁
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants.dart';
import '../../../models/pet_model.dart';
import '../application/prompt_manager.dart';
import '../application/chat_controller.dart';
import '../domain/ai_request_model.dart';
import '../data/chat_service.dart';
import '../../readings/application/reading_service.dart';
import '../../readings/data/firestore_readings_repository.dart';
import 'chat_ui_texts.dart';
import 'communication_result_screen.dart';

class PetCommunicationInputScreen extends StatefulWidget {
  final PetModel pet;

  const PetCommunicationInputScreen({super.key, required this.pet});

  @override
  State<PetCommunicationInputScreen> createState() => _PetCommunicationInputScreenState();
}

class _PetCommunicationInputScreenState extends State<PetCommunicationInputScreen> {
  final TextEditingController _storyController = TextEditingController();
  final List<TextEditingController> _questionControllers = 
      List.generate(5, (_) => TextEditingController());
  
  bool _isLoading = false;
  bool _hasRedFlags = false;
  int _wordCount = 0;

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
    final questionsText = _questionControllers.map((c) => c.text.trim()).join(' ');
    
    setState(() {
      _wordCount = storyText.length;
      _hasRedFlags = PromptManager.detectRedFlags(storyText) || 
                     PromptManager.detectRedFlags(questionsText);
    });
  }

  bool get _useSafeMode => _wordCount < 300 || _hasRedFlags;

  Future<void> _handleSubmit() async {
    if (_storyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先分享一些關於毛孩的故事吧！')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 準備依賴 (未來應使用 DI)
      final chatService = ChatService();
      final readingsRepo = FirestoreReadingsRepository(FirebaseFirestore.instance);
      final readingService = ReadingService(readingsRepo);
      final controller = ChatController(chatService, readingService);

      // 2. 建立 Request Model
      // 注意：這裡假設 OwnerProfile 已由其他地方提供或有預設值
      // 為了演示，我們使用基本的預設值
      final request = AiRequestModel(
        ownerProfile: const OwnerProfile(
          experienceLevel: "intermediate",
          careStyle: "gentle",
          emotionStyle: "supportive",
          dailyRoutine: "stable",
          mainConcern: "health",
        ),
        petProfile: PetProfile(
          name: widget.pet.name,
          species: widget.pet.species,
          breed: widget.pet.breed,
          age: 3, // 預設值
          coatColor: widget.pet.color,
          personalityTraits: [widget.pet.personality],
        ),
        story: _storyController.text.trim(),
        questions: _questionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        inputMode: "free", // 暫定
      );

      // 3. 發送請求
      final result = await controller.handleCommunication(widget.pet.petId!, request);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CommunicationResultScreen(
              result: result,
              pet: widget.pet,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('溝通失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('與 ${widget.pet.name} 溝通', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
        color: isSafe ? AppColors.secondary.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSafe ? AppColors.secondary.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
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
            isSafe ? ChatUiTexts.safeModeSubtitle : '當前資訊充足，AI 將結合毛孩檔案進行多維度的深度分析。',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
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
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
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
              hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary.withOpacity(0.5)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                    color: _wordCount >= 300 ? Colors.green : AppColors.textSecondary,
                    fontWeight: _wordCount >= 300 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (_wordCount < 300) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(滿 300 字開啟深度模式)',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                  ),
                ],
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
          hintText: '問題 ${index + 1} (選填)',
          hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary.withOpacity(0.5)),
          prefixIcon: Icon(Icons.help_outline, color: AppColors.primary.withOpacity(0.5)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: Text(
          '發送溝通請求',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
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
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
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
