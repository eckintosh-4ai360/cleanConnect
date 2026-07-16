import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user_entity.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';
import '../../../../core/shared/widgets/theme_toggle_button.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Listen to Auth State changes for success/error feedback
    ref.listen<AuthState>(authStateControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${next.user.fullName}!'),
            backgroundColor: Colors.green,
          ),
        );
        if (next.user.role == UserRole.rider) {
          context.go('/rider/home');
        } else if (next.user.role == UserRole.admin) {
          context.go('/admin/home');
        } else {
          context.go('/customer/home');
        }
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    final authState = ref.watch(authStateControllerProvider);
    final isLoading = authState.isLoading;

    void handleSignIn() {
      if (formKey.currentState?.validate() ?? false) {
        ref.read(authStateControllerProvider.notifier).login(
              emailController.text.trim(),
              passwordController.text,
            );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/images/login_banner.png',
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16 + MediaQuery.of(context).padding.top,
                    right: 16,
                    child: const ThemeToggleButton(),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'EcoWaste',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Clean & Connected Communities',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sign In Form Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to manage your EcoWaste account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test Tip: Sign in with an email containing "rider" (e.g. rider@ecowaste.com) to access the Rider dashboard.',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    EcoTextField(
                      labelText: 'Email / Rider ID',
                      hintText: 'Enter your email or ID',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email or Rider ID';
                        }
                        return null;
                      },
                    ),
                    EcoTextField(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      controller: passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    // Forgot Password Right-aligned Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sign In Button
                    EcoButton(
                      text: 'Sign In',
                      onPressed: handleSignIn,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 24),
                    // Or continue with Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Or continue with',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Social Sign-ins
                    EcoSocialButton(
                      text: 'Continue with Google',
                      logoWidget: const Icon(
                        Icons.g_mobiledata,
                        size: 32,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        // Mock Google login
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting to Google accounts...')),
                        );
                      },
                    ),
                    EcoSocialButton(
                      text: 'Continue with Apple',
                      logoWidget: Icon(
                        Icons.apple,
                        size: 24,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        // Mock Apple login
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecting to Apple ID...')),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // Register Footer Link
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              TextSpan(
                                text: 'Register here',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/rider/register'),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: "Want to work with us? ",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              TextSpan(
                                text: 'Apply as Rider',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
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
