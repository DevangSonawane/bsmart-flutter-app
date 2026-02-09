import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final activeColor = DesignTokens.instaPink;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.zero, // Reduce top/bottom space
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 40, // Constrain height to reduce space
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, LucideIcons.house, 'Home', isActive: currentIndex == 0),
              _buildNavItem(context, 1, LucideIcons.target, 'Ads', isActive: currentIndex == 1),
              _buildCreateButton(context), // Highlighted '+' button
              _buildNavItem(context, 3, LucideIcons.megaphone, 'Promote', isActive: currentIndex == 3),
              _buildNavItem(context, 4, LucideIcons.clapperboard, 'Reels', isActive: currentIndex == 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, {required bool isActive}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Reduce icon space
        child: Icon(
          icon,
          size: 26,
          color: isActive ? DesignTokens.instaPink : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(2),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Icon(
          Icons.add_box_outlined,
          size: 28, // Slightly larger to highlight
          color: theme.colorScheme.onSurface, // Solid color to highlight
        ),
      ),
    );
  }
}

