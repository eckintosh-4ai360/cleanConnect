import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../domain/entities/user_entity.dart';

class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate after a brief initialization delay
    useEffect(() {
      Future.delayed(const Duration(seconds: 3), () async {
        if (!context.mounted) return;

        // Check if user is logged in
        final authState = ref.read(authStateControllerProvider);
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          if (user.role == UserRole.rider) {
            context.go('/rider/home');
          } else if (user.role == UserRole.admin) {
            context.go('/admin/home');
          } else {
            context.go('/customer/home');
          }
        } else {
          final completed = ref.read(onboardingControllerProvider);
          if (completed) {
            context.go('/login');
          } else {
            context.go('/onboarding');
          }
        }
      });
      return null;
    }, []);

    // Animate the three dots loading indicator
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      animationController.repeat();
      return null;
    }, []);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF9), // Cream Warm White
              Color(0xFFFFF0D4), // Soft Peach/Warm Orange
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Card
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.recycling,
                        size: 52,
                        color: Color(0xFF4CAF50), // Eco Green
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  const Text(
                    'EcoSystem',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  Text(
                    'Sustainable waste management.',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF1A1A1A).withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Initializing Dots at bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: animationController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final delay = index * 0.2;
                            final animValue = (animationController.value - delay).clamp(0.0, 1.0);
                            double bounce = 0.0;
                            if (animValue < 0.5) {
                              bounce = animValue * 2;
                            } else {
                              bounce = (1.0 - animValue) * 2;
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              transform: Matrix4.translationValues(0, -bounce * 10, 0),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0A500),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'INITIALIZING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6E685E),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
