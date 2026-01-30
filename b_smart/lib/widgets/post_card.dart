import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../models/feed_post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class PostCard extends StatelessWidget {
  final FeedPost post;
  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DesignTokens.instaGradient,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: post.userAvatar != null ? NetworkImage(post.userAvatar!) : null,
                    backgroundColor: Colors.grey[200],
                    child: post.userAvatar == null ? Text(post.userName[0]) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (post.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(LucideIcons.circleCheck.localLucide, size: 14, color: Colors.blue),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimeAgo(post.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: Icon(LucideIcons.ellipsis.localLucide)),
              ],
            ),
          ),

          // Media (aspect 4:5 to match React FeedPost)
          if (post.mediaUrls.isNotEmpty)
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => Container(color: Colors.grey[200]),
                  errorWidget: (ctx, url, err) => Container(
                    color: Colors.grey[200],
                    child: Center(child: Icon(LucideIcons.imageOff.localLucide)),
                  ),
                ),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: Icon(LucideIcons.heart.localLucide)),
                IconButton(onPressed: () {}, icon: Icon(LucideIcons.messageCircle.localLucide)),
                IconButton(onPressed: () {}, icon: Icon(LucideIcons.send.localLucide)),
                const Spacer(),
                IconButton(onPressed: () {}, icon: Icon(LucideIcons.bookmark.localLucide)),
              ],
            ),
          ),

          // Caption
          if ((post.caption ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Text(post.caption ?? ''),
            ),

          // Likes count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Text('${post.likes} likes', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Just now';
  }
}

