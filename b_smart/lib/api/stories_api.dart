import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for `/api/stories` endpoints.
///
/// Endpoints:
///   POST   /api/stories                     – Create/append items to active story
///   GET    /api/stories/feed                – Stories feed (preview + seen state)
///   GET    /api/stories/{storyId}/items     – Items for a story
///   POST   /api/stories/items/{itemId}/view – Mark item viewed
///   GET    /api/stories/{storyId}/views     – Viewers list (owner-only)
///   GET    /api/stories/archive             – Archived stories for requester
///   DELETE /api/stories/{storyId}           – Delete story (owner-only)
class StoriesApi {
  static final StoriesApi _instance = StoriesApi._internal();
  factory StoriesApi() => _instance;
  StoriesApi._internal();

  final ApiClient _client = ApiClient();

  String _path(String p) {
    final base = ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final hasApi = base.endsWith('/api');
    return hasApi ? p : '/api${p.startsWith('/') ? p : '/$p'}';
  }

  Future<List<dynamic>> feed() async {
    final res = await _client.get(_path('/stories/feed'));
    return (res as List).cast<dynamic>();
  }

  Future<List<dynamic>> items(String storyId) async {
    final res = await _client.get(_path('/stories/$storyId/items'));
    return (res as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> create(List<Map<String, dynamic>> itemsPayload) async {
    final res = await _client.post(_path('/stories'), body: {'items': itemsPayload});
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createFlexible(List<Map<String, dynamic>> itemsPayload) async {
    try {
      return await create(itemsPayload);
    } catch (e) {
      try {
        final res = await _client.post(_path('/stories/create'), body: {'items': itemsPayload});
        return (res as Map).cast<String, dynamic>();
      } catch (_) {
        final single = itemsPayload.isNotEmpty ? itemsPayload.first : <String, dynamic>{};
        try {
          final res = await _client.post(_path('/stories'), body: {'item': single});
          return (res as Map).cast<String, dynamic>();
        } catch (_) {
          final media = single['media'] is Map ? single['media'] as Map : <String, dynamic>{};
          final minimal = {
            'mediaUrl': media['url'] ?? single['url'] ?? '',
            'type': media['type'] ?? single['type'] ?? 'image',
          };
          final res = await _client.post(_path('/stories'), body: minimal);
          return (res as Map).cast<String, dynamic>();
        }
      }
    }
  }

  Future<Map<String, dynamic>> viewItem(String itemId) async {
    final res = await _client.post(_path('/stories/items/$itemId/view'));
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> views(String storyId) async {
    final res = await _client.get(_path('/stories/$storyId/views'));
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> archive() async {
    final res = await _client.get(_path('/stories/archive'));
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> delete(String storyId) async {
    final res = await _client.delete(_path('/stories/$storyId'));
    return (res as Map).cast<String, dynamic>();
  }
}
