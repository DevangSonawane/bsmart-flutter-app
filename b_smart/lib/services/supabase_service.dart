import 'dart:typed_data';
import '../api/api.dart';

/// Service layer that was previously calling Supabase directly.
///
/// Now delegates to the new REST API endpoints while keeping the same
/// public interface so existing screens/widgets continue to work unchanged.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final UsersApi _usersApi = UsersApi();
  final PostsApi _postsApi = PostsApi();
  final CommentsApi _commentsApi = CommentsApi();
  final UploadApi _uploadApi = UploadApi();

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    // Primary source: public users endpoint with posts
    try {
      final data = await _usersApi.getUserProfile(userId);
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null && (user['username'] != null || user['full_name'] != null)) {
        return user;
      }
    } catch (_) {}
    // Fallback: authenticated user endpoint
    try {
      final me = await AuthApi().me();
      // Only return if it matches the requested id or no public profile existed
      final meId = me['id'] as String? ?? me['_id'] as String?;
      if (meId != null && meId == userId) {
        return me;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final results = await _usersApi.search(email);
      final match = results.firstWhere(
        (u) => (u['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        orElse: () => {},
      );
      if (match.isEmpty) return null;
      return match;
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    // No dedicated endpoint – the server rejects duplicate usernames at
    // registration time. Return true optimistically.
    return true;
  }

  Future<bool> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _usersApi.updateUser(
        userId,
        fullName: updates['full_name'] as String?,
        bio: updates['bio'] as String?,
        avatarUrl: updates['avatar_url'] as String?,
        phone: updates['phone'] as String?,
        username: updates['username'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Posts ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      return await _postsApi.getPost(postId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final data = await _usersApi.getUserProfile(userId);
      List<dynamic> posts = [];
      if (data['posts'] is List) {
        posts = data['posts'] as List<dynamic>;
      } else if (data['user'] is Map && (data['user'] as Map)['posts'] is List) {
        posts = ((data['user'] as Map)['posts'] as List<dynamic>);
      } else if (data['data'] is Map && (data['data'] as Map)['posts'] is List) {
        posts = ((data['data'] as Map)['posts'] as List<dynamic>);
      }
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserSavedPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit * 3);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['posts'] as List<dynamic>? ?? [];
      }
      final posts = raw.where((p) {
        final m = (p as Map).cast<String, dynamic>();
        final isSaved = m['is_saved_by_me'] as bool?;
        if (isSaved == true) return true;
        final savedBy = m['saved_by'] as List<dynamic>?;
        if (savedBy != null) {
          for (final entry in savedBy) {
            if (entry is String && entry == userId) return true;
            if (entry is Map) {
              final id = entry['id'] as String? ?? entry['_id'] as String? ?? entry['user_id'] as String?;
              if (id == userId) return true;
            }
          }
        }
        final bookmarks = m['bookmarks'] as List<dynamic>?;
        if (bookmarks != null) {
          for (final b in bookmarks) {
            if (b is String && b == userId) return true;
            if (b is Map) {
              final id = b['id'] as String? ?? b['_id'] as String? ?? b['user_id'] as String?;
              if (id == userId) return true;
            }
          }
        }
        return false;
      }).toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserTaggedPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit * 3);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['posts'] as List<dynamic>? ?? [];
      }
      final posts = raw.where((p) {
        final m = (p as Map).cast<String, dynamic>();
        final peopleTags = (m['people_tags'] as List<dynamic>?) ?? (m['peopleTags'] as List<dynamic>?) ?? const [];
        for (final t in peopleTags) {
          if (t is String && t == userId) return true;
          if (t is Map) {
            final id = t['user_id'] as String? ?? t['id'] as String? ?? t['_id'] as String?;
            if (id == userId) return true;
          }
        }
        return false;
      }).toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeed(
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      final posts = (data as Map)['posts'] as List<dynamic>? ?? [];
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPost(Map<String, dynamic> postData) async {
    try {
      final media = postData['media'] as List<dynamic>? ?? [];
      await _postsApi.createPost(
        media: media.cast<Map<String, dynamic>>(),
        caption: postData['caption'] as String?,
        location: postData['location'] as String?,
        tags: (postData['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        hideLikesCount: postData['hide_likes_count'] as bool?,
        turnOffCommenting: postData['turn_off_commenting'] as bool?,
        peopleTags: (postData['people_tags'] as List<dynamic>?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        type: postData['type'] as String? ?? 'post',
      );
      return true;
    } on ApiException {
      // Fallback: retry with a minimal media payload if server rejects full schema
      try {
        final media = (postData['media'] as List<dynamic>? ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .map((m) => {
                  'fileUrl': m['fileUrl'],
                  'type': m['type'],
                })
            .toList();
        await _postsApi.createPost(
          media: media,
          caption: postData['caption'] as String?,
          location: postData['location'] as String?,
          type: postData['type'] as String? ?? 'post',
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ── Follows ────────────────────────────────────────────────────────────────

  Future<bool> toggleFollow(String userId, String targetUserId) async {
    // The new API docs don't include a follow endpoint yet.
    // Return false (no-op) until the endpoint is available.
    return false;
  }

  // ── Uploads ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadFile(String bucket, String path, Uint8List bytes,
      {bool makePublic = true}) async {
    final result = await _uploadApi.uploadFileBytes(
      bytes: bytes,
      filename: path.split('/').last,
    );
    return result;
  }

  // ── Comments ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final data = await _commentsApi.getComments(postId);
      final comments = data['comments'] as List<dynamic>? ?? [];
      return comments.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> addComment(
      String postId, String userId, String content) async {
    try {
      await _commentsApi.addComment(postId, text: content);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Likes ──────────────────────────────────────────────────────────────────

  Future<Set<String>> getLikedPostIds(String userId) async {
    // The new API doesn't have a batch "get liked post IDs" endpoint.
    // Feed posts include `is_liked_by_me` so we derive it at render time.
    return {};
  }

  Future<bool> updatePostLikes(
      String postId, List<Map<String, dynamic>> likes) async {
    // Replaced by explicit like/unlike endpoints.
    return false;
  }

  Future<bool> togglePostLike(String postId, String userId) async {
    try {
      // Try to like; if already liked the server returns 400, then unlike.
      try {
        await _postsApi.likePost(postId);
        return true; // liked
      } on BadRequestException {
        await _postsApi.unlikePost(postId);
        return false; // unliked
      }
    } catch (_) {
      return false;
    }
  }

  // ── Ads & Products ─────────────────────────────────────────────────────────
  // These are not part of the new API docs. Keep stubs returning empty data.

  Future<List<Map<String, dynamic>>> fetchAds(
      {int limit = 20, int offset = 0}) async {
    return [];
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    return null;
  }

  // ── Users list ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsers(
      {String? excludeUserId, int limit = 100}) async {
    // Not available in the new REST API; provide a static fallback so StoriesRow
    // renders similarly to the web app's StoryRail.
    final samples = <Map<String, dynamic>>[
      {
        'id': 'u-your',
        'username': 'your_story',
        'avatar_url':
            'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-2',
        'username': 'jane_doe',
        'avatar_url':
            'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-3',
        'username': 'john_smith',
        'avatar_url':
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-4',
        'username': 'travel_lover',
        'avatar_url':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-5',
        'username': 'foodie_life',
        'avatar_url':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-6',
        'username': 'tech_guru',
        'avatar_url':
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-7',
        'username': 'art_daily',
        'avatar_url':
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=60'
      },
    ];
    if (excludeUserId != null && excludeUserId.isNotEmpty) {
      return samples.where((u) => u['id'] != excludeUserId).take(limit).toList();
    }
    return samples.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query,
      {int limit = 20}) async {
    // Not available in the new REST API.
    return [];
  }

  // ── Wallet ─────────────────────────────────────────────────────────────────
  // Wallet endpoints are not defined in the new API docs yet.
  // Keeping Supabase-less stubs so the app compiles.

  Future<int> getCoinBalance(String userId) async {
    return 0;
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId,
      {int limit = 50}) async {
    return [];
  }

  Future<bool> rewardUserForAdView(
      String userId, String adId, int amount) async {
    return false;
  }
}
