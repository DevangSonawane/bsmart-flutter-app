import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final int posts;
  final int followers;
  final int following;
  final bool isMe;
  final VoidCallback? onEdit;
  final VoidCallback? onFollow;

  const ProfileHeader({
    Key? key,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.posts = 0,
    this.followers = 0,
    this.following = 0,
    this.isMe = false,
    this.onEdit,
    this.onFollow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with gradient ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DesignTokens.instaGradient,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
                  backgroundColor: Colors.white,
                  child: avatarUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : '', style: const TextStyle(fontSize: 24, color: Colors.black)) : null,
                ),
              ),
              const SizedBox(width: 24),
              // Stats centered vertically
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statColumn(posts, 'posts'),
                    _statColumn(followers, 'followers'),
                    _statColumn(following, 'following'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fullName?.trim().isNotEmpty == true ? fullName!.trim() : username,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          if (bio != null && bio!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bio!, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Share profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(int count, String label) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }
}

