import 'package:flutter/material.dart';
import 'package:ai_pet_communication/app/theme.dart';
import 'package:ai_pet_communication/models/onboarding_model.dart';
import 'package:ai_pet_communication/features/onboarding/application/onboarding_service.dart';
import 'package:ai_pet_communication/features/auth/application/auth_service.dart';
import 'package:ai_pet_communication/app/injection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  late final OnboardingService _onboardingService = getIt<OnboardingService>();

  int _currentPage = 0;
  final Map<String, dynamic> _answers = {};
  bool _isDisclaimerAccepted = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSlides = onboardingQuestions.length + 2;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage > 0 && _currentPage <= onboardingQuestions.length)
              AppContent(
                verticalPadding: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '第 $_currentPage／${onboardingQuestions.length} 題',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _currentPage / onboardingQuestions.length,
                      minHeight: 6,
                      color: AppColors.accent,
                      backgroundColor: AppColors.outline,
                      semanticsLabel:
                          '引導進度，第 $_currentPage 題，共 ${onboardingQuestions.length} 題',
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _welcome(),
                  for (final question in onboardingQuestions)
                    _question(question),
                  _conclusion(),
                ],
              ),
            ),
            _footer(totalSlides),
          ],
        ),
      ),
    );
  }

  Widget _page(Widget child) =>
      SingleChildScrollView(child: AppContent(child: child));

  Widget _welcome() => _page(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.pets_rounded, size: 64, color: AppColors.accent),
        const SizedBox(height: 24),
        const Text(
          '歡迎來到 PAWLINK',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        _intro(Icons.edit_note_rounded, '分享近況與問題', '說說毛孩最近的生活，以及你想了解的事。'),
        _intro(Icons.chat_bubble_outline, '閱讀 AI 輔助回覆', '依你提供的描述，整理對話與照護參考。'),
        _intro(Icons.auto_stories_outlined, '累積紀錄與照護知識', '回看你們的相處，慢慢累積理解與陪伴。'),
        const SizedBox(height: 16),
        Material(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          child: CheckboxListTile(
            key: const Key('onboarding-consent'),
            value: _isDisclaimerAccepted,
            activeColor: AppColors.accent,
            onChanged: (value) =>
                setState(() => _isDisclaimerAccepted = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            title: const Text(
              '我了解此服務為 AI 娛樂性質，非解釋毛孩行為之準則',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _intro(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _question(OnboardingQuestion question) => _page(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (!question.isRequired)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '選填，可以直接前往下一步',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        if (question.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              question.subtitle!,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 24),
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              checked: _answers[question.id] == option.value,
              inMutuallyExclusiveGroup: true,
              child: Material(
                color: _answers[question.id] == option.value
                    ? AppColors.surfaceMint
                    : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _answers[question.id] == option.value
                        ? AppColors.accent
                        : AppColors.outline,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      setState(() => _answers[question.id] = option.value),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_answers[question.id] == option.value) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _conclusion() => _page(
    const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24),
        Icon(Icons.stars_rounded, size: 64, color: AppColors.accent),
        SizedBox(height: 24),
        Text(
          '太棒了！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '準備好開始了。\n從新增毛孩檔案開始，記錄你們的日常。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  Widget _footer(int totalSlides) {
    final isLastPage = _currentPage == totalSlides - 1;
    var canGoNext = true;
    if (_currentPage == 0) {
      canGoNext = _isDisclaimerAccepted;
    } else if (_currentPage <= onboardingQuestions.length) {
      final question = onboardingQuestions[_currentPage - 1];
      canGoNext = !question.isRequired || _answers[question.id] != null;
    }
    return AppContent(
      verticalPadding: 12,
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                      ),
                child: const Text('上一步', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              key: const Key('onboarding-next'),
              style: AppStyles.primaryButton,
              onPressed: canGoNext && !_isSubmitting
                  ? () => _handleNext(isLastPage)
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                        semanticsLabel: '正在儲存',
                      ),
                    )
                  : Text(
                      isLastPage
                          ? '開始使用'
                          : _currentPage == 0
                          ? '立即開始'
                          : '下一步',
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNext(bool isLastPage) async {
    if (isLastPage) {
      if (_isSubmitting) return;

      // 顯示載入中
      setState(() {
        _isSubmitting = true;
      });

      // 儲存答案並完成 (同步至雲端帳號)
      try {
        final submittedAnswers = Map<String, dynamic>.unmodifiable(_answers);
        await getIt<AuthService>().updateOnboardingStatus(
          true,
          submittedAnswers,
        );

        // 同時也存一份在本地作為備份 (選用)
        List<OnboardingAnswer> answerList = submittedAnswers.entries
            .map((e) => OnboardingAnswer(questionId: e.key, value: e.value))
            .toList();
        await _onboardingService.saveAnswers(answerList);
        await _onboardingService.markCompleted(true);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
        }
      }

      // 注意：這裡不需要 Navigator.push，因為 main.dart 的 StreamBuilder
      // 會在 Firestore 資料更新後自動切換回 HomeScreen
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
