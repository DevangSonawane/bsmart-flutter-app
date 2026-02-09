import 'api_client.dart';

/// REST API wrapper for `/users` endpoints.
///
/// Endpoints:
///   GET    /users/:id  – Get user profile with posts (public)
///   PUT    /users/:id  – Update user profile (protected)
///   DELETE /users/:id  – Delete user and their posts (protected)
class UsersApi {
  static final UsersApi _instance = UsersApi._internal();
  factory UsersApi() => _instance;
  UsersApi._internal();

  final ApiClient _client = ApiClient();

  /// Get a user's profile along with their posts.
  ///
  /// Returns `{ user: {...}, posts: [...] }`.
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await _client.get('/users/$userId');
    return res as Map<String, dynamic>;
  }

  /// Update the authenticated user's profile.
  ///
  /// Accepts optional fields: `full_name`, `bio`, `avatar_url`, `phone`, `username`.
  /// Returns the updated user object.
  Future<Map<String, dynamic>> updateUser(
    String userId, {
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? phone,
    String? username,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (phone != null) body['phone'] = phone;
    if (username != null) body['username'] = username;

    final res = await _client.put('/users/$userId', body: body);
    return res as Map<String, dynamic>;
  }

  /// Delete a user and all their posts.
  ///
  /// Returns `{ message: "User deleted successfully" }`.
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final res = await _client.delete('/users/$userId');
    return res as Map<String, dynamic>;
  }
}
