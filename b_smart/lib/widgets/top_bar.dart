import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../theme/design_tokens.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const TopBar({Key? key, this.title = ''}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(LucideIcons.bell.localLucide),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: DesignTokens.instaPink,
            child: Icon(LucideIcons.user.localLucide, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

