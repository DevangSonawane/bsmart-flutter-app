import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/supabase_service.dart';
import '../theme/design_tokens.dart';

/// Modal matching React PostDetailModal: image left, details + comments right.
class PostDetailModal extends StatefulWidget {
  final String postId;
  final VoidCallback? onClose;

  const PostDetailModal({Key? key, required this.postId, this.onClose}) : super(key: key);

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _postUser;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingPost = true;
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _isLiked = false;
  int _likeCount = 0;
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
    final rawLikes = post['likes'] as List<dynamic>? ?? [];
    final likesList = rawLikes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isLiked = currentUserId != null && likesList.any((e) => e['user_id'] == currentUserId);
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = comments;
        _isLiked = isLiked;
        _likeCount = likesList.length;
        _loadingPost = false;
        _loadingComments = false;
      });
    }
  }

  Future<void> _handleLike() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _post == null) return;
    final rawLikes = _post!['likes'] as List<dynamic>? ?? [];
    final current = rawLikes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final newLikes = _isLiked
        ? current.where((e) => e['user_id'] != userId).toList()
        : [...current, {'user_id': userId, 'like': true}];
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = newLikes.length;
    });
    final ok = await _svc.updatePostLikes(widget.postId, newLikes);
    if (!ok && mounted) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount = current.length;
      });
    } else if (ok && mounted) {
      setState(() => _post = {..._post!, 'likes': newLikes});
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

  static String formatRelativeTime(String dateString) {
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

  String _displayImageUrl() {
    final media = _post?['media'] as List<dynamic>?;
    if (media == null || media.isEmpty) return 'https://via.placeholder.com/600';
    final first = media.first;
    if (first is Map && first.containsKey('image')) return first['image'] as String;
    if (first is Map && first.containsKey('url')) return first['url'] as String;
    if (first is String) return first;
    return 'https://via.placeholder.com/600';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPost && _post == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop())),
        body: const Center(child: Text('Post not found')),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 1200, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 0 : 12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Flexible(
                  child: isMobile
                      ? Column(
                          children: [
                            Expanded(flex: 2, child: _buildImage()),
                            Expanded(flex: 3, child: _buildDetails()),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 400, child: _buildImage()),
                            Expanded(child: _buildDetails()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      color: Colors.black,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: _displayImageUrl(),
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorWidget: (_, __, ___) => Icon(LucideIcons.imageOff, size: 64, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = _post?['caption'] as String? ?? '';
    final location = _post?['location'] as String?;
    final createdAt = _post?['created_at'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    final userId = _postUser?['id'] as String?;
                    if (userId != null && userId.isNotEmpty) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/profile/$userId');
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U') : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                            if (location != null && location.isNotEmpty) Text(location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(icon: Icon(LucideIcons.ellipsis), onPressed: () {}),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black, fontSize: 14),
                              children: [
                                TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: caption),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(formatRelativeTime(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loadingComments)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: DesignTokens.instaPink)))
                else if (_comments.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No comments yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))))
                else
                  ..._comments.map((c) {
                    final u = c['user'] as Map<String, dynamic>?;
                    final un = u?['username'] as String? ?? 'user';
                    final uAvatar = u?['avatar_url'] as String?;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 14, backgroundImage: uAvatar != null ? NetworkImage(uAvatar) : null, child: uAvatar == null ? Text(un.isNotEmpty ? un[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black, fontSize: 14),
                                    children: [
                                      TextSpan(text: '$un ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      TextSpan(text: c['content'] as String? ?? ''),
                                    ],
                                  ),
                                ),
                                Text(formatRelativeTime(c['created_at'] as String? ?? ''), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(icon: Icon(LucideIcons.heart, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(icon: Icon(LucideIcons.heart, color: _isLiked ? Colors.red : Colors.black87), onPressed: _handleLike),
              IconButton(icon: Icon(LucideIcons.messageCircle), onPressed: () {}),
              IconButton(icon: Icon(LucideIcons.send), onPressed: () {}),
              const Spacer(),
              IconButton(icon: Icon(LucideIcons.bookmark), onPressed: () {}),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Text(
            _formatFullDate(createdAt),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(icon: Icon(LucideIcons.smile), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(hintText: 'Add a comment...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _commentController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return TextButton(
                    onPressed: _postingComment || !hasText ? null : _postComment,
                    child: Text('Post', style: TextStyle(color: !hasText ? Colors.grey : DesignTokens.instaPink, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFullDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    return '${date.month} ${date.day}, ${date.year}';
  }
}
