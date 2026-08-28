import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../../../../core/config/theme.dart';

class CustomerBottomNavBar extends StatelessWidget {
  /// -1 means no tab is highlighted — used by screens that sit outside the
  /// four tabs (Subscription) but still show the bar.
  final int currentIndex;

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  static const _routes = [
    '/customer/home',
    '/customer/bins',
    '/customer/history',
    '/customer/profile',
  ];

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    // GNav fires its own selectionClick, so no manual haptic here.
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isTabSelected = currentIndex >= 0 && currentIndex < _routes.length;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      minimum: const EdgeInsets.only(bottom: 12),
      // heightFactor is essential: Scaffold hands bottomNavigationBar loose
      // constraints whose maxHeight is the whole screen, so an unconstrained
      // Align swells to fill it and squeezes the body down to nothing.
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: GNav(
                    selectedIndex: isTabSelected ? currentIndex : 0,
                    onTabChange: (index) => _onItemTapped(context, index),
                    gap: 6,
                    iconSize: 22,
                    haptic: true,
                    curve: Curves.easeOutExpo,
                    duration: const Duration(milliseconds: 350),
                    color: isTabSelected
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.6),
                    activeColor: isTabSelected
                        ? EcoTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.6),
                    tabBackgroundColor: isTabSelected
                        ? EcoTheme.primaryColor.withValues(alpha: 0.16)
                        : Colors.transparent,
                    tabBorderRadius: 28,
                    rippleColor: Colors.white.withValues(alpha: 0.06),
                    hoverColor: Colors.white.withValues(alpha: 0.04),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: EcoTheme.primaryColor,
                    ),
                    tabs: const [
                      GButton(icon: Icons.home_rounded, text: 'Home'),
                      GButton(icon: Icons.delete_rounded, text: 'Bins'),
                      GButton(icon: Icons.history_rounded, text: 'History'),
                      GButton(icon: Icons.person_rounded, text: 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
