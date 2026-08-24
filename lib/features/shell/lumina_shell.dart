import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/utils/responsive.dart';
import '../../core/theme/text_styles.dart';

const _kSidebarWidth = 220.0;

/// Bottom navigation caps at five destinations; this sits at four.
const _destinations = <({IconData icon, String label})>[
  (icon: LucideIcons.house, label: 'Home'),
  (icon: LucideIcons.mic, label: 'Practice'),
  (icon: LucideIcons.chartBar, label: 'Insights'),
  (icon: LucideIcons.userCheck, label: 'Interview'),
];

class LuminaShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const LuminaShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    // Sidebar replaces the bottom bar once there is room for it.
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(
              currentIndex: shell.currentIndex,
              onTap: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
            ),
            const VerticalDivider(width: 1, color: AppColors.line),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              label: d.label,
              tooltip: d.label,
            ),
        ],
      ),
    );
  }
}

// ── Sidebar navigation (web / large screens) ─────────────────────────────────

class _SideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SideNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      color: AppColors.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo ───────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo_variant_1.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Oralidle',
                      style: context.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main nav items ─────────────────────────────────────────────
          ...List.generate(_destinations.length, (i) {
            final item = _destinations[i];
            return _SideNavItem(
              icon: item.icon,
              label: item.label,
              active: currentIndex == i,
              onTap: () => onTap(i),
            );
          }),

          const Spacer(),

          // ── Footer items ───────────────────────────────────────────────
          // _SideNavItem(
          //   icon: LucideIcons.settings,
          //   activeIcon: LucideIcons.settings,
          //   label: 'Settings',
          //   active: false,
          //   onTap: () {},
          // ),
          // _SideNavItem(
          //   icon: LucideIcons.helpCircle,
          //   activeIcon: LucideIcons.helpCircle,
          //   label: 'Support',
          //   active: false,
          //   onTap: () {},
          // ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: SafeArea(
              top: false,
              child: AppButton.secondary(
                label: 'Upgrade to Pro',
                expand: true,
                size: AppButtonSize.small,
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.raised2 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: active ? AppColors.ink : AppColors.borderControl,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.cardTitle.copyWith(
                  color: active ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
            if (active)
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
