import '../domain/communication_response.dart';
// lib/features/chat/presentation/communication_result_screen.dart
// ============================================================
// PAWLINK - 寵物溝通結果展示頁
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/app/injection.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/widgets/free_member_ad.dart';
import 'package:ai_pet_communication/features/profile/presentation/points_shop_screen.dart';
import 'package:ai_pet_communication/features/pet/domain/models/pet_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_response_model.dart';
import 'package:ai_pet_communication/features/chat/domain/ai_safe_response_model.dart';
import 'package:ai_pet_communication/features/chat/presentation/chat_ui_texts.dart';
import 'communication_display.dart';
import 'package:ai_pet_communication/features/planet/domain/planet_card.dart';
import 'package:ai_pet_communication/features/planet/presentation/pet_planet_screen.dart';

class CommunicationResultScreen extends StatelessWidget {
  final CommunicationResponse result;
  final PetModel pet;
  const CommunicationResultScreen({
    super.key,
    required this.result,
    required this.pet,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('溝通結果')),
    bottomNavigationBar: FreeMemberAd(
      users: getIt<AuthService>().getUserStream(),
      uid: pet.ownerId,
      onViewPlans: () => PointsShopScreen.open(context, initialOffer: 'plus'),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: AppContent(child: CommunicationResultContent(result: result)),
      ),
    ),
  );
}

class CommunicationResultContent extends StatelessWidget {
  final CommunicationResponse result;
  const CommunicationResultContent({super.key, required this.result});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (result is AiSafeResponseModel)
        _safe(result as AiSafeResponseModel)
      else
        _standard(result as AiResponseModel),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('copy-response'),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('複製回覆'),
          onPressed: () async {
            try {
              await Clipboard.setData(
                ClipboardData(text: communicationCopyText(result)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已複製回覆')));
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('無法存取剪貼簿，請選取文字複製。')),
                );
              }
            }
          },
        ),
      ),
      if (result.matchedCardIds.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            '本次知識卡：${planetCards.where((card) => result.matchedCardIds.contains(card.id)).map((card) => '${card.title}（${result.newCardIds.contains(card.id) ? '本次新收藏' : '已收藏'}）').join('、')}',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PetPlanetScreen()),
        ),
        icon: const Icon(Icons.auto_stories_outlined),
        label: const Text('查看寵物星球圖鑑', textAlign: TextAlign.center),
      ),
    ],
  );

  Widget _standard(AiResponseModel model) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _card('重點摘要', model.summary, key: const Key('result-summary')),
      const SizedBox(height: 24),
      _heading(ChatUiTexts.petVoiceTitle, Icons.pets),
      for (final voice in model.petVoice)
        _card(
          voice.question.isEmpty ? '毛孩的回覆' : '提問：${voice.question}',
          naturalPetVoice(voice.answer),
        ),
      const SizedBox(height: 24),
      _knowledge([
        _card(model.knowledgeStation.title, model.knowledgeStation.content),
      ]),
    ],
  );

  Widget _safe(AiSafeResponseModel model) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.safetyAlert.hasRedFlags) ...[
        Semantics(
          liveRegion: true,
          child: _card(
            ChatUiTexts.safetyAlertTitle,
            model.safetyAlert.message,
            key: const Key('result-safety'),
            alert: true,
          ),
        ),
        const SizedBox(height: 16),
      ] else ...[
        _heading(ChatUiTexts.safeModeTitle, Icons.shield_outlined),
        const SizedBox(height: 16),
      ],
      if (model.nextSteps.isNotEmpty)
        Column(
          key: const Key('result-next-steps'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('接下來可以做', Icons.check_circle_outline),
            for (final step in model.nextSteps) _bullet(step),
            const SizedBox(height: 24),
          ],
        ),
      _heading(ChatUiTexts.petVoiceTitle, Icons.pets),
      _card(
        '毛孩的回覆',
        naturalPetVoice(model.petVoice.text),
        key: const Key('result-voice'),
      ),
      if (model.knowledgeTips.isNotEmpty) ...[
        const SizedBox(height: 24),
        _knowledge([for (final tip in model.knowledgeTips) _bullet(tip)]),
      ],
    ],
  );

  Widget _knowledge(List<Widget> children) => Material(
    color: AppColors.surfaceSoft,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const Key('result-knowledge'),
      maintainState: true,
      iconColor: AppColors.accent,
      collapsedIconColor: AppColors.accent,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textPrimary,
      title: const Text(
        ChatUiTexts.knowledgeTipsTitle,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      subtitle: const Text(
        '展開閱讀照護說明',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: children,
    ),
  );

  Widget _heading(String title, IconData icon) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.accent),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ],
  );

  Widget _card(String title, String content, {Key? key, bool alert = false}) =>
      Container(
        key: key,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alert ? const Color(0xFFFFF1F0) : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: alert ? Border.all(color: AppColors.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.bold,
                color: alert ? AppColors.error : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.accent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
