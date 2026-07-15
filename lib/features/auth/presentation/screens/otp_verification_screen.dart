import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../../core/shared/widgets/eco_button.dart';

class OtpVerificationScreen extends HookConsumerWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Focus nodes & controllers for the 4 OTP fields
    final otpControllers = List.generate(4, (_) => useTextEditingController());
    final otpFocusNodes = List.generate(4, (_) => useFocusNode());
    final isVerifying = useState(false);

    // Resend countdown timer state (starts at 29s)
    final secondsRemaining = useState(29);
    final timerRef = useRef<Timer?>(null);

    // Start timer on mount
    void startTimer() {
      secondsRemaining.value = 29;
      timerRef.value?.cancel();
      timerRef.value = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (secondsRemaining.value > 0) {
          secondsRemaining.value--;
        } else {
          timer.cancel();
        }
      });
    }

    useEffect(() {
      startTimer();
      return () => timerRef.value?.cancel();
    }, []);

    // Helper to format countdown timer string (e.g. 00:29)
    String formatTime(int totalSeconds) {
      final minutes = (totalSeconds / 60).floor().toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    // Triggered when a digit is entered in one of the fields
    void onChanged(int index, String value) {
      if (value.isNotEmpty) {
        // Move focus to next field if it's not the last one
        if (index < 3) {
          otpFocusNodes[index + 1].requestFocus();
        } else {
          otpFocusNodes[index].unfocus();
        }
      } else {
        // Backspace - move to previous field
        if (index > 0) {
          otpFocusNodes[index - 1].requestFocus();
        }
      }
    }

    // Call verify action
    Future<void> handleVerify() async {
      final code = otpControllers.map((c) => c.text).join();
      if (code.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter all 4 digits of the OTP code.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      isVerifying.value = true;
      try {
        await ref.read(authRepositoryProvider).verifyOtp(phoneNumber, code);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification successful! Dashboard accessed.'),
            backgroundColor: Colors.green,
          ),
        );
        // Successful verification routes to dashboard
        context.go('/dashboard');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        isVerifying.value = false;
      }
    }

    // Resend OTP
    Future<void> handleResend() async {
      if (secondsRemaining.value > 0) return;
      try {
        await ref.read(authRepositoryProvider).resendOtp(phoneNumber);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent!'),
            backgroundColor: Colors.green,
          ),
        );
        startTimer();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top navigation arrow
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 40),
              // OTP Card layout
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? theme.cardTheme.color : const Color(0xFFFFFDF9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : const Color(0xFFFFF7EA),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Lock Icon in circular background
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0D4),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF0A500).withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_person_outlined,
                        color: Color(0xFFC78200),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verification Code',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 4-digit code sent to your phone\n$phoneNumber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 4 Code input squares
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        return Container(
                          width: 60,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade900 : const Color(0xFFF2F6FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: otpFocusNodes[index].hasFocus
                                  ? const Color(0xFFF0A500)
                                  : (isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: TextField(
                              controller: otpControllers[index],
                              focusNode: otpFocusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) => onChanged(index, val),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // Resend text / countdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          secondsRemaining.value > 0
                              ? "Didn't receive code? "
                              : "Ready to resend? ",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: handleResend,
                          child: Text(
                            secondsRemaining.value > 0
                                ? 'Resend in ${formatTime(secondsRemaining.value)}'
                                : 'Resend code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: secondsRemaining.value > 0
                                  ? Colors.grey.shade500
                                  : const Color(0xFFF0A500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Verify button
                    EcoButton(
                      text: 'Verify & Proceed',
                      onPressed: handleVerify,
                      isLoading: isVerifying.value,
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
