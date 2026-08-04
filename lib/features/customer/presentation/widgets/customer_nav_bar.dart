import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();

    switch (index) {
      case 0:
        context.go('/customer/home');
        break;
      case 1:
        context.go('/customer/bins');
        break;
      case 2:
        context.go('/customer/history');
        break;
      case 3:
        context.go('/customer/profile');
        break;
    }
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
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context: context,
                  index: 0,
                  icon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                ),
                _buildNavItem(
                  context: context,
                  index: 1,
                  icon: Icons.delete_rounded,
                  inactiveIcon: Icons.delete_outline_rounded,
                ),
                _buildNavItem(
                  context: context,
                  index: 2,
                  icon: Icons.history_rounded,
                  inactiveIcon: Icons.history_rounded,
                ),
                _buildNavItem(
                  context: context,
                  index: 3,
                  icon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData inactiveIcon,
  }) {
    final bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(context, index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Icon(
          isActive ? icon : inactiveIcon,
          size: 26,
          color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }
}
