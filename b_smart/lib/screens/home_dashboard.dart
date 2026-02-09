import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feed_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
import '../widgets/post_detail_modal.dart';
import 'ads_screen.dart';
import 'promote_screen.dart';
import 'reels_screen.dart';
import 'story_viewer_screen.dart';
import '../utils/current_user.dart';

class HomeDashboard extends StatefulWidget {
  final int? initialIndex;

  const HomeDashboard({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final FeedService _feedService = FeedService();
  final SupabaseService _supabase = SupabaseService();
  final WalletService _walletService = WalletService();

  List<FeedPost> posts = [];
  List<Map<String, dynamic>> _storyUsers = [];
  bool _isLoading = true;
  List<StoryGroup> _storyGroups = [];
  int _currentIndex = 0;
  int _balance = 0;
  /// Current user profile from `users` table (same source as React web app) for header avatar.
  Map<String, dynamic>? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Use REST API-backed CurrentUser helper for the authenticated user ID.
    final currentUserId = await CurrentUser.id;
    final currentProfile = currentUserId != null ? await _supabase.getUserById(currentUserId) : null;
    // Same as React Home.jsx: fetch all posts, users(id, username, avatar_url), order by created_at desc
    final fetched = await _feedService.fetchFeedFromBackend(currentUserId: currentUserId);
    final users = await _supabase.fetchUsers(limit: 10, excludeUserId: currentUserId);
    final bal = await _walletService.getCoinBalance();
    final groups = _buildStoryGroupsFromUsers(users);
    if (mounted) {
      setState(() {
        _currentUserProfile = currentProfile;
        posts = fetched;
        _storyUsers = users;
        _storyGroups = groups;
        _balance = bal;
        _isLoading = false;
      });
      // Preload profile into Redux so ProfileScreen opens instantly
      if (currentUserId != null && currentProfile != null) {
        StoreProvider.of<AppState>(context).dispatch(SetProfile(currentProfile));
      }
    }
  }

  // Like toggle - same as React PostCard: update post.likes array on posts table
  void _onLikePost(FeedPost post) async {
    final currentUserId = await CurrentUser.id;
    if (currentUserId == null) return;
    final current = post.rawLikes ?? [];
    final newLikes = post.isLiked
        ? current.where((e) => e['user_id'] != currentUserId).toList()
        : [...current, {'user_id': currentUserId, 'like': true}];
    // Optimistic update (same as React)
    setState(() {
      final i = posts.indexWhere((p) => p.id == post.id);
      if (i != -1) {
        posts[i] = post.copyWith(
          isLiked: !post.isLiked,
          likes: newLikes.length,
          rawLikes: newLikes,
        );
      }
    });
    _supabase.updatePostLikes(post.id, newLikes).then((ok) {
      if (!ok && mounted) {
        // Revert on failure
        setState(() {
          final i = posts.indexWhere((p) => p.id == post.id);
          if (i != -1) posts[i] = post;
        });
      }
    });
  }

  void _onCommentPost(FeedPost post) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      Navigator.of(context).pushNamed('/post/${post.id}');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailModal(postId: post.id),
        ),
      );
    }
  }

  void _onSharePost(FeedPost post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share link copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSavePost(FeedPost post) {
    setState(() {
      final i = posts.indexWhere((p) => p.id == post.id);
      if (i != -1) {
        posts[i] = post.copyWith(isSaved: !post.isSaved);
      }
    });
  }

  void _onMorePost(BuildContext context, FeedPost post) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.not_interested_outlined),
              title: const Text('Not interested'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('We\'ll show you less like this')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector({required bool isDark}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        // TODO: hook up location picker.
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.mapPin,
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOME',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Plot No.20, 2nd Floor, Shivaram Nivas',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronDown,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  List<StoryGroup> _buildStoryGroupsFromUsers(List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    return users.map((u) {
      final username = (u['username'] ?? u['full_name'] ?? 'User').toString();
      final userId = (u['id'] ?? '').toString();
      return StoryGroup(
        userId: userId,
        userName: username,
        userAvatar: u['avatar_url'] as String?,
        isOnline: true,
        stories: [
          Story(
            id: 'story-$userId',
            userId: userId,
            userName: username,
            userAvatar: u['avatar_url'] as String?,
            mediaUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400',
            mediaType: StoryMediaType.image,
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
      );
    }).toList();
  }

  void _onStoryTap(int userIndex) {
    if (userIndex < 0 || userIndex >= _storyGroups.length) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          storyGroups: _storyGroups,
          initialIndex: userIndex,
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  void _onNavTap(int idx) {
    // Create (center) opens create modal: post vs reel choice (React parity)
    if (idx == 2) {
      _showCreateModal();
      return;
    }
    // Profile from sidebar (desktop)
    if (idx == 5) {
      Navigator.of(context).pushNamed('/profile');
      return;
    }
    setState(() {
      _currentIndex = idx;
    });
  }

  void _showCreateModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Create', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.image, color: Colors.white, size: 22),
                ),
                title: const Text('Create Post'),
                subtitle: Text('Photo or video', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Defer push to next frame so sheet closes first (matches React: modal overlay, no route conflict)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pushNamed('/create');
                  });
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.video, color: Colors.white, size: 22),
                ),
                title: const Text('Upload Reel'),
                subtitle: Text('Short video', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pushNamed('/create');
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final isFullScreen = _currentIndex == 3 || _currentIndex == 4; // Promote, Reels

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final appBarFg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final content = Scaffold(
      extendBody: true,
      backgroundColor: isFullScreen ? (isDark ? const Color(0xFF121212) : Colors.black) : null,
      appBar: isFullScreen
          ? null
          : AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [DesignTokens.instaPurple, DesignTokens.instaPink, DesignTokens.instaOrange],
                ).createShader(bounds),
                child: Text('b_smart', style: TextStyle(color: appBarFg, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'cursive')),
              ),
              elevation: 0,
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
              iconTheme: IconThemeData(color: appBarFg),
              actions: [
                if (!isDesktop)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pushNamed('/search'),
                          icon: Icon(LucideIcons.search, size: 24, color: appBarFg),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/wallet'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle),
                                  child: Icon(LucideIcons.wallet, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Text('$_balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: appBarFg)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(onPressed: () => Navigator.of(context).pushNamed('/notifications'), icon: Icon(LucideIcons.heart, size: 24, color: appBarFg)),
                            Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFFE8E8E8) : Colors.white, width: 1.5)))),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 12),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.transparent,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
                                backgroundImage: _currentUserProfile != null &&
                                        _currentUserProfile!['avatar_url'] != null &&
                                        (_currentUserProfile!['avatar_url'] as String).isNotEmpty
                                    ? NetworkImage(_currentUserProfile!['avatar_url'] as String)
                                    : null,
                                child: _currentUserProfile == null ||
                                        _currentUserProfile!['avatar_url'] == null ||
                                        (_currentUserProfile!['avatar_url'] as String).isEmpty
                                    ? Text(
                                        _currentUserProfile != null
                                            ? ((_currentUserProfile!['username'] ?? _currentUserProfile!['full_name'] ?? 'U') as String).isNotEmpty
                                                ? ((_currentUserProfile!['username'] ?? _currentUserProfile!['full_name'] ?? 'U') as String).substring(0, 1).toUpperCase()
                                                : 'U'
                                            : 'U',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: appBarFg),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home tab
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: DesignTokens.instaPink))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: _buildLocationSelector(isDark: isDark),
                        ),
                        StoriesRow(
                          users: _storyUsers,
                          onYourStoryTap: () {},
                          onUserStoryTap: _storyGroups.isEmpty ? null : _onStoryTap,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final p = posts[index];
                            return PostCard(
                              post: p,
                              onLike: () => _onLikePost(p),
                              onComment: () => _onCommentPost(p),
                              onShare: () => _onSharePost(p),
                              onSave: () => _onSavePost(p),
                              onMore: () => _onMorePost(context, p),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
          // Ads tab
          const AdsScreen(),
          // Placeholder for create (kept empty since create opens modal/route)
          Container(),
          // Promote tab
          const PromoteScreen(),
          // Reels tab
          const ReelsScreen(),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : BottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
    );

    if (isDesktop) {
      return Row(
        children: [
          Sidebar(
            currentIndex: _currentIndex,
            onNavTap: _onNavTap,
            onCreatePost: () => Navigator.of(context).pushNamed('/create'),
            onUploadReel: () => Navigator.of(context).pushNamed('/create'),
          ),
          Expanded(
            child: Stack(
              children: [
                content,
                if (!isFullScreen) ...[
                  Positioned(
                    top: 32,
                    right: 32,
                    child: _DesktopNotificationsButton(),
                  ),
                  Positioned(
                    bottom: 32,
                    right: 32,
                    child: _FloatingWallet(balance: _balance),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return content;
  }
}

class _DesktopNotificationsButton extends StatefulWidget {
  @override
  State<_DesktopNotificationsButton> createState() => _DesktopNotificationsButtonState();
}

class _DesktopNotificationsButtonState extends State<_DesktopNotificationsButton> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _showDropdown = true),
      onExit: (_) => setState(() => _showDropdown = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: surfaceColor,
            elevation: 4,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _showDropdown = !_showDropdown),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(LucideIcons.heart, size: 20, color: fgColor)),
                    Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFFE8E8E8) : Colors.white, width: 1.5)))),
                  ],
                ),
              ),
            ),
          ),
          if (_showDropdown)
            Positioned(
              top: 48,
              right: 0,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: fgColor)),
                            GestureDetector(onTap: () {}, child: Text('Mark all read', style: TextStyle(fontSize: 12, color: DesignTokens.instaPink, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            _NotificationTile(icon: LucideIcons.bell, iconColor: Colors.blue, title: 'New follower: Sarah', time: '2 min ago'),
                            _NotificationTile(icon: LucideIcons.heart, iconColor: DesignTokens.instaPink, title: 'Mike liked your post', time: '1 hour ago'),
                            _NotificationTile(icon: LucideIcons.messageCircle, iconColor: DesignTokens.instaPurple, title: 'Anna commented: "Amazing!"', time: '2 hours ago'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _NotificationTile({required this.icon, required this.iconColor, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;
    return ListTile(
      leading: CircleAvatar(backgroundColor: iconColor.withAlpha(40), child: Icon(icon, size: 14, color: iconColor)),
      title: Text(title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
      subtitle: Text(time, style: TextStyle(fontSize: 12, color: mutedColor)),
    );
  }
}

class _FloatingWallet extends StatelessWidget {
  final int balance;

  const _FloatingWallet({required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/wallet'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: DesignTokens.instaPink.withAlpha(80), blurRadius: 8)]),
                child: Icon(LucideIcons.wallet, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600)),
                  Text('$balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fgColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
