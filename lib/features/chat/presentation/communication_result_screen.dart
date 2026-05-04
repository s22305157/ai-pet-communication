// lib/features/chat/presentation/communication_result_screen.dart
// ============================================================
// PAWLINK - 寵物溝通結果展示頁
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants.dart';
import '../../../models/pet_model.dart';
import '../domain/ai_response_model.dart';
import '../domain/ai_safe_response_model.dart';
import 'chat_ui_texts.dart';

class CommunicationResultScreen extends StatelessWidget {
  final dynamic result; // AiResponseModel or AiSafeResponseModel
  final PetModel pet;

  const CommunicationResultScreen({
    super.key,
    required this.result,
    required this.pet,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSafe = result is AiSafeResponseModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('溝通結果'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSafe) _buildSafeResult(result as AiSafeResponseModel)
            else _buildStandardResult(result as AiResponseModel),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardResult(AiResponseModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(ChatUiTexts.petVoiceTitle, ChatUiTexts.petVoiceSubtitle, Icons.pets),
        ...model.petVoice.map((v) => _buildMessageCard(v.question, v.answer)),
        const SizedBox(height: 24),
        _buildSectionHeader(ChatUiTexts.knowledgeTipsTitle, ChatUiTexts.knowledgeTipsSubtitle, Icons.lightbulb_outline),
        _buildContentCard(model.knowledgeStation.title, model.knowledgeStation.content),
        const SizedBox(height: 24),
        _buildSectionHeader('總結', '本次溝通的核心要點', Icons.summarize_outlined),
        _buildContentCard('重點摘要', model.summary),
      ],
    );
  }

  Widget _buildSafeResult(AiSafeResponseModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(ChatUiTexts.safeModeTitle, ChatUiTexts.safeModeSubtitle, Icons.shield_outlined, color: AppColors.secondary),
        const SizedBox(height: 16),
        _buildSectionHeader(ChatUiTexts.petVoiceTitle, ChatUiTexts.petVoiceSubtitle, Icons.pets),
        _buildContentCard('感應回饋', model.petVoice.text),
        if (model.safetyAlert.hasRedFlags) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(ChatUiTexts.safetyAlertTitle, ChatUiTexts.safetyAlertSubtitle, Icons.warning_amber_rounded, color: Colors.redAccent),
          _buildContentCard('安全警示', model.safetyAlert.message, isAlert: true),
        ],
        const SizedBox(height: 24),
        _buildSectionHeader(ChatUiTexts.knowledgeTipsTitle, ChatUiTexts.knowledgeTipsSubtitle, Icons.lightbulb_outline),
        ...model.knowledgeTips.map((tip) => _buildBulletItem(tip)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color ?? AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.isNotEmpty) ...[
            Text('提問：$q', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(height: 24),
          ],
          Text(a, style: GoogleFonts.outfit(fontSize: 15, height: 1.6, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildContentCard(String title, String content, {bool isAlert = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAlert ? Colors.redAccent.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAlert ? Border.all(color: Colors.redAccent.withOpacity(0.2)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isAlert ? Colors.redAccent : AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.outfit(fontSize: 15, height: 1.6, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        ChatUiTexts.footerNote,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.6)),
      ),
    );
  }
}
