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
    try {
      final data = await _usersApi.getUserProfile(userId);
      return data['user'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    // The new REST API doesn't expose a get-by-email endpoint.
    // This was only used for forgot-password flow; return null for now.
    return null;
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
      final posts = data['posts'] as List<dynamic>? ?? [];
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
      final posts = data['posts'] as List<dynamic>? ?? [];
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
        type: postData['type'] as String? ?? 'post',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Follows ────────────────────────────────────────────────────────────────

  Future<bool> toggleFollow(String userId, String targetUserId) async {
    // The new API docs don't include a follow endpoint yet.
    // Return false (no-op) until the endpoint is available.
    return false;
  }

  // ── Uploads ────────────────────────────────────────────────────────────────

  Future<String?> uploadFile(String bucket, String path, Uint8List bytes,
      {bool makePublic = true}) async {
    try {
      final result = await _uploadApi.uploadFileBytes(
        bytes: bytes,
        filename: path.split('/').last,
      );
      return result['fileUrl'] as String?;
    } catch (_) {
      return null;
    }
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
    // Not available in the new REST API.
    return [];
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
