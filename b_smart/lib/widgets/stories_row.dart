import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../theme/design_tokens.dart';

class StoriesRow extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final VoidCallback? onYourStoryTap;
  /// Called when a user story is tapped. Index 0 = first user in [users].
  final void Function(int userIndex)? onUserStoryTap;

  const StoriesRow({
    Key? key,
    required this.users,
    this.onYourStoryTap,
    this.onUserStoryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryItem(
              label: 'Your Story',
              avatarUrl: null,
              ringGradient: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade200]),
              onTap: onYourStoryTap,
            );
          }
          final user = users[index - 1];
          return _StoryItem(
            label: (user['username'] ?? user['full_name'] ?? '').toString(),
            avatarUrl: user['avatar_url'] as String?,
            ringGradient: DesignTokens.instaGradient,
            onTap: onUserStoryTap != null ? () => onUserStoryTap!(index - 1) : null,
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final Gradient ringGradient;
  final VoidCallback? onTap;

  const _StoryItem({required this.label, this.avatarUrl, required this.ringGradient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ringGradient,
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null ? Icon(LucideIcons.user.localLucide, color: Colors.grey) : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

