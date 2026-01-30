import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/supabase_service.dart';
import '../theme/design_tokens.dart';

/// Full-screen post detail page for mobile / deep link (/post/:postId).
/// Reuses same data and UI as PostDetailModal but as a routed screen with AppBar.
class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _postUser;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingPost = true;
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _isLiked = false;
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingPost = true;
      _loadingComments = true;
    });
    final post = await _svc.getPostById(widget.postId);
    if (post == null || !mounted) {
      if (mounted) setState(() => _loadingPost = false);
      return;
    }
    final userId = post['user_id'] as String?;
    Map<String, dynamic>? user;
    if (userId != null) {
      user = await _svc.getUserById(userId);
    }
    final comments = await _svc.getComments(widget.postId);
    final likes = post['likes'] as List<dynamic>? ?? [];
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isLiked = currentUserId != null &&
        likes.any((e) => e is Map && e['user_id'] == currentUserId);
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = comments;
        _isLiked = isLiked;
        _loadingPost = false;
        _loadingComments = false;
      });
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (content.isEmpty || userId == null) return;
    setState(() => _postingComment = true);
    try {
      await _svc.addComment(widget.postId, userId, content);
      _commentController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  void _onAuthorTap() {
    final userId = _postUser?['id'] as String?;
    if (userId == null) return;
    Navigator.of(context).pushNamed('/profile/$userId');
  }

  static String _formatRelativeTime(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  static String _formatFullDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    return '${date.month} ${date.day}, ${date.year}';
  }

  String _displayImageUrl() {
    final media = _post?['media'] as List<dynamic>?;
    if (media == null || media.isEmpty) return 'https://via.placeholder.com/600';
    final first = media.first;
    if (first is Map && first.containsKey('image')) return first['image'] as String;
    if (first is Map && first.containsKey('url')) return first['url'] as String;
    if (first is String) return first;
    return 'https://via.placeholder.com/600';
  }

  int get _likeCount {
    final likes = _post?['likes'] as List<dynamic>? ?? [];
    return likes.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingPost && _post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)),
      );
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          title: Text('Post', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
        ),
        body: const Center(child: Text('Post not found')),
      );
    }

    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = _post?['caption'] as String? ?? '';
    final location = _post?['location'] as String?;
    final createdAt = _post?['created_at'] as String? ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).width,
                    child: Container(
                      color: theme.brightness == Brightness.dark ? Colors.black : Colors.grey.shade200,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: _displayImageUrl(),
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)),
                          errorWidget: (_, __, ___) => Icon(LucideIcons.imageOff, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _onAuthorTap,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: TextStyle(color: theme.colorScheme.primary))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _onAuthorTap,
                                child: Text(username, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                              if (location != null && location.isNotEmpty)
                                Text(location, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(icon: Icon(LucideIcons.ellipsis, color: theme.iconTheme.color), onPressed: () {}),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: caption),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_formatRelativeTime(createdAt), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingComments)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: DesignTokens.instaPink)))
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('No comments yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                    )
                  else
                    ..._comments.map((c) {
                      final u = c['user'] as Map<String, dynamic>?;
                      final un = u?['username'] as String? ?? 'user';
                      final uAvatar = u?['avatar_url'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              backgroundImage: uAvatar != null && uAvatar.isNotEmpty ? NetworkImage(uAvatar) : null,
                              child: uAvatar == null || uAvatar.isEmpty
                                  ? Text(un.isNotEmpty ? un[0].toUpperCase() : 'U', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyMedium,
                                      children: [
                                        TextSpan(text: '$un ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        TextSpan(text: c['content'] as String? ?? ''),
                                      ],
                                    ),
                                  ),
                                  Text(_formatRelativeTime(c['created_at'] as String? ?? ''), style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(icon: Icon(LucideIcons.heart, size: 14, color: theme.iconTheme.color), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          ],
                        ),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(_formatFullDate(createdAt), style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(LucideIcons.heart, color: _isLiked ? Colors.red : theme.iconTheme.color),
                  onPressed: () async {
                    final uid = Supabase.instance.client.auth.currentUser?.id;
                    if (uid == null || _post == null) return;
                    final rawLikes = _post!['likes'] as List<dynamic>? ?? [];
                    final current = rawLikes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                    final newLikes = _isLiked
                        ? current.where((e) => e['user_id'] != uid).toList()
                        : [...current, {'user_id': uid, 'like': true}];
                    final ok = await _svc.updatePostLikes(widget.postId, newLikes);
                    if (ok && mounted) await _load();
                  },
                ),
                IconButton(icon: Icon(LucideIcons.messageCircle, color: theme.iconTheme.color), onPressed: () {}),
                IconButton(icon: Icon(LucideIcons.send, color: theme.iconTheme.color), onPressed: () {}),
                const Spacer(),
                IconButton(icon: Icon(LucideIcons.bookmark, color: theme.iconTheme.color), onPressed: () {}),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
            child: Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: Icon(LucideIcons.smile, color: theme.iconTheme.color), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: TextStyle(color: theme.hintColor),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return TextButton(
                      onPressed: _postingComment || !hasText ? null : _postComment,
                      child: Text('Post', style: TextStyle(color: hasText ? DesignTokens.instaPink : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
