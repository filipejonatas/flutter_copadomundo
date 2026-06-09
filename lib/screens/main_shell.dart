import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/session_controller.dart';
import '../theme/app_theme.dart';

/// App shell with floating glass bottom navigation for the main tabs.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.sessionController,
    required this.navigationShell,
  });

  final SessionController sessionController;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.nav),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(AppRadii.nav),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  _BottomNavItem(
                    tooltip: 'Home',
                    icon: PhosphorIcons.house(),
                    activeIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
                    isActive: navigationShell.currentIndex == 0,
                    onTap: () => _goBranch(0),
                  ),
                  _BottomNavItem(
                    tooltip: 'Matches',
                    icon: PhosphorIcons.calendar(),
                    activeIcon: PhosphorIcons.calendar(PhosphorIconsStyle.fill),
                    isActive: navigationShell.currentIndex == 1,
                    onTap: () => _goBranch(1),
                  ),
                  _BottomNavItem(
                    tooltip: 'Ranking',
                    icon: PhosphorIcons.trophy(),
                    activeIcon: PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                    isActive: navigationShell.currentIndex == 2,
                    onTap: () => _goBranch(2),
                  ),
                  _BottomNavItem(
                    tooltip: 'Profile',
                    icon: PhosphorIcons.user(),
                    activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                    isActive: navigationShell.currentIndex == 3,
                    onTap: () => _goBranch(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.tooltip,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
  });

  final String tooltip;
  final PhosphorIconData icon;
  final PhosphorIconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: PhosphorIcon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.black : AppColors.textSecondary,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}
