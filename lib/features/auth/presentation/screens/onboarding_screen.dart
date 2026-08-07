import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';

// ─── Color palette ───────────────────────────────────────────────────────────
const _kPrimary = Color(0xFFF0A500);
const _kGreen = Color(0xFF3EC16B);
const _kBlue = Color(0xFF3A8EF6);
const _kPurple = Color(0xFF8A64F7);
const _kDark = Color(0xFF1A1A1A);
const _kMuted = Color(0xFF6E685E);
const _kBg = Color(0xFFFFFDF9);

// ─── Slide data model ────────────────────────────────────────────────────────
class _SlideData {
  final String stepLabel;
  final String title;
  final String description;
  final Color accentColor;
  final Color cardBg;
  final IconData heroIcon;
  final List<_FloatingBadge> badges;
  final String buttonText;

  const _SlideData({
    required this.stepLabel,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.cardBg,
    required this.heroIcon,
    required this.badges,
    required this.buttonText,
  });
}

class _FloatingBadge {
  final IconData icon;
  final String label;
  final Color color;
  const _FloatingBadge(this.icon, this.label, this.color);
}

// ─── Slide definitions ───────────────────────────────────────────────────────
const _slides = [
  _SlideData(
    stepLabel: 'Welcome',
    title: 'Smart Waste\nManagement',
    description:
        'CleanConnect streamlines waste collection from request to disposal — seamlessly connecting customers, admins, and riders.',
    accentColor: _kPrimary,
    cardBg: Color(0xFFFFF3D0),
    heroIcon: Icons.recycling_rounded,
    badges: [
      _FloatingBadge(Icons.eco_rounded, 'Eco-Friendly', _kGreen),
      _FloatingBadge(Icons.flash_on_rounded, 'Fast & Easy', _kPrimary),
    ],
    buttonText: 'See How It Works',
  ),
  _SlideData(
    stepLabel: 'Step 1 — Customer',
    title: 'Customer\nRequests Pickup',
    description:
        'Customers simply tap to schedule a waste pickup. Choose a preferred time, add bin details and submit — done in seconds.',
    accentColor: _kBlue,
    cardBg: Color(0xFFDDEEFF),
    heroIcon: Icons.person_rounded,
    badges: [
      _FloatingBadge(Icons.schedule_rounded, 'Pick a Time', _kBlue),
      _FloatingBadge(Icons.delete_outline_rounded, 'Bin Details', _kMuted),
    ],
    buttonText: 'Next',
  ),
  _SlideData(
    stepLabel: 'Step 2 — Admin',
    title: 'Admin Assigns\na Rider',
    description:
        'Our admin dashboard reviews each request and dispatches the nearest available rider instantly — no delays, no confusion.',
    accentColor: _kPurple,
    cardBg: Color(0xFFEDE7FF),
    heroIcon: Icons.admin_panel_settings_rounded,
    badges: [
      _FloatingBadge(Icons.assignment_ind_rounded, 'Smart Dispatch', _kPurple),
      _FloatingBadge(Icons.verified_rounded, 'Verified Riders', _kGreen),
    ],
    buttonText: 'Next',
  ),
  _SlideData(
    stepLabel: 'Step 3 — Rider',
    title: 'Rider Delivers\nto Dump Site',
    description:
        'The assigned rider navigates to the customer, collects the waste, and delivers it safely to the certified dump site.',
    accentColor: _kGreen,
    cardBg: Color(0xFFD4F5E2),
    heroIcon: Icons.two_wheeler_rounded,
    badges: [
      _FloatingBadge(Icons.route_rounded, 'Live Navigation', _kGreen),
      _FloatingBadge(Icons.check_circle_rounded, 'Verified Drop-off', _kBlue),
    ],
    buttonText: 'Get Started',
  ),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────
class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final animController = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );

    useEffect(() {
      animController.forward();
      return null;
    }, []);

    void handleNext() {
      if (currentPage.value < _slides.length - 1) {
        animController.reverse().then((_) {
          pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
          animController.forward();
        });
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
        animController.reverse().then((_) {
          pageController.previousPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
          animController.forward();
        });
      }
    }

    final slide = _slides[currentPage.value];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            slide.accentColor.withValues(alpha: 0.08),
            _kBg,
            _kBg,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar ──────────────────────────────────────────────────
              _TopBar(
                currentPage: currentPage.value,
                totalPages: _slides.length,
                accentColor: slide.accentColor,
                onBack: handleBack,
                onSkip: handleSkip,
              ),

              // ── Step Indicator Pipeline ──────────────────────────────────
              _PipelineIndicator(
                currentPage: currentPage.value,
                slides: _slides,
              ),

              const SizedBox(height: 8),

              // ── Page Content ─────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _slides.length,
                  onPageChanged: (index) => currentPage.value = index,
                  itemBuilder: (context, index) {
                    return _SlidePage(
                      slide: _slides[index],
                      animController: animController,
                    );
                  },
                ),
              ),

              // ── Bottom Action ─────────────────────────────────────────────
              _BottomAction(
                slide: slide,
                currentPage: currentPage.value,
                totalPages: _slides.length,
                onNext: handleNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color accentColor;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _TopBar({
    required this.currentPage,
    required this.totalPages,
    required this.accentColor,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          AnimatedOpacity(
            opacity: currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: currentPage > 0 ? onBack : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 16,
                  color: _kDark,
                ),
              ),
            ),
          ),

          // Brand logo mark
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.recycling_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CleanConnect',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          // Skip button
          TextButton(
            onPressed: onSkip,
            child: Text(
              currentPage == _slides.length - 1 ? '' : 'Skip',
              style: const TextStyle(
                color: _kMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pipeline Step Indicator ──────────────────────────────────────────────────
class _PipelineIndicator extends StatelessWidget {
  final int currentPage;
  final List<_SlideData> slides;

  const _PipelineIndicator({
    required this.currentPage,
    required this.slides,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: List.generate(slides.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line between steps
            final slideIndex = i ~/ 2;
            final isPast = currentPage > slideIndex;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isPast
                      ? slides[slideIndex].accentColor
                      : Colors.grey.shade200,
                ),
              ),
            );
          } else {
            // Step node
            final slideIndex = i ~/ 2;
            final isCurrent = currentPage == slideIndex;
            final isPast = currentPage > slideIndex;
            final stepSlide = slides[slideIndex];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: isCurrent ? 36 : 28,
              height: isCurrent ? 36 : 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent || isPast
                    ? stepSlide.accentColor
                    : Colors.grey.shade200,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: stepSlide.accentColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: isPast
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : Icon(
                        stepSlide.heroIcon,
                        color: isCurrent ? Colors.white : Colors.grey.shade400,
                        size: isCurrent ? 18 : 14,
                      ),
              ),
            );
          }
        }),
      ),
    );
  }
}

