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
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return SafeArea(
      top: false,
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: DesignTokens.instaPink,
        unselectedItemColor: inactiveColor,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.house), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.target), label: 'Ads'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.megaphone), label: 'Promote'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.clapperboard), label: 'Reels'),
        ],
      ),
    );
  }
}

