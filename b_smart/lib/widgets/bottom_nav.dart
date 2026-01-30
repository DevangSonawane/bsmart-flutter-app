import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../theme/design_tokens.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use only top: false so bar floats at bottom with no white strip below (bottom safe area not applied)
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavIcon(icon: LucideIcons.house.localLucide, index: 0, currentIndex: currentIndex, onTap: onTap),
                  _NavIcon(icon: LucideIcons.target.localLucide, index: 1, currentIndex: currentIndex, onTap: onTap), // Ads
                  SizedBox(width: 64), // space for center fab
                  _NavIcon(icon: LucideIcons.megaphone.localLucide, index: 3, currentIndex: currentIndex, onTap: onTap), // Promote
                  _NavIcon(icon: LucideIcons.clapperboard.localLucide, index: 4, currentIndex: currentIndex, onTap: onTap), // Reels
                ],
              ),
            ),
            Positioned(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DesignTokens.instaGradient,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Icon(LucideIcons.plus.localLucide, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavIcon({required this.icon, required this.index, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == index;
    return IconButton(
      onPressed: () => onTap(index),
      icon: Icon(icon, color: active ? DesignTokens.instaPink : Colors.grey[600]),
    );
  }
}

