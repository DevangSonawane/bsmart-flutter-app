import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token != null) {
        // Optionally store token on user's profile in Supabase
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('device_tokens').upsert({
            'user_id': user.id,
            'token': token,
            'platform': 'android',
          });
        }
      }
    } catch (e) {
      // ignore initialization errors
    }
  }
}

