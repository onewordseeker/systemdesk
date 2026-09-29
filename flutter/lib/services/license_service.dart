import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../consts.dart';

class SessionCheckResult {
  final bool allowed;
  final String code;
  final String? sessionToken;
  final int? minutesRemainingToday;
  final int? sessionLimitMinutes;

  const SessionCheckResult({
    required this.allowed,
    this.code = '',
    this.sessionToken,
    this.minutesRemainingToday,
    this.sessionLimitMinutes,
  });
}

class HeartbeatResult {
  final bool allowed;
  final String code;
  const HeartbeatResult({required this.allowed, this.code = ''});
}

class LicenseService {
  LicenseService._();
  static final instance = LicenseService._();

  String? _deviceId;
  String? _sessionToken;
  String? _authToken;

  String? get authToken => _authToken;
  String? get deviceId => _deviceId;
  bool get isLoggedIn => _authToken != null;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('sd_auth_token');

      final fingerprint = await _getHardwareFingerprint();
      final platform = _getPlatform();

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';

      final response = await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/devices/register'),
            headers: headers,
            body: jsonEncode({
              'hardware_fingerprint': fingerprint,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _deviceId = data['device_id'] as String?;
        if (_deviceId != null) {
          await prefs.setString('sd_device_id', _deviceId!);
        }
      }
    } catch (e) {
      debugPrint('LicenseService.init error: $e');
      // Fail open — allow app to work when server unreachable
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('sd_device_id');
    }
  }

  Future<SessionCheckResult> checkAndStartSession() async {
    if (_deviceId == null) {
      return const SessionCheckResult(allowed: true); // fail open
    }
    try {
      final response = await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/sessions/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': _deviceId}),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        _sessionToken = data['session_token'] as String?;
        final limits = data['limits'] as Map<String, dynamic>?;
        return SessionCheckResult(
          allowed: true,
          sessionToken: _sessionToken,
          minutesRemainingToday:
              limits?['minutes_remaining_today'] as int?,
          sessionLimitMinutes: limits?['session_limit_minutes'] as int?,
        );
      }
      return SessionCheckResult(
        allowed: false,
        code: data['code'] as String? ?? 'DENIED',
      );
    } catch (e) {
      debugPrint('LicenseService.checkAndStartSession error: $e');
      return const SessionCheckResult(allowed: true); // fail open
    }
  }

  Future<HeartbeatResult> heartbeat() async {
    if (_sessionToken == null) return const HeartbeatResult(allowed: true);
    try {
      final response = await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/sessions/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_token': _sessionToken}),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return HeartbeatResult(
        allowed: data['allowed'] as bool? ?? true,
        code: data['code'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('LicenseService.heartbeat error: $e');
      return const HeartbeatResult(allowed: true); // fail open
    }
  }

  Future<void> endSession() async {
    final token = _sessionToken;
    _sessionToken = null;
    if (token == null) return;
    try {
      await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/sessions/end'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_token': token}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('LicenseService.endSession error: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$kLicenseApiUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      _authToken = data['token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sd_auth_token', _authToken!);
      await init(); // re-register device bound to account
      return data;
    }
    throw Exception(data['error'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$kLicenseApiUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      _authToken = data['token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sd_auth_token', _authToken!);
      await init();
      return data;
    }
    throw Exception(data['error'] ?? 'Registration failed');
  }

  Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sd_auth_token');
  }

  Future<Map<String, dynamic>> getSubscription() async {
    if (_authToken == null) throw Exception('Not logged in');
    final response = await http.get(
      Uri.parse('$kLicenseApiUrl/api/subscription'),
      headers: {'Authorization': 'Bearer $_authToken'},
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<String> _getHardwareFingerprint() async {
    final plugin = DeviceInfoPlugin();
    String rawId;
    try {
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        rawId = info.deviceId;
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        rawId = info.systemGUID ?? info.computerName;
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        rawId = info.machineId ?? info.id;
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        rawId = info.id;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        rawId = info.identifierForVendor ?? info.name;
      } else {
        rawId = 'web';
      }
    } catch (e) {
      rawId = 'fallback-${Platform.operatingSystem}';
    }
    final bytes = utf8.encode('systemdesk:$rawId');
    return sha256.convert(bytes).toString();
  }

  String _getPlatform() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
