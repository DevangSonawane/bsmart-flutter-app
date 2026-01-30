import 'package:supabase_flutter/supabase_flutter.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchAds({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client
          .from('ads')
          .select('*, company:companies(*)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      if (res == null) return [];
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final res = await _client.from('products').select().eq('id', productId).maybeSingle();
      return res as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createAd(Map<String, dynamic> data) async {
    try {
      await _client.from('ads').insert(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}

