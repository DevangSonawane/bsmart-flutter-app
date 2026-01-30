import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/auth/device_session_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;

  DeviceService._internal();

  DeviceInfo? _cachedDeviceInfo;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
    // ignore: dead_code - fallback for any future platform value
    return 'unknown';
  }

  // Get device information (works on all platforms including web)
  Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    try {
      String deviceId;
      String deviceName;
      String deviceType;
      String? deviceFingerprint;

      if (kIsWeb) {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Web Browser';
        deviceType = 'web';
        deviceFingerprint = _generateFingerprint({'platform': 'web', 'id': deviceId});
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceType = 'Android';
        deviceFingerprint = _generateFingerprint({
          'id': androidInfo.id,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
        });
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        deviceType = 'iOS';
        deviceFingerprint = _generateFingerprint({
          'id': iosInfo.identifierForVendor ?? 'unknown',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        });
      } else {
        deviceId = '${_platformLabel}_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Unknown Device';
        deviceType = _platformLabel;
        deviceFingerprint = _generateFingerprint({'os': _platformLabel, 'id': deviceId});
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final userAgent =
          '${packageInfo.appName}/${packageInfo.version} ($deviceType)';

      _cachedDeviceInfo = DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        deviceFingerprint: deviceFingerprint,
        ipAddress: null,
        userAgent: userAgent,
      );

      return _cachedDeviceInfo!;
    } catch (e) {
      return DeviceInfo(
        deviceId: '${_platformLabel}_fallback',
        deviceName: 'Unknown Device',
        deviceType: _platformLabel,
        deviceFingerprint: null,
        ipAddress: null,
        userAgent: 'b_smart/1.0.0',
      );
    }
  }

  // Generate device fingerprint hash
  String _generateFingerprint(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get or create device session
  Future<DeviceSession?> getOrCreateDeviceSession(String userId) async {
    try {
      final deviceInfo = await getDeviceInfo();
      final client = Supabase.instance.client;

      // Try to find existing session for this device and user
      final existing = await client
          .from('device_sessions')
          .select()
          .eq('device_id', deviceInfo.deviceId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update last_active_at
        await client.from('device_sessions').update({
          'last_active_at': DateTime.now().toIso8601String(),
          'device_name': deviceInfo.deviceName,
          'device_type': deviceInfo.deviceType,
        }).eq('id', existing['id']);

        return DeviceSession.fromJson(Map<String, dynamic>.from(existing));
      }

      // Insert new device session (upsert style)
      final newSession = {
        'user_id': userId,
        'device_id': deviceInfo.deviceId,
        'device_name': deviceInfo.deviceName,
        'device_type': deviceInfo.deviceType,
        'last_active_at': DateTime.now().toIso8601String(),
        'is_trusted': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final inserted = await client.from('device_sessions').insert(newSession).select().maybeSingle();
      if (inserted != null) {
        return DeviceSession.fromJson(Map<String, dynamic>.from(inserted));
      }

      return null;
    } catch (e) {
      // If table doesn't exist or RPC missing, fallback gracefully
      return null;
    }
    // final deviceInfo = await getDeviceInfo();
    // final existing = await backend.getDeviceSession(deviceInfo.deviceId);
    // 
    // if (existing != null) {
    //   await backend.updateDeviceSession({
    //     'user_id': userId,
    //     'device_id': deviceInfo.deviceId,
    //     'device_name': deviceInfo.deviceName,
    //     'device_type': deviceInfo.deviceType,
    //     'last_active_at': DateTime.now().toIso8601String(),
    //   });
    //   return DeviceSession.fromJson(existing);
    // }
    // 
    // final sessionData = {
    //   'user_id': userId,
    //   'device_id': deviceInfo.deviceId,
    //   'device_name': deviceInfo.deviceName,
    //   'device_type': deviceInfo.deviceType,
    //   'last_active_at': DateTime.now().toIso8601String(),
    //   'is_trusted': false,
    // };
    // 
    // await backend.upsertDeviceSession(sessionData);
    // return DeviceSession.fromJson({
    //   'id': '',
    //   ...sessionData,
    //   'created_at': DateTime.now().toIso8601String(),
    // });
  }

  // Mark device as trusted
  Future<void> markDeviceAsTrusted(String deviceId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('device_sessions').update({'is_trusted': true}).eq('device_id', deviceId);
    } catch (e) {
      // ignore errors silently
    }
  }

  // Check if device is trusted
  Future<bool> isDeviceTrusted(String deviceId) async {
    try {
      final client = Supabase.instance.client;
      final session = await client.from('device_sessions').select().eq('device_id', deviceId).maybeSingle();
      if (session == null) return false;
      return session['is_trusted'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  // Detect suspicious login (different device, IP, etc.)
  Future<bool> isSuspiciousLogin(String userId, String deviceId) async {
    try {
      final client = Supabase.instance.client;
      final deviceSession = await client.from('device_sessions').select().eq('device_id', deviceId).maybeSingle();
      if (deviceSession != null) {
        final isTrusted = deviceSession['is_trusted'] as bool? ?? false;
        if (isTrusted) return false;
      }

      final activeSessions = await client.from('device_sessions').select().eq('user_id', userId);
      // If there are active sessions for this user and this device is new/untrusted, mark suspicious
      if ((activeSessions as List).isNotEmpty && deviceSession == null) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
