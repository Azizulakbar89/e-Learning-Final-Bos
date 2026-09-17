import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppNavRailItem> items;
  final Widget? header;
  final Widget? footer;

  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        border: Border(
          right: BorderSide(color: AppColors.borderDark.withAlpha(80)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Brand
          ?header,

          const SizedBox(height: 8),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onDestinationSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    AppColors.orange.withAlpha(50),
                                    AppColors.orangeDark.withAlpha(30),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.orange.withAlpha(90))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondaryDark,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondaryDark,
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

          // Footer
          if (footer != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class AppNavRailItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? badge;

  const AppNavRailItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badge,
  });
}
