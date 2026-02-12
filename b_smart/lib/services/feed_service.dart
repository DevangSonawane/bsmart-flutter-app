import '../api/api.dart';
import '../config/api_config.dart';
import '../models/feed_post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';

class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;

  FeedService._internal();

  final PostsApi _postsApi = PostsApi();
  final AuthApi _authApi = AuthApi();
  String _absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConfig.baseUrl;
    final baseUri = Uri.parse(base);
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    if (url.startsWith('/')) return '$origin$url';
    return '$origin/$url';
  }
  String _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    var u = url.trim();
    u = u.replaceAll('\\', '/');
    final lower = u.toLowerCase();
    final isLikelyFile =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.mp4');
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      if (!u.startsWith('/')) {
        if (isLikelyFile) {
          if (u.startsWith('uploads/') || u.contains('/')) {
            u = '/$u';
          } else {
            u = '/uploads/$u';
          }
        } else {
          u = '/$u';
        }
      }
    }
    return _absoluteUrl(u);
  }

  // Get personalized feed with ranking
  List<FeedPost> getPersonalizedFeed({
    List<String>? followedUserIds,
    List<String>? userInterests,
    List<String>? searchHistory,
  }) {
    final allPosts = _generateFeedPosts();

    // Rank posts based on relevance
    final rankedPosts = allPosts.map((post) {
      double score = 0.0;

      // Follow relationship (high priority)
      if (followedUserIds != null && followedUserIds.contains(post.userId)) {
        score += 100.0;
      }

      // Tagged posts (high priority)
      if (post.isTagged) {
        score += 80.0;
      }

      // Engagement history (liked posts from followed users)
      if (post.isLiked &&
          followedUserIds != null &&
          followedUserIds.contains(post.userId)) {
        score += 50.0;
      }

      // Interest matching
      if (userInterests != null) {
        final matchingHashtags = post.hashtags
            .where((tag) => userInterests
                .any((interest) =>
                    tag.toLowerCase().contains(interest.toLowerCase())))
            .length;
        score += matchingHashtags * 10.0;
      }

      // Search history matching
      if (searchHistory != null && post.caption != null) {
        final matchingKeywords = searchHistory
            .where((keyword) =>
                post.caption!.toLowerCase().contains(keyword.toLowerCase()))
            .length;
        score += matchingKeywords * 5.0;
      }

      // Recent posts get slight boost
      final hoursSincePost =
          DateTime.now().difference(post.createdAt).inHours;
      score += (24 - hoursSincePost).clamp(0, 24) * 0.5;

      return {'post': post, 'score': score};
    }).toList();

    // Sort by score (highest first)
    rankedPosts.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Insert ads every 5 posts
    final finalFeed = <FeedPost>[];
    for (int i = 0; i < rankedPosts.length; i++) {
      finalFeed.add(rankedPosts[i]['post'] as FeedPost);
      if ((i + 1) % 5 == 0 && i < rankedPosts.length - 1) {
        final ads = _getAds();
        if (ads.isNotEmpty) {
          finalFeed.add(ads[i % ads.length]);
        }
      }
    }

    return finalFeed;
  }

  List<FeedPost> _generateFeedPosts() {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'post-1',
        userId: 'user-2',
        userName: 'Alice Smith',
        mediaType: PostMediaType.image,
        mediaUrls: ['image_url_1'],
        caption: 'Beautiful sunset today! 🌅 #sunset #nature #photography',
        hashtags: ['sunset', 'nature', 'photography'],
        createdAt: now.subtract(const Duration(hours: 2)),
        likes: 245,
        comments: 12,
        isLiked: false,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-2',
        userId: 'user-3',
        userName: 'Bob Johnson',
        mediaType: PostMediaType.video,
        mediaUrls: ['video_url_1'],
        caption: 'Working on something exciting! 💻 #coding #tech',
        hashtags: ['coding', 'tech'],
        createdAt: now.subtract(const Duration(hours: 5)),
        likes: 189,
        comments: 8,
        views: 1200,
        isLiked: true,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-3',
        userId: 'user-4',
        userName: 'Emma Wilson',
        mediaType: PostMediaType.carousel,
        mediaUrls: ['image_url_2', 'image_url_3', 'image_url_4'],
        caption: 'Tagged you in this! @JohnDoe #friends #memories',
        hashtags: ['friends', 'memories'],
        createdAt: now.subtract(const Duration(hours: 1)),
        likes: 156,
        comments: 5,
        isLiked: false,
        isTagged: true,
      ),
      FeedPost(
        id: 'post-4',
        userId: 'user-5',
        userName: 'Mike Brown',
        mediaType: PostMediaType.carousel,
        mediaUrls: ['image_url_5', 'image_url_6'],
        caption: 'Check out my new collection! 🎨 #art #design',
        hashtags: ['art', 'design'],
        createdAt: now.subtract(const Duration(hours: 3)),
        likes: 320,
        comments: 15,
        isLiked: false,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-5',
        userId: 'user-6',
        userName: 'Sarah Davis',
        mediaType: PostMediaType.reel,
        mediaUrls: ['reel_url_1'],
        caption: 'Quick tutorial! #tutorial #tips',
        hashtags: ['tutorial', 'tips'],
        createdAt: now.subtract(const Duration(hours: 4)),
        likes: 890,
        comments: 45,
        views: 5000,
        isLiked: true,
      ),
      FeedPost(
        id: 'post-6',
        userId: 'user-7',
        userName: 'David Lee',
        mediaType: PostMediaType.image,
        mediaUrls: ['image_url_7'],
        caption: 'Amazing day at the beach! 🏖️ #beach #summer',
        hashtags: ['beach', 'summer'],
        createdAt: now.subtract(const Duration(hours: 6)),
        likes: 278,
        comments: 22,
        isLiked: false,
      ),
      FeedPost(
        id: 'post-7',
        userId: 'user-8',
        userName: 'Lisa Chen',
        isVerified: true,
        mediaType: PostMediaType.video,
        mediaUrls: ['video_url_2'],
        caption: 'New recipe I tried today! 🍰 #food #cooking',
        hashtags: ['food', 'cooking'],
        createdAt: now.subtract(const Duration(hours: 8)),
        likes: 412,
        comments: 18,
        views: 2500,
        isLiked: true,
      ),
    ];
  }

  List<FeedPost> _getAds() {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'ad-post-1',
        userId: 'advertiser-1',
        userName: 'Sponsored',
        mediaType: PostMediaType.image,
        mediaUrls: ['ad_image_1'],
        caption: 'Special Offer - 50% Off!',
        createdAt: now.subtract(const Duration(hours: 1)),
        likes: 0,
        comments: 0,
        isAd: true,
        adTitle: 'Special Offer',
        adCompanyId: 'company-1',
        adCompanyName: 'TechCorp',
      ),
    ];
  }

  /// Fetch feed from the REST API backend.
  ///
  /// Replaces the previous Supabase-direct `fetchFeedFromBackend`.
  Future<List<FeedPost>> fetchFeedFromBackend({
    int limit = 50,
    int offset = 0,
    String? currentUserId,
  }) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit);
      List<Map<String, dynamic>> items = [];
      if (data is List) {
        items = (data as List).cast<Map<String, dynamic>>();
      } else if (data is Map) {
        final map = data as Map;
        if (map['posts'] is List) {
          items = (map['posts'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is List) {
          items = (map['data'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is Map && (map['data'] as Map)['posts'] is List) {
          items = ((map['data'] as Map)['posts'] as List).cast<Map<String, dynamic>>();
        }
      }

      final mapped = items.map((item) {
        // The API nests the author info inside `user_id` as a populated object.
        Map<String, dynamic> user = {};
        if (item['user_id'] is Map) {
          user = item['user_id'] as Map<String, dynamic>;
        } else if (item['users'] is Map) {
          user = item['users'] as Map<String, dynamic>;
        }

        final rawLikesAny = (item['likes'] as List<dynamic>?) ??
            (item['liked_by'] as List<dynamic>?) ??
            const [];
        final likesCount = (item['likes_count'] as int?) ?? rawLikesAny.length;
        bool computedLiked = false;
        if (currentUserId != null && rawLikesAny.isNotEmpty) {
          for (final e in rawLikesAny) {
            if (e is Map) {
              String? uid = (e['user_id'] as String?) ??
                  (e['id'] as String?) ??
                  (e['_id'] as String?);
              if (uid == null && e['user'] is Map) {
                final u = (e['user'] as Map);
                uid = (u['id'] as String?) ?? (u['_id'] as String?);
              }
              if (uid != null && uid.toString() == currentUserId.toString()) {
                computedLiked = true;
                break;
              }
            } else if (e is String && e.toString() == currentUserId.toString()) {
              computedLiked = true;
              break;
            }
          }
        }
        final hasLikesArray = rawLikesAny.isNotEmpty;
        final isLikedByMe = hasLikesArray
            ? computedLiked
            : ((item['is_liked_by_me'] as bool?) ?? false);

        final media = item['media'] as List<dynamic>? ?? (item['images'] as List<dynamic>? ?? (item['attachments'] as List<dynamic>? ?? []));
        List<String> mediaUrls = media.map((m) {
          String? url;
          if (m is String) {
            url = m;
          } else if (m is Map) {
            if (m['file'] is Map) {
              final f = (m['file'] as Map);
              url = (f['fileUrl'] ?? f['file_url'] ?? f['url'] ?? f['path'])?.toString();
            } else if (m['file'] is String) {
              url = (m['file'] as String);
            }
            url ??= (m['fileUrl'] ??
                    m['file_url'] ??
                    m['image'] ??
                    m['imageUrl'] ??
                    m['url'] ??
                    m['file_path'])
                ?.toString();
            if ((url == null || url.isEmpty) && m['fileName'] != null) {
              final fn = m['fileName'].toString();
              url = '/uploads/$fn';
            }
          }
          return _normalizeUrl(url);
        }).where((u) => u.isNotEmpty).cast<String>().toList();
        if (mediaUrls.isEmpty) {
          final single = (item['imageUrl'] ??
                  item['image'] ??
                  item['fileUrl'] ??
                  item['file_url'] ??
                  item['url'] ??
                  item['file_path'])
              ?.toString();
          final normalized = _normalizeUrl(single);
          if (normalized.isNotEmpty) {
            mediaUrls = [normalized];
          }
        }
        if (mediaUrls.isEmpty) {
          final single = (item['imageUrl'] ?? item['image'] ?? item['url'])?.toString();
          if (single != null && single.isNotEmpty) {
            mediaUrls.add(single);
          }
        }

        final typeStr = (item['type'] as String?) ?? 'post';
        bool hasVideo = false;
        for (final mm in media) {
          if (mm is Map) {
            final t = (mm['type'] as String?)?.toLowerCase();
            if (t == 'video' || t == 'reel') {
              hasVideo = true;
              break;
            }
            final cand = (mm['fileUrl'] ??
                    mm['file_url'] ??
                    mm['url'] ??
                    mm['file_path'] ??
                    (mm['file'] is String ? mm['file'] : null) ??
                    (mm['file'] is Map ? ((mm['file'] as Map)['url'] ?? (mm['file'] as Map)['fileUrl']) : null))
                ?.toString()
                .toLowerCase();
            if (cand != null &&
                (cand.endsWith('.mp4') || cand.endsWith('.mov') || cand.contains('.m3u8'))) {
              hasVideo = true;
              break;
            }
          } else if (mm is String) {
            final s = mm.toLowerCase();
            if (s.endsWith('.mp4') || s.endsWith('.mov')) {
              hasVideo = true;
              break;
            }
          }
        }
        PostMediaType mediaType = PostMediaType.image;
        if (typeStr == 'reel') {
          mediaType = PostMediaType.reel;
        } else if (hasVideo && mediaUrls.length <= 1) {
          mediaType = PostMediaType.video;
        } else if (mediaUrls.length > 1) {
          mediaType = PostMediaType.carousel;
        }

        final post = FeedPost(
          id: item['_id'] as String? ?? item['id'] as String? ?? '',
          userId: user['_id'] as String? ??
              user['id'] as String? ??
              (item['user_id'] is String ? item['user_id'] as String : ''),
          userName: user['username'] as String? ?? (item['username'] as String?) ?? 'user',
          fullName: user['full_name'] as String? ?? (item['full_name'] as String?),
          userAvatar: user['avatar_url'] as String? ?? (item['userAvatar'] as String?),
          isVerified: user['is_verified'] as bool? ?? false,
          mediaType: mediaType,
          mediaUrls: mediaUrls,
          caption: item['caption'] as String?,
          hashtags: ((item['tags'] as List<dynamic>?) ?? [])
              .map((e) => e.toString())
              .toList(),
          createdAt: item['createdAt'] is String
              ? DateTime.parse(item['createdAt'] as String)
              : (item['created_at'] is String
                  ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
                  : DateTime.now()),
          likes: likesCount,
          comments: item['comments'] is List
              ? (item['comments'] as List).length
              : (item['comments_count'] as int? ?? (item['commentCount'] as int? ?? 0)),
          views: 0,
          isLiked: isLikedByMe,
          isSaved: false,
          isFollowed: false,
          isTagged: false,
          isShared: false,
          isAd: false,
          rawLikes: rawLikesAny.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
        );
        return post;
      }).toList();

      return mapped;
    } catch (e) {
      return [];
    }
  }

  // Get stories for online users
  List<StoryGroup> getStories() {
    return [];
  }

  // Get current user for profile icon
  User getCurrentUser() {
    // Will be populated after fetching /auth/me.
    // Return a placeholder; the caller should use AuthService.fetchCurrentUser() instead.
    return User(
      id: 'unknown',
      name: 'User',
      email: '',
    );
  }

  /// Fetch the current user from the REST API.
  Future<User> fetchCurrentUser() async {
    try {
      final data = await _authApi.me();
      return User(
        id: data['id'] as String? ?? data['_id'] as String? ?? 'unknown',
        name: data['full_name'] as String? ??
            data['username'] as String? ??
            'User',
        email: data['email'] as String? ?? '',
        avatarUrl: data['avatar_url'] as String?,
        username: data['username'] as String?,
      );
    } catch (_) {
      return User(id: 'unknown', name: 'User', email: '');
    }
  }

  // Like/Unlike post
  FeedPost toggleLike(FeedPost post) {
    return post.copyWith(
      isLiked: !post.isLiked,
      likes: post.isLiked ? post.likes - 1 : post.likes + 1,
    );
  }

  // Save/Unsave post
  FeedPost toggleSave(FeedPost post) {
    return post.copyWith(isSaved: !post.isSaved);
  }

  // Follow/Unfollow user
  FeedPost toggleFollow(FeedPost post) {
    return post.copyWith(isFollowed: !post.isFollowed);
  }
}
