import 'package:flutter/material.dart';
import 'dart:async';
import '../models/feed_post_model.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';
import '../services/wallet_service.dart';
import '../services/boost_service.dart';
import '../services/user_account_service.dart';
import '../models/user_account_model.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'story_viewer_screen.dart';
import 'wallet_screen.dart';
import 'boost_post_screen.dart';

class InstagramFeedScreen extends StatefulWidget {
  const InstagramFeedScreen({super.key});

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen> {
  final FeedService _feedService = FeedService();
  final WalletService _walletService = WalletService();
  
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollOffset = 0;
  
  List<FeedPost> _feedPosts = [];
  List<StoryGroup> _stories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      if (_isHeaderVisible) setState(() => _isHeaderVisible = false);
    } else if (currentOffset < _lastScrollOffset) {
      if (!_isHeaderVisible) setState(() => _isHeaderVisible = true);
    }
    _lastScrollOffset = currentOffset;
    if (currentOffset >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final posts = _feedService.getPersonalizedFeed(
      followedUserIds: ['user-2', 'user-3', 'user-4', 'user-5'],
      userInterests: ['technology', 'photography', 'art'],
    );
    final stories = _feedService.getStories();
    setState(() {
      _feedPosts = posts;
      _stories = stories;
      _isLoading = false;
    });
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final morePosts = _feedService.getPersonalizedFeed();
    setState(() {
      _feedPosts.addAll(morePosts);
      _isLoadingMore = false;
    });
  }

  void _handleLike(FeedPost post) {
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _feedPosts[index] = _feedService.toggleLike(post);
      }
    });
  }

  void _handleSave(FeedPost post) {
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _feedPosts[index] = _feedService.toggleSave(post);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFeed,
              color: InstagramTheme.primaryPink,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    floating: true,
                    pinned: false,
                    snap: true,
                    backgroundColor: InstagramTheme.backgroundWhite,
                    elevation: 0,
                    leading: _isHeaderVisible ? _buildProfileIcon() : null,
                    title: _isHeaderVisible ? _buildSearchBar() : null,
                    actions: _isHeaderVisible ? _buildHeaderActions() : null,
                  ),
                  SliverToBoxAdapter(child: _buildStoriesSection()),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < _feedPosts.length) {
                          return _buildPostCard(_feedPosts[index]);
                        } else if (_isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      childCount: _feedPosts.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileIcon() {
    final user = _feedService.getCurrentUser();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Center(
        child: ClayContainer(
          width: 36,
          height: 36,
          borderRadius: 18,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.transparent,
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                color: InstagramTheme.primaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ClayContainer(
        borderRadius: 20,
        color: InstagramTheme.surfaceWhite,
        child: TextField(
          style: const TextStyle(color: InstagramTheme.textBlack),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: InstagramTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.search, size: 20, color: InstagramTheme.textGrey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      IconButton(
        icon: const Icon(Icons.favorite_border, color: InstagramTheme.textBlack),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          );
        },
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: ClayContainer(
            height: 32,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: InstagramTheme.primaryPink, size: 16),
                const SizedBox(width: 4),
                FutureBuilder<int>(
                  future: _walletService.getCoinBalance(),
                  initialData: 0,
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: InstagramTheme.textBlack,
                        fontSize: 12,
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildStoriesSection() {
    if (_stories.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length,
        itemBuilder: (context, index) => _buildStoryItem(_stories[index]),
      ),
    );
  }

  Widget _buildStoryItem(StoryGroup storyGroup) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(
              storyGroups: _stories,
              initialIndex: _stories.indexOf(storyGroup),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                ClayContainer(
                  width: 74,
                  height: 74,
                  borderRadius: 37,
                  color: InstagramTheme.surfaceWhite,
                  child: Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage('https://via.placeholder.com/150'), // Replace with actual
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          storyGroup.userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: InstagramTheme.surfaceWhite, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              storyGroup.userName.split(' ').first,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(FeedPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: ClayContainer(
        borderRadius: 24,
        color: InstagramTheme.surfaceWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post),
            _buildMediaSection(post),
            _buildActionBar(post),
            if (post.likes > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${post.likes} likes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (post.caption != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: '${post.userName} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(FeedPost post) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: InstagramTheme.dividerGrey,
            child: Text(
              post.userName[0].toUpperCase(),
              style: const TextStyle(
                color: InstagramTheme.primaryPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.userName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (post.isAd) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Sponsored',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: InstagramTheme.primaryPink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: InstagramTheme.textGrey, size: 24),
            onPressed: () => _showMoreOptions(context, post),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(FeedPost post) {
    return Container(
      height: 300,
      width: double.infinity,
      color: InstagramTheme.dividerGrey,
      child: const Center(
        child: Icon(Icons.image, size: 60, color: InstagramTheme.textGrey),
      ),
    );
  }

  Widget _buildActionBar(FeedPost post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? InstagramTheme.errorRed : InstagramTheme.textBlack,
              size: 28,
            ),
            onPressed: () => _handleLike(post),
          ),
          IconButton(
            icon: const Icon(Icons.comment_outlined, color: InstagramTheme.textBlack, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined, color: InstagramTheme.textBlack, size: 28),
            onPressed: () {},
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: post.isSaved ? InstagramTheme.primaryPink : InstagramTheme.textBlack,
              size: 28,
            ),
            onPressed: () => _handleSave(post),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, FeedPost post) {
    final boostService = BoostService();
    final accountService = UserAccountService();
    final currentAccount = accountService.getCurrentAccount();
    final canBoost = currentAccount.accountType != AccountType.regular;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canBoost)
              ListTile(
                leading: const Icon(Icons.trending_up),
                title: const Text('Boost Post'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BoostPostScreen(
                        postId: post.id,
                        contentType: 'post',
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.not_interested),
              title: const Text('Not Interested'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('We\'ll show you less like this')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
