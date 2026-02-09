import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_exceptions.dart';

/// Centralised HTTP client for the REST API.
///
/// * Automatically attaches the stored JWT Bearer token.
/// * Parses responses and throws typed [ApiException] subclasses.
/// * Provides convenience helpers: [get], [post], [put], [delete], [multipartPost].
class ApiClient {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final http.Client _http = http.Client();
  late final FlutterSecureStorage _storage;
  final Map<String, String> _memoryStorage = {};

  /// In-memory cached token so we don't hit secure storage on every request.
  String? _cachedToken;

  ApiClient._internal() {
    if (kIsWeb) {
      _storage = const FlutterSecureStorage(
        webOptions: WebOptions(
          dbName: 'b_smart_secure',
          publicKey: 'b_smart_api',
        ),
      );
    } else {
      _storage = const FlutterSecureStorage();
    }
  }

  // ── Token management ───────────────────────────────────────────────────────

  static const String _tokenKey = 'api_jwt_token';

  /// Persist the JWT returned by `/auth/login` or `/auth/register`.
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      _memoryStorage[_tokenKey] = token;
    }
  }

  /// Retrieve the stored JWT (from cache → secure storage → memory fallback).
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: _tokenKey) ?? _memoryStorage[_tokenKey];
    } catch (_) {
      _cachedToken = _memoryStorage[_tokenKey];
    }
    return _cachedToken;
  }

  /// Clear stored JWT (logout).
  Future<void> clearToken() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    _memoryStorage.remove(_tokenKey);
  }

  /// Whether we currently hold a token.
  Future<bool> get hasToken async => (await getToken()) != null;

  // ── Request helpers ────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final fullPath = path.startsWith('/') ? '$base$path' : '$base/$path';
    return Uri.parse(fullPath).replace(queryParameters: queryParams);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = await getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // ── Public HTTP methods ────────────────────────────────────────────────────

  /// `GET <baseUrl>/<path>?queryParams`
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    try {
      final response = await _http
          .get(_uri(path, queryParams), headers: await _headers())
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  /// `POST <baseUrl>/<path>` with JSON body.
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final response = await _http
          .post(_uri(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null)
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  /// `PUT <baseUrl>/<path>` with JSON body.
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    try {
      final response = await _http
          .put(_uri(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null)
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  /// `DELETE <baseUrl>/<path>`
  Future<dynamic> delete(String path) async {
    try {
      final response = await _http
          .delete(_uri(path), headers: await _headers())
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  /// Multipart `POST` for file uploads.
  ///
  /// [fileField] is the form field name (defaults to `"file"`).
  /// [filePath] is the local file path to upload.
  Future<dynamic> multipartPost(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      final streamed = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  /// Multipart `POST` from bytes (useful for image picker results).
  Future<dynamic> multipartPostBytes(
    String path, {
    required List<int> bytes,
    required String filename,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
      final streamed = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    }
  }

  // ── Response handling ──────────────────────────────────────────────────────

  dynamic _handleResponse(http.Response response) {
    final Map<String, dynamic>? body = _tryDecodeJson(response.body);
    final message = body?['message'] as String? ??
        body?['error'] as String? ??
        response.reasonPhrase ??
        'Unknown error';

    switch (response.statusCode) {
      case 200:
      case 201:
        return body ?? response.body;
      case 400:
        throw BadRequestException(message: message, body: body);
      case 401:
        throw UnauthorizedException(message: message, body: body);
      case 403:
        throw ForbiddenException(message: message, body: body);
      case 404:
        throw NotFoundException(message: message, body: body);
      default:
        if (response.statusCode >= 500) {
          throw ServerException(message: message, body: body);
        }
        throw ApiException(statusCode: response.statusCode, message: message, body: body);
    }
  }

  Map<String, dynamic>? _tryDecodeJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
