import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feed_post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class PostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onMore;

  const PostCard({
    Key? key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName = post.fullName?.trim().isNotEmpty == true
        ? post.fullName!
        : post.userName;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(0),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar, name, three dots (Instagram style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade200,
                    backgroundImage: post.userAvatar != null && post.userAvatar!.isNotEmpty
                        ? NetworkImage(post.userAvatar!)
                        : null,
                    child: post.userAvatar == null || post.userAvatar!.isEmpty
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: DesignTokens.instaPink,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          if (post.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(LucideIcons.badgeCheck, size: 14, color: Colors.blue.shade400),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMore ?? () {},
                  icon: Icon(LucideIcons.ellipsis, size: 24, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Media
          if (post.mediaUrls.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRect(
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrls.first,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (ctx, url) => Container(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DesignTokens.instaPink,
                      ),
                    ),
                  ),
                  errorWidget: (ctx, url, err) => Container(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                    child: Center(
                      child: Icon(LucideIcons.imageOff, size: 48, color: mutedColor),
                    ),
                  ),
                ),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                child: Center(
                  child: Icon(LucideIcons.image, size: 48, color: mutedColor),
                ),
              ),
            ),

          // Action bar: like, comment, share, save (Instagram order)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike ?? () {},
                  icon: Icon(
                    post.isLiked ? Icons.favorite : LucideIcons.heart,
                    size: 28,
                    color: post.isLiked ? Colors.red : textColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  onPressed: onComment ?? () {},
                  icon: Icon(LucideIcons.messageCircle, size: 26, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  onPressed: onShare ?? () {},
                  icon: Icon(LucideIcons.send, size: 26, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onSave ?? () {},
                  icon: Icon(
                    post.isSaved ? Icons.bookmark : LucideIcons.bookmark,
                    size: 26,
                    color: textColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
          ),

          // Likes count
          if (post.likes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Text(
                '${post.likes} ${post.likes == 1 ? 'like' : 'likes'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ),

          // Caption: "username caption" (Instagram style)
          if ((post.caption ?? '').trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: textColor, height: 1.3),
                  children: [
                    TextSpan(
                      text: '${post.userName} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            ),
          ],

          // Time posted (below caption, Instagram style)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 12),
            child: Text(
              _formatTimeAgo(post.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
                fontWeight: FontWeight.w400,
              ),
            ),
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
    if (diff.inSeconds > 30) return '${diff.inSeconds}s';
    return 'Just now';
  }
}
