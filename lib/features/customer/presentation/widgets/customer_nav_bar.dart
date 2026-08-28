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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: GNav(
              selectedIndex: currentIndex,
              onTabChange: (index) => _onItemTapped(context, index),
              gap: 8,
              iconSize: 24,
              haptic: true,
              curve: Curves.easeOutExpo,
              duration: const Duration(milliseconds: 400),
              color: Colors.white.withValues(alpha: 0.45),
              activeColor: EcoTheme.primaryColor,
              tabBackgroundColor: EcoTheme.primaryColor.withValues(alpha: 0.16),
              tabBorderRadius: 30,
              rippleColor: Colors.white.withValues(alpha: 0.06),
              hoverColor: Colors.white.withValues(alpha: 0.04),
              // Sized so the expanded active pill plus three collapsed tabs
              // still fit inside the bar on a 320dp-wide screen.
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
    );
  }
}
