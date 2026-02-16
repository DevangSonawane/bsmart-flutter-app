import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feed_post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import '../config/api_config.dart';
import '../theme/design_tokens.dart';

class PostCard extends StatefulWidget {
  final FeedPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  const PostCard({
    Key? key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onFollow,
    this.onMore,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtl;
  Future<void>? _initVideo;
  Map<String, String>? _imageHeaders;
  String? _resolvedImageUrl;
  double? _mediaAspect;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _isHeartAnimating = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartController);
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_heartController);
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _isHeartAnimating = false;
      }
    });
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() {
          _imageHeaders = {'Authorization': 'Bearer $token'};
        });
        // Re-run media setup so images/videos initialize with headers
        _setupMedia();
      }
    });
    _setupMedia();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFirst = oldWidget.post.mediaUrls.isNotEmpty ? oldWidget.post.mediaUrls.first : '';
    final newFirst = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
    if (oldWidget.post.id != widget.post.id ||
        oldFirst != newFirst ||
        oldWidget.post.mediaType != widget.post.mediaType) {
      _disposeVideo();
      _setupMedia();
    }
  }
  bool _likeAnim = false;
  void _onLikePressed() {
    _toggleLike();
  }

  void _toggleLike({bool onlyLike = false}) {
    final shouldLike = !widget.post.isLiked;
    if (onlyLike && !shouldLike) return;
    setState(() => _likeAnim = true);
    widget.onLike?.call();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _likeAnim = false);
    });
  }

  void _onMediaDoubleTap() {
    if (_isHeartAnimating) return;
    _toggleLike(onlyLike: true);
    _isHeartAnimating = true;
    _heartController.forward(from: 0);
  }

  void _setupMedia() {
    if (widget.post.mediaType.name == 'video' || widget.post.mediaType.name == 'reel') {
      final url = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
      if (url.isNotEmpty) _initVideoFromCandidates(_candidateUrls(url));
    } else {
      final url = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
      if (url.isNotEmpty) _resolveImageUrl(url);
    }
  }

  void _disposeVideo() {
    _videoCtl?.dispose();
    _videoCtl = null;
    _initVideo = null;
    _mediaAspect = null;
  }

  @override
  void dispose() {
    _heartController.dispose();
    _disposeVideo();
    super.dispose();
  }

  List<String> _candidateUrls(String url) {
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    String abs = url;
    if (!abs.startsWith('http://') && !abs.startsWith('https://')) {
      abs = url.startsWith('/') ? '$origin$url' : '$origin/$url';
    }
    final alts = <String>[abs];
    if (abs.startsWith('http://')) {
      alts.add(abs.replaceFirst('http://', 'https://'));
    }
    if (abs.contains('/api/uploads/')) {
      alts.add(abs.replaceFirst('/api/uploads/', '/uploads/'));
    } else if (abs.contains('/uploads/')) {
      alts.add(abs.replaceFirst('/uploads/', '/api/uploads/'));
    }
    return alts.toSet().toList();
  }

  Future<void> _resolveImageUrl(String url) async {
    final headers = _imageHeaders ?? {};
    final candidates = _candidateUrls(url);
    // If we don't yet have headers, skip HEAD probe and use first candidate;
    // CachedNetworkImage will fetch with headers once available and cacheKey changes.
    if (headers.isEmpty) {
      if (mounted) setState(() => _resolvedImageUrl = candidates.first);
      return;
    }
    for (final u in candidates) {
      try {
        final resp = await http.get(
          Uri.parse(u),
          headers: {
            ...headers,
            'Range': 'bytes=0-0',
            'Accept': 'image/*',
          },
        ).timeout(const Duration(seconds: 8));
        final ok = (resp.statusCode >= 200 && resp.statusCode < 300) || resp.statusCode == 206;
        if (ok) {
          if (!mounted) return;
          setState(() => _resolvedImageUrl = u);
          return;
        }
      } catch (_) {}
    }
    // Fallback: try plain GET with headers (servers that disallow Range)
    for (final u in candidates) {
      try {
        final resp = await http.get(
          Uri.parse(u),
          headers: {
            ...headers,
            'Accept': 'image/*',
          },
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          if (!mounted) return;
          setState(() => _resolvedImageUrl = u);
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _resolvedImageUrl = candidates.first);
  }

  void _computeImageAspect(ImageProvider provider) {
    final imageStream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) {
        final ar = w / h;
        if (mounted) setState(() => _mediaAspect = _normalizedAspect(ar));
      }
      imageStream.removeListener(listener!);
    }, onError: (_, __) {
      imageStream.removeListener(listener!);
    });
    imageStream.addListener(listener);
  }

  double _normalizedAspect(double raw) {
    if (raw.isNaN || raw <= 0) return 1.0;
    if (widget.post.isAd) return 1.0;
    if (raw < 0.9) return 4 / 5;
    if (raw > 1.2) return 16 / 9;
    return 1.0;
  }

  Future<void> _initVideoFromCandidates(List<String> candidates) async {
    // Ensure headers are ready; if not, fetch token quickly
    if (_imageHeaders == null) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        if (mounted) setState(() {
          _imageHeaders = {'Authorization': 'Bearer $token'};
        });
      }
    }
    final headers = _imageHeaders ?? {};
    for (final u in candidates) {
      try {
        _videoCtl?.dispose();
        _videoCtl = VideoPlayerController.networkUrl(Uri.parse(u), httpHeaders: headers);
        await _videoCtl!.initialize();
        _videoCtl!.setLooping(true);
        _videoCtl!.setVolume(0);
        _videoCtl!.play();
        if (mounted) {
          setState(() {
            _mediaAspect = _normalizedAspect(_videoCtl!.value.aspectRatio);
          });
        }
        return;
      } catch (_) {
        // Try next candidate
      }
    }
    // If all candidates fail, show placeholder by leaving controller null
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayName = post.fullName?.trim().isNotEmpty == true
        ? post.fullName!
        : post.userName;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: post.userId.isNotEmpty
                        ? () => Navigator.of(context).pushNamed('/profile/${post.userId}')
                        : null,
                    borderRadius: BorderRadius.circular(24),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onMore ?? () {},
                  icon: Icon(LucideIcons.ellipsis, size: 24, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          if (post.mediaUrls.isNotEmpty)
            AspectRatio(
              aspectRatio: 1.0, // Square container like Instagram
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _onMediaDoubleTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      color: isDark ? Colors.black : Colors.grey.shade200,
                      child: post.isAd
                          ? CachedNetworkImage(
                              imageUrl: _resolvedImageUrl ?? post.mediaUrls.first,
                              cacheKey:
                                  '${_resolvedImageUrl ?? post.mediaUrls.first}#${_imageHeaders?['Authorization'] ?? ''}',
                              httpHeaders: _imageHeaders,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              placeholder: (ctx, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DesignTokens.instaPink,
                                ),
                              ),
                              errorWidget: (ctx, url, err) => Center(
                                child: Icon(LucideIcons.imageOff, size: 48, color: mutedColor),
                              ),
                            )
                          : (post.mediaType.name == 'video' || post.mediaType.name == 'reel')
                              ? (_videoCtl != null
                                  ? FutureBuilder(
                                      future: _initVideo,
                                      builder: (ctx, snap) {
                                        if (snap.connectionState != ConnectionState.done) {
                                          return Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: DesignTokens.instaPink,
                                            ),
                                          );
                                        }
                                        return Center(
                                          child: AspectRatio(
                                            aspectRatio: _videoCtl!.value.aspectRatio,
                                            child: VideoPlayer(_videoCtl!),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: DesignTokens.instaPink,
                                      ),
                                    ))
                              : CachedNetworkImage(
                                  imageUrl: _resolvedImageUrl ?? post.mediaUrls.first,
                                  cacheKey:
                                      '${_resolvedImageUrl ?? post.mediaUrls.first}#${_imageHeaders?['Authorization'] ?? ''}',
                                  httpHeaders: _imageHeaders,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  placeholder: (ctx, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DesignTokens.instaPink,
                                    ),
                                  ),
                                  errorWidget: (ctx, url, err) => Center(
                                    child: Icon(LucideIcons.imageOff, size: 48, color: mutedColor),
                                  ),
                                ),
                    ),
                    IgnorePointer(
                      child: FadeTransition(
                        opacity: _heartOpacity,
                        child: ScaleTransition(
                          scale: _heartScale,
                          child: Icon(
                            LucideIcons.heart,
                            size: 96,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),
                  ],
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
            padding: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 0.5),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _likeAnim ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton(
                    onPressed: _onLikePressed,
                    icon: Icon(
                      post.isLiked ? Icons.favorite : LucideIcons.heart,
                      size: 28,
                      color: post.isLiked ? Colors.red : textColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ),
                IconButton(
                  onPressed: widget.onComment ?? () {},
                  icon: Icon(LucideIcons.messageCircle, size: 26, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  onPressed: widget.onShare ?? () {},
                  icon: Icon(LucideIcons.send, size: 26, color: textColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onFollow ?? () {},
                  icon: Icon(
                    post.isFollowed ? LucideIcons.userCheck : LucideIcons.userPlus,
                    size: 26,
                    color: textColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
                IconButton(
                  onPressed: widget.onSave ?? () {},
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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

          // Comments preview line: "View all X comments"
          if (post.comments > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: GestureDetector(
                onTap: widget.onComment,
                child: Text(
                  'View all ${post.comments} ${post.comments == 1 ? 'comment' : 'comments'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Time posted (below caption, Instagram style)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 12),
            child: Text(
              _formatTimeAgo(post.createdAt),
              style: TextStyle(
                fontSize: 10,
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
