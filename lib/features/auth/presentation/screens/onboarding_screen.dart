import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);

    final pages = [
      _OnboardingPageData(
        title: 'Effortless Waste\nManagement',
        description: 'Schedule pickups in seconds. We handle the logistics, you focus on your business.',
        imagePath: 'assets/images/smart_bin.png',
        buttonText: 'Next',
        isCustomWidget: false,
      ),
      _OnboardingPageData(
        title: 'Real-time Tracking',
        description: 'Follow your collection vehicle live on the map and know exactly when it arrives.',
        imagePath: 'assets/images/map_route.png',
        buttonText: 'Next',
        isCustomWidget: false,
      ),
      _OnboardingPageData(
        title: 'Track Your Impact',
        description: 'See real-time visualization of your carbon savings and recycled weight. Every small action contributes to a measurable difference for a greener planet.',
        imagePath: 'assets/images/co2_saving.png',
        buttonText: 'Get Started',
        isCustomWidget: true, // Special glassmorphic impact badge
      ),
    ];

    void handleNext() {
      if (currentPage.value < pages.length - 1) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        ref.read(onboardingControllerProvider.notifier).completeOnboarding();
        context.go('/login');
      }
    }

    void handleSkip() {
      ref.read(onboardingControllerProvider.notifier).completeOnboarding();
      context.go('/login');
    }

    void handleBack() {
      if (currentPage.value > 0) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9), // Warm light background
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  currentPage.value > 0
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                          onPressed: handleBack,
                        )
                      : const SizedBox(width: 48, height: 48),
                  // Progress indicator in the header of Page 2 (as in image)
                  currentPage.value == 1
                      ? Row(
                          children: List.generate(pages.length, (index) {
                            final isSelected = currentPage.value == index;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSelected ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF0A500) : const Color(0xFFE5DECE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        )
                      : const SizedBox.shrink(),
                  TextButton(
                    onPressed: handleSkip,
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        color: Color(0xFF6E685E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Page Slider
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: pages.length,
                onPageChanged: (index) => currentPage.value = index,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration Area
                        if (!page.isCustomWidget) ...[
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0D4).withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Image.asset(
                                page.imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Glassmorphic Impact Badge for Slide 3
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Inner Globe Circle Image
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFC8E6C9),
                                      width: 4,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(60),
                                    child: Image.asset(
                                      page.imagePath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Badge Text
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.eco,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'YOUR POTENTIAL IMPACT',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '120 kg',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'CO2 Offset Projected Annually',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6E685E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
                        // Page Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Page Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6E685E),
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Action Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicators (hidden in Page 2 because it is in the header, shown on Page 1 & 3)
                  currentPage.value != 1
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final isSelected = currentPage.value == index;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isSelected ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF0A500) : const Color(0xFFE5DECE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        )
                      : const SizedBox(height: 8),
                  const SizedBox(height: 24),
                  // Button
                  EcoButton(
                    text: pages[currentPage.value].buttonText,
                    onPressed: handleNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;
  final String buttonText;
  final bool isCustomWidget;

  _OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.buttonText,
    required this.isCustomWidget,
  });
}
