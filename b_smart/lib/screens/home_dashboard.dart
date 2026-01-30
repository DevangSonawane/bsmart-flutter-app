import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../services/feed_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
import 'ads_screen.dart';
import 'promote_screen.dart';
import 'reels_screen.dart';
import 'story_viewer_screen.dart';

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
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final currentProfile = currentUserId != null ? await _supabase.getUserById(currentUserId) : null;
    final fetched = await _feedService.fetchFeedFromBackend();
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
    }
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
    // Create (center) opens create route
    if (idx == 2) {
      Navigator.of(context).pushNamed('/create');
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final isFullScreen = _currentIndex == 3 || _currentIndex == 4; // Promote, Reels

    final content = Scaffold(
      backgroundColor: isFullScreen ? Colors.black : null,
      appBar: isFullScreen
          ? null
          : AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [DesignTokens.instaPurple, DesignTokens.instaPink, DesignTokens.instaOrange],
                ).createShader(bounds),
                child: const Text('b_smart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'cursive')),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              actions: [
                if (!isDesktop)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/wallet'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle),
                                  child: Icon(LucideIcons.wallet.localLucide, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Text('$_balance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(onPressed: () => Navigator.of(context).pushNamed('/notifications'), icon: Icon(LucideIcons.heart.localLucide, size: 24)),
                            Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.of(context).pushNamed('/notifications'), icon: Icon(LucideIcons.messageCircle.localLucide, size: 24)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 12),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.transparent,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.grey.shade200,
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
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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
                            return PostCard(post: p);
                          },
                        ),
                        const SizedBox(height: 88),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _showDropdown = true),
      onExit: (_) => setState(() => _showDropdown = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white,
            elevation: 4,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _showDropdown = !_showDropdown),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade100)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(LucideIcons.heart.localLucide, size: 20, color: Colors.black87)),
                    Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                            _NotificationTile(icon: LucideIcons.bell.localLucide, iconColor: Colors.blue, title: 'New follower: Sarah', time: '2 min ago'),
                            _NotificationTile(icon: LucideIcons.heart.localLucide, iconColor: DesignTokens.instaPink, title: 'Mike liked your post', time: '1 hour ago'),
                            _NotificationTile(icon: LucideIcons.messageCircle.localLucide, iconColor: DesignTokens.instaPurple, title: 'Anna commented: "Amazing!"', time: '2 hours ago'),
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
    return ListTile(
      leading: CircleAvatar(backgroundColor: iconColor.withAlpha(40), child: Icon(icon, size: 14, color: iconColor)),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    );
  }
}

class _FloatingWallet extends StatelessWidget {
  final int balance;

  const _FloatingWallet({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/wallet'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: DesignTokens.instaPink.withAlpha(80), blurRadius: 8)]),
                child: Icon(LucideIcons.wallet.localLucide, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                  Text('$balance', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

