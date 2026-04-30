import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants.dart';
import '../../models/onboarding_model.dart';
import '../../services/onboarding_service.dart';
import '../auth_service.dart'; // Just in case, though we'll likely use it in main.dart
import '../../login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  
  int _currentPage = 0;
  final Map<String, dynamic> _answers = {};

  // 產品理念文字
  final String _philosophyText = 
      'AI Pet Communicator 以寵物溝通為核心，幫助你和毛孩建立更深的連結，並補充實用的寵物知識，讓日常互動延伸成有依據的照顧與陪伴。透過 AI 輔助、直覺操作與本地優先的設計，讓你用更簡單的方式，接近毛孩想表達的世界。';

  @override
  Widget build(BuildContext context) {
    final int totalSlides = 1 + onboardingQuestions.length + 1; // 理念 + 問題 + 結束

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 進度條
            if (_currentPage > 0 && _currentPage <= onboardingQuestions.length)
              _buildProgressBar(),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // 強制透過按鈕切換
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPhilosophySlide(),
                  ...onboardingQuestions.map((q) => _buildQuestionSlide(q)),
                  _buildConclusionSlide(),
                ],
              ),
            ),

            // 底部按鈕
            _buildFooter(totalSlides),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = _currentPage / onboardingQuestions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPhilosophySlide() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'logo',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.pets_rounded, size: 80, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            '歡迎來到 PAWLINK',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _philosophyText,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 17,
              height: 1.8,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSlide(OnboardingQuestion question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            question.title,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (question.subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              question.subtitle!,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                bool isSelected = _answers[question.id] == option.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _answers[question.id] = option.value;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade200,
                          width: 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ] : [],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConclusionSlide() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stars_rounded, size: 100, color: Colors.amber),
          const SizedBox(height: 40),
          Text(
            '太棒了！',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '我們已經為您調整好個性化的導引內容。\n現在，就開始您的 AI 寵物溝通之旅吧！',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int totalSlides) {
    bool isLastPage = _currentPage == totalSlides - 1;
    bool canGoNext = true;

    // 檢查必填問題是否已作答
    if (_currentPage > 0 && _currentPage <= onboardingQuestions.length) {
      final q = onboardingQuestions[_currentPage - 1];
      if (q.isRequired && _answers[q.id] == null) {
        canGoNext = false;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                '上一步',
                style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 16),
              ),
            )
          else
            const SizedBox(width: 80),

          ElevatedButton(
            onPressed: canGoNext ? () => _handleNext(isLastPage) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              isLastPage ? '開始使用' : (_currentPage == 0 ? '立即開始' : '下一步'),
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext(bool isLastPage) async {
    if (isLastPage) {
      // 儲存答案並完成
      List<OnboardingAnswer> answerList = _answers.entries
          .map((e) => OnboardingAnswer(questionId: e.key, value: e.value))
          .toList();
      
      await _onboardingService.saveAnswers(answerList);
      await _onboardingService.markCompleted(true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}
