import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../models/auth/jwt_token_model.dart';
import '../../utils/constants.dart';
import '../../config/supabase_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JWTService {
  static final JWTService _instance = JWTService._internal();
  factory JWTService() => _instance;

  late final FlutterSecureStorage _storage;
  final Map<String, String> _memoryStorage = {}; // Fallback when secure storage unavailable (e.g. web)
  JWTToken? _cachedToken;

  JWTService._internal() {
    if (kIsWeb) {
      _storage = const FlutterSecureStorage(
        webOptions: WebOptions(
          dbName: 'b_smart_secure',
          publicKey: 'b_smart_jwt',
        ),
      );
    } else {
      _storage = const FlutterSecureStorage();
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _memoryStorage[key] = value;
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key) ?? _memoryStorage[key];
    } catch (_) {
      return _memoryStorage[key];
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    _memoryStorage.remove(key);
  }

  // Store tokens securely
  Future<void> storeTokens(JWTToken token) async {
    _cachedToken = token;
    await _write(AuthConstants.accessTokenKey, token.accessToken);
    await _write(AuthConstants.refreshTokenKey, token.refreshToken);
    await _write(
        '${AuthConstants.accessTokenKey}_expires',
        token.accessTokenExpiresAt.toIso8601String());
    await _write(
        '${AuthConstants.refreshTokenKey}_expires',
        token.refreshTokenExpiresAt.toIso8601String());
    if (token.deviceId != null) {
      await _write(AuthConstants.deviceIdKey, token.deviceId!);
    }
  }

  // Get stored tokens
  Future<JWTToken?> getStoredTokens() async {
    if (_cachedToken != null && !_cachedToken!.isRefreshTokenExpired) {
      return _cachedToken;
    }

    try {
      final accessToken = await _read(AuthConstants.accessTokenKey);
      final refreshToken = await _read(AuthConstants.refreshTokenKey);
      final accessExpiresStr = await _read('${AuthConstants.accessTokenKey}_expires');
      final refreshExpiresStr = await _read('${AuthConstants.refreshTokenKey}_expires');
      final deviceId = await _read(AuthConstants.deviceIdKey);

      if (accessToken == null || refreshToken == null) {
        return null;
      }

      if (accessExpiresStr == null || refreshExpiresStr == null) {
        return null;
      }

      _cachedToken = JWTToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: DateTime.parse(accessExpiresStr),
        refreshTokenExpiresAt: DateTime.parse(refreshExpiresStr),
        deviceId: deviceId,
      );

      return _cachedToken;
    } catch (e) {
      return null;
    }
  }

  // Get access token (refresh if needed)
  Future<String?> getAccessToken() async {
    final token = await getStoredTokens();
    if (token == null) return null;

    // Check if access token is expired or will expire soon (within 1 minute)
    if (token.isAccessTokenExpired ||
        token.accessTokenExpiresAt.difference(DateTime.now()).inMinutes < 1) {
      // Try to refresh
      final refreshed = await refreshAccessToken();
      if (refreshed != null) {
        return refreshed.accessToken;
      }
      return null;
    }

    return token.accessToken;
  }

  // Decode JWT payload
  JWTPayload? decodeToken(String token) {
    try {
      if (!JwtDecoder.isExpired(token)) {
        final decoded = JwtDecoder.decode(token);
        return JWTPayload(
          userId: decoded['user_id'] as String,
          username: decoded['username'] as String,
          authProvider: decoded['auth_provider'] as String,
          deviceId: decoded['device_id'] as String?,
          issuedAt: DateTime.fromMillisecondsSinceEpoch(
              (decoded['iat'] as int) * 1000),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
              (decoded['exp'] as int) * 1000),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Refresh access token
  Future<JWTToken?> refreshAccessToken() async {
    final currentToken = await getStoredTokens();
    if (currentToken == null || currentToken.isRefreshTokenExpired) {
      await clearTokens();
      return null;
    }

    try {
      // Call Supabase auth token endpoint with refresh token
      final refreshToken = currentToken.refreshToken;
      final uri = Uri.parse('${SupabaseConfig.url}/auth/v1/token');
      final res = await http.post(
        uri,
        headers: {
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=refresh_token&refresh_token=$refreshToken',
      );

      if (res.statusCode != 200) {
        await clearTokens();
        return null;
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final newRefreshToken = data['refresh_token'] as String?;
      final expiresIn = data['expires_in'] as int? ?? 3600;

      if (accessToken == null || newRefreshToken == null) {
        await clearTokens();
        return null;
      }

      final now = DateTime.now();
      final token = JWTToken(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        accessTokenExpiresAt: now.add(Duration(seconds: expiresIn)),
        refreshTokenExpiresAt:
            now.add(AuthConstants.refreshTokenExpiry), // use configured expiry
      );

      await storeTokens(token);
      return token;
    } catch (e) {
      await clearTokens();
      return null;
    }
  }

  // Clear all tokens
  Future<void> clearTokens() async {
    _cachedToken = null;
    await _delete(AuthConstants.accessTokenKey);
    await _delete(AuthConstants.refreshTokenKey);
    await _delete('${AuthConstants.accessTokenKey}_expires');
    await _delete('${AuthConstants.refreshTokenKey}_expires');
    await _delete(AuthConstants.deviceIdKey);
    await _delete(AuthConstants.userIdKey);
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null;
  }

  // Get current user ID from token
  Future<String?> getCurrentUserId() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final payload = decodeToken(token);
    return payload?.userId;
  }
}

