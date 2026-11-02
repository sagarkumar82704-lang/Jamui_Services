import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../shared/widgets/custom_button.dart';

/// [OnboardingPage] नए यूजर्स को JAMUI SERVICE की खासियत (Zero Commission, Verified Locals) समझाता है।
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'जमुई के भरोसेमंद कारीगर',
      'subtitle': 'प्लंबर, इलेक्ट्रीशियन, कारपेंटर और 50+ सेवाएँ अपने घर पर कुछ ही मिनटों में बुक करें।',
      'icon': Icons.home_repair_service_rounded,
      'color': AppColors.primary,
    },
    {
      'title': '0% कमीशन • सीधा संपर्क',
      'subtitle': 'सर्विस प्रोवाइडर से सीधे कॉल या व्हाट्सएप पर बात करें। कोई बिचौलिया या हिडन चार्ज नहीं।',
      'icon': Icons.phone_in_talk_rounded,
      'color': AppColors.secondary,
    },
    {
      'title': 'लोकल बिज़नेस को बढ़ावा',
      'subtitle': 'अगर आप कारीगर या सर्विस प्रोवाइडर हैं, तो आज ही जुड़ें और पाएं हर दिन नए ग्राहक।',
      'icon': Icons.trending_up_rounded,
      'color': AppColors.accent,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: (slide['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 80,
                            color: slide['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: CustomButton(
                text: _currentPage == _slides.length - 1 ? 'शुरू करें' : AppStrings.continueText,
                onPressed: () {
                  if (_currentPage == _slides.length - 1) {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
