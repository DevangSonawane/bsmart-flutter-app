import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reel_model.dart';

class ReelsService {
  static final ReelsService _instance = ReelsService._internal();
  factory ReelsService() => _instance;
  ReelsService._internal() {
    // Seed with mock data so UI shows immediately (no loading spinner)
    _cache.addAll(_defaultMockReels());
    _init();
  }

  final SupabaseClient _client = Supabase.instance.client;
  final List<Reel> _cache = [];

  static List<Reel> _defaultMockReels() {
    return [
      Reel(
        id: 'reel-1',
        userId: 'user-dance',
        userName: 'dance_queen',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=dance_queen',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
        thumbnailUrl: null,
        caption: 'Dancing vibes! 💃 #dance #fun',
        hashtags: ['dance', 'fun'],
        audioTitle: 'Original Audio - dance_quee',
        audioArtist: null,
        audioId: null,
        likes: 12500,
        comments: 120,
        shares: 10,
        views: 50000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: false,
        duration: const Duration(seconds: 30),
      ),
      Reel(
        id: 'reel-2',
        userId: 'user-nature',
        userName: 'nature_walks',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=nature_walks',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
        thumbnailUrl: null,
        caption: 'Peaceful morning 🌳 #nature',
        hashtags: ['nature'],
        audioTitle: 'Original Audio - nature_walks',
        audioArtist: null,
        audioId: null,
        likes: 8200,
        comments: 45,
        shares: 5,
        views: 20000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: false,
        duration: const Duration(seconds: 25),
      ),
      Reel(
        id: 'reel-3',
        userId: 'user-city',
        userName: 'city_life',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=city_life',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
        thumbnailUrl: null,
        caption: 'City lights 🌃 #nightlife',
        hashtags: ['city', 'nightlife'],
        audioTitle: 'Original Audio - city_life',
        audioArtist: null,
        audioId: null,
        likes: 25000,
        comments: 500,
        shares: 40,
        views: 120000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: true,
        duration: const Duration(seconds: 30),
      ),
    ];
  }

  /// When backend has posts with media_type=reel, fetchReels uses them; otherwise mock is shown.
  Future<void> _init() async {
    try {
      final fetched = await fetchReels(limit: 20, offset: 0);
      if (fetched.isNotEmpty) {
        _cache.clear();
        _cache.addAll(fetched);
      }
    } catch (_) {
      // Keep seeded mock data on fetch failure
    }
  }

  // Synchronous getter used by UI components that expect an immediate list
  List<Reel> getReels() => List.unmodifiable(_cache);

  Future<List<Reel>> fetchReels({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client
          .from('posts')
          .select('*, users:users(id, username, avatar_url)')
          .eq('media_type', 'reel')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final items = List<Map<String, dynamic>>.from(res);
      final list = items.map((item) {
        final user = item['users'] as Map<String, dynamic>?;
        final media = item['media'] as List<dynamic>? ?? [];
        final videoUrl = media.isNotEmpty ? (media.first is String ? media.first : (media.first['url'] ?? '')) : '';
        return Reel(
          id: item['id'] as String,
          userId: item['user_id'] as String,
          userName: user?['username'] as String? ?? 'user',
          userAvatarUrl: user?['avatar_url'] as String?,
          videoUrl: videoUrl,
          thumbnailUrl: null,
          caption: item['caption'] as String?,
          hashtags: ((item['hashtags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: item['likes_count'] as int? ?? 0,
          comments: item['comments_count'] as int? ?? 0,
          shares: item['shares_count'] as int? ?? 0,
          views: item['views_count'] as int? ?? 0,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.parse(item['created_at'] as String),
          isSponsored: item['is_ad'] as bool? ?? false,
          sponsorBrand: item['ad_company_name'] as String?,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 30),
        );
      }).toList();
      // update cache if offset == 0
      if (offset == 0) {
        _cache.clear();
        _cache.addAll(list);
      }
      return list;
    } catch (e) {
      // Fallback to mock reels (match React app sample)
      return [
        Reel(
          id: 'reel-1',
          userId: 'user-dance',
          userName: 'dance_queen',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=dance_queen',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
          thumbnailUrl: null,
          caption: 'Dancing vibes! 💃 #dance #fun',
          hashtags: ['dance','fun'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 12500,
          comments: 120,
          shares: 10,
          views: 50000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 30),
        ),
        Reel(
          id: 'reel-2',
          userId: 'user-nature',
          userName: 'nature_walks',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=nature_walks',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
          thumbnailUrl: null,
          caption: 'Peaceful morning 🌳 #nature',
          hashtags: ['nature'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 8200,
          comments: 45,
          shares: 5,
          views: 20000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 25),
        ),
        Reel(
          id: 'reel-3',
          userId: 'user-city',
          userName: 'city_life',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=city_life',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
          thumbnailUrl: null,
          caption: 'City lights 🌃 #nightlife',
          hashtags: ['city','nightlife'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 25000,
          comments: 500,
          shares: 40,
          views: 120000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: true,
          duration: const Duration(seconds: 30),
        ),
      ];
    }
  }

  Future<void> incrementViews(String reelId) async {
    try {
      await _client.rpc('increment_views', params: {'post_id': reelId});
    } catch (e) {
      try {
        final current = await _client.from('posts').select('views_count').eq('id', reelId).maybeSingle();
        final curVal = current?['views_count'] as int? ?? 0;
        await _client.from('posts').update({'views_count': curVal + 1}).eq('id', reelId);
      } catch (_) {}
    }
  }

  Future<void> incrementShares(String reelId) async {
    try {
      final current = await _client.from('posts').select('shares_count').eq('id', reelId).maybeSingle();
      final curVal = current?['shares_count'] as int? ?? 0;
      await _client.from('posts').update({'shares_count': curVal + 1}).eq('id', reelId);
    } catch (_) {}
  }

  // Local cache helpers for UI interactions (optimistic)
  void toggleLike(String reelId) {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx != -1) {
      final r = _cache[idx];
      _cache[idx] = r.copyWith(isLiked: !r.isLiked, likes: r.isLiked ? r.likes - 1 : r.likes + 1);
      // async backend update
      _client.rpc('toggle_reel_like', params: {'post_id': reelId});
    }
  }

  void toggleSave(String reelId) {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx != -1) {
      final r = _cache[idx];
      _cache[idx] = r.copyWith(isSaved: !r.isSaved);
      // backend save action (best-effort)
      _client.rpc('toggle_reel_save', params: {'post_id': reelId});
    }
  }

  void toggleFollow(String userId) {
    for (int i = 0; i < _cache.length; i++) {
      if (_cache[i].userId == userId) {
        _cache[i] = _cache[i].copyWith(isFollowing: !_cache[i].isFollowing);
      }
    }
    // best-effort backend call
    final me = Supabase.instance.client.auth.currentUser;
    if (me != null) {
      _client.rpc('toggle_follow', params: {'follower_id': me.id, 'followed_id': userId});
    }
  }
}
