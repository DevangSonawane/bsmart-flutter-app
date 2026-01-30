import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final res = await _client.from('users').select().eq('id', userId).maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Find user by email (e.g. for forgot password).
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final res = await _client
          .from('users')
          .select('id, email, full_name, username, avatar_url')
          .eq('email', email)
          .maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      final res = await _client.from('posts').select().eq('id', postId).maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final res = await _client
          .from('posts')
          .select('*, users:users(id, username, avatar_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    try {
      final res = await _client.from('users').select('id').eq('username', username).maybeSingle();
      return res == null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      // Update public.users table
      await _client.from('users').update(updates).eq('id', userId);
      // Also update auth user metadata if necessary
      // Note: Supabase auth update requires current session; skip here if not available
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleFollow(String userId, String targetUserId) async {
    try {
      final existing = await _client
          .from('follows')
          .select()
          .eq('follower_id', userId)
          .eq('followed_id', targetUserId)
          .maybeSingle();
      if (existing == null) {
        await _client.from('follows').insert({
          'follower_id': userId,
          'followed_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      } else {
        await _client.from('follows').delete().eq('id', existing['id']);
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Fetch feed (posts) with pagination and optional filters
  Future<List<Map<String, dynamic>>> fetchFeed({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client
          .from('posts')
          .select('*, users:users(id, username, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  // Upload file to specified storage bucket and return public URL
  // Upload file to specified storage bucket and return the stored path (caller may call getPublicUrl)
  Future<String?> uploadFile(String bucket, String path, Uint8List bytes, {bool makePublic = true}) async {
    try {
      await _client.storage.from(bucket).uploadBinary(path, bytes);
      if (makePublic) {
        try {
          // getPublicUrl is synchronous and returns String
          final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
          if (publicUrl.isNotEmpty) return publicUrl;
        } catch (_) {
          // fallback to returning path if getPublicUrl fails
        }
      }
      // If not making public or getPublicUrl not available, return stored path
      return path;
    } catch (e) {
      return null;
    }
  }

  // Create a post row (expects media to be an array of URLs or objects)
  Future<bool> createPost(Map<String, dynamic> postData) async {
    try {
      final insertRes = await _client.from('posts').insert(postData).select().maybeSingle();
      // Try to call append_post_id RPC (used by web) if available
      try {
        final insertedId = insertRes != null ? (insertRes['id'] ?? insertRes['ID'] ?? insertRes['Id']) : null;
        final userId = postData['user_id'];
        if (insertedId != null && userId != null) {
          await _client.rpc('append_post_id', params: {'post_id': insertedId, 'user_id_param': userId});
        }
      } catch (_) {
        // ignore rpc errors - best-effort compatibility with web
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Comments
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final res = await _client.from('comments').select('*, user:users(id, username, avatar_url)').eq('post_id', postId).order('created_at', ascending: true);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      // Fallback: return mock ads similar to React promote/ads data
      return [
        {
          'id': 'ad-1',
          'ad_title': 'Special Offer - 50% Off!',
          'ad_company_name': 'TechCorp',
          'creative_url': 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?w=400&h=300&fit=crop',
          'product_id': 'product-1',
          'cta_text': 'Shop',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'ad-2',
          'ad_title': 'Upgrade your workflow',
          'ad_company_name': 'WorkFlow Inc.',
          'creative_url': 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=400&h=300&fit=crop',
          'product_id': 'product-2',
          'cta_text': 'Learn',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    }
  }

  Future<bool> addComment(String postId, String userId, String content) async {
    try {
      await _client.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Likes - simple like toggle using post_likes table
  Future<bool> togglePostLike(String postId, String userId) async {
    try {
      final existing = await _client.from('post_likes').select().eq('post_id', postId).eq('user_id', userId).maybeSingle();
      if (existing == null) {
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        // increment likes_count
        await _client.rpc('increment_post_likes', params: {'post_id': postId});
        return true;
      } else {
        await _client.from('post_likes').delete().eq('id', existing['id']);
        await _client.rpc('decrement_post_likes', params: {'post_id': postId});
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  // Ads & products
  Future<List<Map<String, dynamic>>> fetchAds({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client.from('ads').select('*, company:companies(*)').order('created_at', ascending: false).range(offset, offset + limit - 1);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final res = await _client.from('products').select().eq('id', productId).maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // Fetch users for selection (exclude current user if provided)
  Future<List<Map<String, dynamic>>> fetchUsers({String? excludeUserId, int limit = 100}) async {
    try {
      final res = await _client.from('users').select('id, username, full_name, avatar_url').order('created_at', ascending: false).limit(limit);
      if (res == null) return [];
      final list = List<Map<String, dynamic>>.from(res as List);
      if (excludeUserId != null) {
        list.removeWhere((m) => (m['id'] as String?) == excludeUserId);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Search users by username for tagging (ilike, limit 20).
  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query, {int limit = 20}) async {
    try {
      PostgrestList res;
      if (query.trim().isNotEmpty) {
        res = await _client
            .from('users')
            .select('id, username, avatar_url, full_name')
            .ilike('username', '%${query.trim()}%')
            .limit(limit);
      } else {
        res = await _client
            .from('users')
            .select('id, username, avatar_url, full_name')
            .limit(limit);
      }
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // Wallet
  Future<int> getCoinBalance(String userId) async {
    try {
      final res = await _client.from('wallets').select('balance').eq('user_id', userId).maybeSingle();
      final bal = res?['balance'];
      if (bal is int) return bal;
      if (bal is double) return bal.toInt();
      if (bal is num) return bal.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId, {int limit = 50}) async {
    try {
      final res = await _client.from('transactions').select().eq('user_id', userId).order('created_at', ascending: false).range(0, limit - 1);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
  }

  // Reward user for watching ad (tries RPC then fallback)
  Future<bool> rewardUserForAdView(String userId, String adId, int amount) async {
    try {
      await _client.rpc('reward_user_for_view', params: {'user_id': userId, 'ad_id': adId, 'amount': amount});
      return true;
    } catch (_) {
      // fallback: insert transaction and update wallet
      try {
        await _client.from('transactions').insert({
          'user_id': userId,
          'type': 'adReward',
          'amount': amount,
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        });
        final bal = await getCoinBalance(userId);
        await _client.from('wallets').update({'balance': bal + amount}).eq('user_id', userId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}

