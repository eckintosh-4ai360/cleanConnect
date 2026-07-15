import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../config/theme_provider.dart';

/// A compact dark/light mode toggle pill that can be placed in any AppBar or header.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => ref.read(themeModeControllerProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 64,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2E2A24)
              : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFFF0A500).withOpacity(0.4)
                : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Track icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: 14,
                    color: isDark ? Colors.grey.shade600 : Colors.amber.shade700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.nightlight_round,
                    size: 14,
                    color: isDark ? const Color(0xFFF0A500) : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            // Thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFF0A500) : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 14,
                    color: isDark ? Colors.black : Colors.amber.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