// ─── Slide Page ───────────────────────────────────────────────────────────────
class _SlidePage extends HookWidget {
  final _SlideData slide;
  final AnimationController animController;

  const _SlidePage({
    required this.slide,
    required this.animController,
  });

  @override
  Widget build(BuildContext context) {
    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOut),
    );
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Circular Hero Card ──────────────────────────────────────
              _CircularHeroCard(slide: slide),

              const SizedBox(height: 32),

              // ── Step label pill ─────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: slide.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  slide.stepLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: slide.accentColor,
                    letterSpacing: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Title ────────────────────────────────────────────────────
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 14),

              // ── Description ───────────────────────────────────────────────
              Text(
                slide.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: _kMuted,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Circular Hero Card ───────────────────────────────────────────────────────
class _CircularHeroCard extends StatelessWidget {
  final _SlideData slide;

  const _CircularHeroCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outermost subtle ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: slide.accentColor.withValues(alpha: 0.14),
                width: 2,
              ),
            ),
          ),

          // Middle dashed ring
          CustomPaint(
            size: const Size(240, 240),
            painter: _DashedCirclePainter(
              color: slide.accentColor.withValues(alpha: 0.25),
              dashCount: 24,
            ),
          ),

          // Main filled circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: slide.cardBg,
              boxShadow: [
                BoxShadow(
                  color: slide.accentColor.withValues(alpha: 0.22),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 12,
                  spreadRadius: -4,
                  offset: const Offset(-4, -4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                slide.heroIcon,
                size: 80,
                color: slide.accentColor,
              ),
            ),
          ),

          // Floating badge chips
          ..._buildBadges(),
        ],
      ),
    );
  }

  List<Widget> _buildBadges() {
    // Positions relative to center (140, 140) of the 280×280 stack
    final positions = [
      const Offset(-118, -58),
      const Offset(94, 68),
    ];

    return List.generate(
      math.min(slide.badges.length, positions.length),
      (i) {
        final badge = slide.badges[i];
        final pos = positions[i];
        return Positioned(
          left: 140 + pos.dx,
          top: 140 + pos.dy,
          child: _BadgeChip(badge: badge),
        );
      },
    );
  }
}

// ─── Badge chip ───────────────────────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  final _FloatingBadge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badge.color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: badge.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 13, color: badge.color),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badge.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed Circle Painter ────────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;

  const _DashedCirclePainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 2;
    final dashAngle = (2 * math.pi) / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.dashCount != dashCount;
}

// ─── Bottom Action Area ────────────────────────────────────────────────────────
class _BottomAction extends StatelessWidget {
  final _SlideData slide;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  const _BottomAction({
    required this.slide,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              final isSelected = currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 28 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected ? slide.accentColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // CTA button with accent glow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: slide.accentColor.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: slide.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slide.buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

