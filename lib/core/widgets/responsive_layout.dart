import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────────────────────

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= Breakpoints.desktop;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= Breakpoints.tablet;

bool isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < Breakpoints.mobile;

double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE LAYOUT — 2-way (mobile / desktop)
// ─────────────────────────────────────────────────────────────────────────────

/// Adaptive layout: renders [mobile] or [desktop] based on screen width
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;
  final double breakpoint;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
    this.breakpoint = Breakpoints.tablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) return desktop;
        return mobile;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP RESPONSIVE SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

/// Scaffold responsif:
/// - Mobile (<900): BottomNavigationBar
/// - Tablet (900–1199): NavigationRail kiri (icon + label mini)
/// - Desktop (1200+): NavigationDrawer/sidebar penuh (icon + label)
class AppResponsiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavItem> items;
  final List<Widget> pages;
  final Widget? header;           // Header khusus sidebar (logo, avatar)
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const AppResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.items,
    required this.pages,
    this.header,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return _buildDesktopLayout(context);
        } else if (constraints.maxWidth >= Breakpoints.tablet) {
          return _buildTabletLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  // ── MOBILE: BottomNavigationBar ──
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF8FAFC),
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _MobileNavBar(
        currentIndex: currentIndex,
        items: items,
        onTap: onDestinationSelected,
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  // ── TABLET: NavigationRail slim (icon + short label) ──
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _TabletNavRail(
            currentIndex: currentIndex,
            items: items,
            onTap: onDestinationSelected,
            header: header,
          ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  // ── DESKTOP: Full NavigationDrawer (icon + full label) ──
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _DesktopSidebar(
            currentIndex: currentIndex,
            items: items,
            onTap: onDestinationSelected,
            header: header,
          ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _MobileNavBar extends StatelessWidget {
  final int currentIndex;
  final List<AppNavItem> items;
  final ValueChanged<int> onTap;

  const _MobileNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF040D1F),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
            blurRadius: 12,
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final isSelected = currentIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: isSelected
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withAlpha(130),
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withAlpha(110),
                          fontSize: 9.5,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET NAV RAIL
// ─────────────────────────────────────────────────────────────────────────────

class _TabletNavRail extends StatelessWidget {
  final int currentIndex;
  final List<AppNavItem> items;
  final ValueChanged<int> onTap;
  final Widget? header;

  const _TabletNavRail({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF040D1F),
        border: Border(
          right: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (header != null) ...[header!, const SizedBox(height: 8)],
            // Logo mini
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withAlpha(80),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isSelected = currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: item.label,
                      preferBelow: false,
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 64,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF7A00),
                                      Color(0xFFFF0055)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : Colors.white.withAlpha(5),
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected
                                ? null
                                : Border.all(color: Colors.white.withAlpha(10)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withAlpha(130),
                                size: 22,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.shortLabel ?? item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withAlpha(100),
                                  fontSize: 9,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final List<AppNavItem> items;
  final ValueChanged<int> onTap;
  final Widget? header;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF040D1F),
        border: Border(
          right: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A00), Color(0xFFFF0055)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withAlpha(80),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('📚', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'e-Learning',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Platform Belajar Digital',
                          style: TextStyle(
                            color: Colors.white.withAlpha(110),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?header,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white12, height: 1),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isSelected = currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      AppColors.orange.withAlpha(60),
                                      AppColors.orangeDark.withAlpha(40),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.orange.withAlpha(100))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.white.withAlpha(130),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withAlpha(140),
                                  ),
                                ),
                              ),
                              if (item.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.rose,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP NAV ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AppNavItem {
  final String label;
  final String? shortLabel; // Label pendek untuk tablet rail
  final IconData icon;
  final IconData selectedIcon;
  final String? badge;

  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.shortLabel,
    this.badge,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE FORM WRAPPER — constraint lebar form di desktop
// ─────────────────────────────────────────────────────────────────────────────

/// Wrap form/content agar tidak meregang penuh di layar desktop.
/// Gunakan sebagai body atau child widget pada screen form.
class ResponsiveFormWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveFormWrapper({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
