import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../providers/auth_provider.dart';
import '../../../../core/shared/widgets/clean_connect_button.dart';
import '../../../../core/shared/widgets/clean_connect_text_field.dart';

/// Shown after the user opens the password-reset link from their email.
/// The link has already signed them in with a recovery session; the router
/// keeps them here until the new password is saved.
class ResetPasswordScreen extends HookConsumerWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordController = useTextEditingController();
    final confirmController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isSaving = useState(false);

    final theme = Theme.of(context);

    Future<void> handleSave() async {
      if (!(formKey.currentState?.validate() ?? false)) return;
      isSaving.value = true;
      final messenger = ScaffoldMessenger.of(context);
      try {
        // Clears the recovery flag; the router then moves to the dashboard.
        await ref
            .read(authStateControllerProvider.notifier)
            .updatePassword(passwordController.text);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } on sb.AuthException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (context.mounted) isSaving.value = false;
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Text(
                'Set New Password',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a new password for your account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    CleanConnectTextField(
                      labelText: 'New Password',
                      hintText: 'Enter a new password',
                      controller: passwordController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CleanConnectTextField(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter the new password',
                      controller: confirmController,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CleanConnectButton(
                      text: 'Update Password',
                      onPressed: handleSave,
                      isLoading: isSaving.value,
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        // Don't leave a half-finished recovery session signed in.
                        onPressed: isSaving.value
                            ? null
                            : () => ref
                                .read(authStateControllerProvider.notifier)
                                .logout(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
