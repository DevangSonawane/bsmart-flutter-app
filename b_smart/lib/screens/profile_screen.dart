import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'reels_screen.dart';
import '../services/reels_service.dart';
import '../models/reel_model.dart';
import '../services/supabase_service.dart';
import '../widgets/profile_header.dart';
import '../widgets/posts_grid.dart';
import '../widgets/post_detail_modal.dart';
import '../models/feed_post_model.dart';
import '../theme/design_tokens.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../utils/current_user.dart';
import '../services/user_account_service.dart';
import '../services/wallet_service.dart';

/// Heroicons badge-check (same as React web app verified badge)
const String _verifiedBadgeSvg = r'''
<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.498 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z"/>
</svg>
''';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _profile;
  List<FeedPost> _posts = [];
  bool _loading = true;
  bool _usedCache = false;
  final ReelsService _reelsService = ReelsService();
  List<Reel> _userReels = [];
  static const int _initialPostsLimit = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only hydrate from Redux cache when viewing own profile (no explicit userId).
    final isMe = widget.userId == null;
    if (!isMe || _usedCache) return;
    final store = StoreProvider.of<AppState>(context);
    final cached = store.state.profileState.profile;
    if (cached == null) return;
    _usedCache = true;
    setState(() {
      _profile = Map<String, dynamic>.from(cached);
      _loading = false;
    });
  }

  Future<void> _load() async {
    // Use REST API-backed CurrentUser helper for the authenticated user ID,
    // falling back to Supabase only internally within ApiClient.
    final targetId = widget.userId ?? await CurrentUser.id;
    if (targetId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    // Load profile and posts in parallel from the REST API.
    final profileFuture = _svc.getUserById(targetId);
    final postsFuture = _svc.getUserPosts(targetId, limit: _initialPostsLimit);
    final walletFuture = (widget.userId == null) ? WalletService().getCoinBalance() : Future.value(0);
    
    // Also fetch UserAccount info (e.g. followers, account type)
    final userAccount = UserAccountService().getAccount(targetId);

    final results = await Future.wait([
      profileFuture,
      postsFuture,
      walletFuture,
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final rawPosts = results[1] as List<Map<String, dynamic>>;
    final walletBalance = results[2] as int;

    final posts = rawPosts.map((item) {
      final media = item['media'] as List<dynamic>? ?? [];
      final mediaUrls = media.map((m) {
        if (m is String) return m;
        if (m is Map) {
          if (m.containsKey('image')) return m['image'] as String;
          if (m.containsKey('url')) return m['url'] as String;
        }
        return m.toString();
      }).cast<String>().toList();
      return FeedPost(
        id: item['id'] as String,
        userId: item['user_id'] as String,
        userName: (item['users'] as Map<String, dynamic>?)?['username'] as String? ?? 'user',
        mediaType: PostMediaType.image,
        mediaUrls: mediaUrls,
        caption: item['caption'] as String?,
        hashtags: ((item['hashtags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
        createdAt: DateTime.parse(item['created_at'] as String),
      );
    }).toList();

    if (mounted) {
      final merged = {
        ...?profile,
        'posts_count': (profile?['posts_count'] as int?) ?? posts.length,
        // Followers / following / wallet fields are expected from the REST API
        // payload; fall back to UserAccountService or 0 if not provided.
        'followers_count': (profile?['followers_count'] as int?) ?? userAccount?.followers ?? 0,
        'following_count': (profile?['following_count'] as int?) ?? 0,
        'wallet_balance': (profile?['wallet_balance'] as int?) ?? walletBalance,
        'account_type': userAccount?.accountType.toString().split('.').last,
        'engagement_score': userAccount?.engagementScore,
      };
      setState(() {
        _profile = merged;
        _posts = posts;
        _userReels =
            _reelsService.getReels().where((r) => r.userId == targetId).toList();
        _loading = false;
      });
      // Cache own profile in Redux for instant load next time
      if (widget.userId == null) {
        StoreProvider.of<AppState>(context).dispatch(SetProfile(merged));
      }
    }
  }

  void _onEdit() async {
    final targetId = widget.userId ?? await CurrentUser.id;
    if (!mounted || targetId == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
      return EditProfileScreen(userId: targetId);
    })).then((_) => _load());
  }

  void _onFollow() async {
    final meId = await CurrentUser.id;
    final targetId = widget.userId;
    if (meId == null || targetId == null) return;
    await _svc.toggleFollow(meId, targetId);
    _load();
  }

  void _onPostTap(FeedPost p) {
    // Post detail modal implemented in task 5
    _showPostDetail(p.id);
  }

  void _showPostDetail(String postId) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      Navigator.of(context).pushNamed('/post/$postId');
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PostDetailModal(
            postId: postId,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  static const List<({String title, String img})> _highlights = [
    (title: 'Travel', img: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=150&h=150&fit=crop'),
    (title: 'Work', img: 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=150&h=150&fit=crop'),
    (title: 'Life', img: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=150&h=150&fit=crop'),
    (title: 'Tech', img: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=150&h=150&fit=crop'),
    (title: 'Music', img: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=150&h=150&fit=crop'),
  ];

  Widget _buildHighlights() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _highlights.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          if (i == _highlights.length) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
                  ),
                  child: Icon(LucideIcons.plus, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 6),
                const Text('New', style: TextStyle(fontSize: 12)),
              ],
            );
          }
          final h = _highlights[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.network(h.img, width: 60, height: 60, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(width: 72, child: Text(h.title, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    }
    final username = _profile?['username'] as String? ?? 'user';
    final fullName = _profile?['full_name'] as String?;
    final bio = _profile?['bio'] as String?;
    final avatar = _profile?['avatar_url'] as String?;
    final postsCount = (_profile?['posts_count'] as int?) ?? _posts.length;
    final followers = (_profile?['followers_count'] as int?) ?? 0;
    final following = (_profile?['following_count'] as int?) ?? 0;
    // When no explicit userId is provided we are viewing our own profile.
    final isMe = widget.userId == null;

    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !isMe,
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(username, style: TextStyle(color: fgColor)),
              const SizedBox(width: 4),
              SvgPicture.string(
                _verifiedBadgeSvg,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(Color(0xFF3B82F6), BlendMode.srcIn),
              ),
            ],
          ),
          actions: [
            if (isMe) ...[
              IconButton(icon: Icon(LucideIcons.plus, color: fgColor), onPressed: () => Navigator.of(context).pushNamed('/create')),
              IconButton(icon: Icon(LucideIcons.menu, color: fgColor), onPressed: () => Navigator.of(context).pushNamed('/settings')),
            ],
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: ProfileHeader(
                username: username,
                fullName: fullName,
                bio: bio,
                avatarUrl: avatar,
                posts: postsCount,
                followers: followers,
                following: following,
                isMe: isMe,
                onEdit: isMe ? _onEdit : null,
                onFollow: isMe ? null : _onFollow,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildHighlights(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  tabs: [
                    Tab(icon: Icon(LucideIcons.layoutGrid)),
                    Tab(icon: Icon(LucideIcons.video)),
                    Tab(icon: Icon(LucideIcons.bookmark)),
                  ],
                  indicator: UnderlineTabIndicator(borderSide: BorderSide(width: 1.5, color: DesignTokens.instaPink)),
                  labelColor: DesignTokens.instaPink,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _posts.isEmpty
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.dividerColor, width: 2)),
                              child: Icon(LucideIcons.layoutGrid, size: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(height: 16),
                            Text('No Posts Yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: fgColor)),
                            const SizedBox(height: 8),
                            Text('When you share photos, they will appear on your profile.', style: TextStyle(color: theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600, fontSize: 14), textAlign: TextAlign.center),
                            if (isMe) ...[
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.of(context).pushNamed('/create'),
                                child: Text('Share your first photo', style: TextStyle(color: DesignTokens.instaPink)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: PostsGrid(posts: _posts, onTap: (p) => _onPostTap(p)),
                    ),
              _userReels.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No reels yet', style: TextStyle(color: fgColor))))
                  : ListView.builder(
                      itemCount: _userReels.length,
                      itemBuilder: (ctx, i) {
                        final r = _userReels[i];
                        return ListTile(
                          leading: r.thumbnailUrl != null ? Image.network(r.thumbnailUrl!) : Icon(LucideIcons.video, color: fgColor),
                          title: Text(r.caption ?? '', style: TextStyle(color: fgColor)),
                          subtitle: Text('${r.views} views', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReelsScreen())),
                        );
                      },
                    ),
              Center(child: Text('Saved', style: TextStyle(color: fgColor))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class EditProfileScreen extends StatefulWidget {
  final String? userId;
  const EditProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseService _svc = SupabaseService();
  final _usernameCtl = TextEditingController();
  final _fullNameCtl = TextEditingController();
  final _bioCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  bool _loading = true;
  bool _uploading = false;
  String? _avatarUrl;
  Map<String, dynamic>? _profile;
  String? _effectiveUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.userId != null && widget.userId!.isNotEmpty
        ? widget.userId
        : await CurrentUser.id;
    
    if (uid == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _effectiveUserId = uid;

    final profile = await _svc.getUserById(uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _usernameCtl.text = profile?['username'] ?? '';
        _fullNameCtl.text = profile?['full_name'] ?? '';
        _bioCtl.text = profile?['bio'] ?? '';
        _phoneCtl.text = profile?['phone'] ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        _loading = false;
      });
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ext = xfile.path.split('.').last;
      final path = '$_effectiveUserId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final res = await _svc.uploadFile('avatars', path, bytes);
      if (mounted) {
        setState(() {
          _avatarUrl = res['fileUrl'] as String?;
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final updates = {
      'username': _usernameCtl.text.trim(),
      'full_name': _fullNameCtl.text.trim(),
      'bio': _bioCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
      if (_avatarUrl != null) 'avatar_url': _avatarUrl,
    };
    try {
      if (_effectiveUserId == null) throw 'User ID not found';
      await _svc.updateUserProfile(_effectiveUserId!, updates);
      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    if (_loading && _profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: fgColor), onPressed: () => Navigator.of(context).pop()),
        title: Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: fgColor)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: fgColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(_loading ? 'Saving...' : 'Save', style: TextStyle(fontWeight: FontWeight.w600, color: _loading ? Colors.grey : DesignTokens.instaPink)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _uploading ? null : _uploadAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: DesignTokens.instaGradient,
                      boxShadow: [BoxShadow(color: DesignTokens.instaPink.withAlpha(80), blurRadius: 8)],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.cardColor),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: _avatarUrl != null
                            ? Image.network(_avatarUrl!, width: 86, height: 86, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderAvatar())
                            : _placeholderAvatar(),
                      ),
                    ),
                  ),
                  if (_uploading) Positioned.fill(child: Container(color: Colors.black38, child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
                  if (!_uploading) Positioned(bottom: 0, right: 0, child: Icon(LucideIcons.camera, size: 20, color: fgColor)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _uploading ? null : _uploadAvatar,
              child: Text(_uploading ? 'Uploading...' : 'Change Profile Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DesignTokens.instaPink)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _fullNameCtl,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: theme.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameCtl,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(labelText: 'Username', filled: true, fillColor: theme.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtl,
              maxLines: 3,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(labelText: 'Bio', hintText: 'Write something about yourself...', filled: true, fillColor: theme.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(labelText: 'Phone', filled: true, fillColor: theme.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderAvatar() {
    final theme = Theme.of(context);
    final name = _fullNameCtl.text.trim().isNotEmpty ? _fullNameCtl.text.trim() : _usernameCtl.text.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    return Container(color: theme.cardColor, child: Center(child: Text(initial, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))));
  }
}

