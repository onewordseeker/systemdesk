import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../consts.dart';
import '../models/platform_model.dart';

/// A refusal from the license server with its machine-readable code (DEVICE_LIMIT, DEVICE_ALREADY_BOUND, ...).
/// toString() is the plain message, so code that just prints the error keeps working.
class LicenseException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? data;
  const LicenseException(this.message, {this.code, this.data});

  @override
  String toString() => message;
}

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
  String? _fingerprint;
  String? _sessionToken;
  String? _authToken;

  final isLoggedInRx = false.obs;

  Timer? _sessionTimer;

  /// Called after this login was revoked on the server (e.g. an admin removed this device from the
  /// account) and the local sign-in has been cleared, so the UI can reset its own user state.
  void Function()? onSessionRevoked;

  String? get authToken => _authToken;
  String? get deviceId => _deviceId;

  /// SHA-256 hardware fingerprint: the same value the console and the customer portal show as "FP".
  String? get hardwareFingerprint => _fingerprint;
  bool get isLoggedIn => _authToken != null;

  // Keys used in both SharedPreferences and bind config (cross-window).
  static const _kAuthTokenKey = 'sd_auth_token';
  static const _kDeviceIdKey = 'sd_device_id';

  Future<void> init() async {
    // SharedPreferences is only available in the main window on macOS
    // (secondary windows lack the platform channel). We always mirror
    // the token and device ID to bind.mainSetLocalOption so that
    // remote/file-transfer windows can read them via bind.mainGetLocalOption.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('LicenseService.init: SharedPreferences unavailable ($e)');
    }

    // --- Read auth token ---
    if (prefs != null) {
      _authToken = prefs.getString(_kAuthTokenKey);
      isLoggedInRx.value = _authToken != null;
      // Mirror into the cross-window config so secondary windows can read it.
      if (_authToken != null) {
        bind.mainSetLocalOption(key: _kAuthTokenKey, value: _authToken!);
      }
      _startSessionWatch(); // main window only: notice when the server revokes this login
    } else {
      // Secondary window: read from the Rust config file (shared across all windows).
      final stored = bind.mainGetLocalOption(key: _kAuthTokenKey);
      if (stored.isNotEmpty) {
        _authToken = stored;
        isLoggedInRx.value = true;
      }
      // If device ID is already cached in config, skip the registration call.
      final storedDeviceId = bind.mainGetLocalOption(key: _kDeviceIdKey);
      if (storedDeviceId.isNotEmpty) {
        _deviceId = storedDeviceId;
        return;
      }
    }

    // --- Device registration ---
    try {
      final fingerprint = await _getHardwareFingerprint();
      _fingerprint = fingerprint;
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
              ...await _identityFields(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _deviceId = data['device_id'] as String?;
        if (_deviceId != null) {
          await prefs?.setString(_kDeviceIdKey, _deviceId!);
          bind.mainSetLocalOption(key: _kDeviceIdKey, value: _deviceId!);
        }
      } else if (response.statusCode == 403 && _authToken != null) {
        // this device may not use the account (no free slot / linked to someone else): the server has already
        // revoked this login, so drop it here too instead of waiting for the next check
        final code = (jsonDecode(response.body) as Map<String, dynamic>)['code'];
        if (code == 'DEVICE_LIMIT' || code == 'DEVICE_ALREADY_BOUND') await _signOutLocally();
      }
    } catch (e) {
      debugPrint('LicenseService.init device registration error: $e');
      // Fall back to whatever we have cached.
      if (_deviceId == null) {
        _deviceId = prefs?.getString(_kDeviceIdKey);
      }
      if (_deviceId == null) {
        final cached = bind.mainGetLocalOption(key: _kDeviceIdKey);
        if (cached.isNotEmpty) _deviceId = cached;
      }
    }
  }

  /// [peerId] = RustDesk id of the host this app is about to control. The backend uses it to merge the host's own
  /// report of the connection into this one session (otherwise one connection is counted twice).
  Future<SessionCheckResult> checkAndStartSession({String? peerId}) async {
    if (_deviceId == null) {
      // Device not registered yet (e.g. after delink+logout). Re-register now so
      // the backend can apply free-tier limits rather than letting the session
      // through unchecked. Only fail open if registration itself errors out.
      await init();
      if (_deviceId == null) return const SessionCheckResult(allowed: true);
    }
    final result = await _doSessionStart(_deviceId!, peerId);
    if (result.code == 'DEVICE_INACTIVE') {
      // Stale device_id — clear it, re-register, and retry once.
      _deviceId = null;
      bind.mainSetLocalOption(key: _kDeviceIdKey, value: '');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kDeviceIdKey);
      } catch (_) {}
      await init();
      if (_deviceId == null) return const SessionCheckResult(allowed: true);
      final retry = await _doSessionStart(_deviceId!, peerId);
      // If backend still reports DEVICE_INACTIVE for an authenticated user,
      // fail open so valid subscribers aren't blocked by a backend data issue.
      if (retry.code == 'DEVICE_INACTIVE' && _authToken != null) {
        debugPrint('LicenseService: DEVICE_INACTIVE persists after re-register; failing open for authenticated user');
        return const SessionCheckResult(allowed: true);
      }
      return retry;
    }
    return result;
  }

  Future<SessionCheckResult> _doSessionStart(String deviceId, String? peerId) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';
      final body = <String, String>{'device_id': deviceId};
      // the host's id as typed ("123 456 789@server" -> 123456789) and our own id
      final host = (peerId ?? '').split('@').first.split(',').first.replaceAll(' ', '');
      if (host.isNotEmpty) body['peer_id'] = host;
      try {
        final mine = await bind.mainGetMyId();
        if (mine.isNotEmpty) body['client_rd_id'] = mine;
      } catch (_) {}
      final response = await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/sessions/start'),
            headers: headers,
            body: jsonEncode(body),
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
      debugPrint('LicenseService._doSessionStart error: $e');
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

  Future<Map<String, dynamic>> login(String username, String password) async {
    // The server only signs an account in on its linked devices, or on a new one while a slot is free: it needs to know
    // which device this is.
    String? fingerprint = _fingerprint;
    try {
      fingerprint ??= await _getHardwareFingerprint();
      _fingerprint = fingerprint;
    } catch (_) {}
    final response = await http
        .post(
          Uri.parse('$kLicenseApiUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            if (fingerprint != null) 'hardware_fingerprint': fingerprint,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      _authToken = data['token'] as String?;
      isLoggedInRx.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAuthTokenKey, _authToken!);
      // Mirror to cross-window config immediately so secondary windows pick it up.
      bind.mainSetLocalOption(key: _kAuthTokenKey, value: _authToken!);
      await init(); // re-register device bound to account
      return data;
    }
    throw LicenseException(data['error'] as String? ?? 'Login failed', code: data['code'] as String?, data: data);
  }

  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$kLicenseApiUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      _authToken = data['token'] as String?;
      isLoggedInRx.value = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAuthTokenKey, _authToken!);
      bind.mainSetLocalOption(key: _kAuthTokenKey, value: _authToken!);
      await init();
      return data;
    }
    throw Exception(data['error'] ?? 'Registration failed');
  }

  void _startSessionWatch() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    if (_authToken == null) return;
    _sessionTimer = Timer.periodic(const Duration(seconds: 60), (_) => _checkSession());
    _checkSession();
  }

  /// A revoked login (admin unbound this device, session removed) answers 401 on any authenticated
  /// call. Anything else (offline, server error, older backend) is ignored: never sign out on doubt.
  Future<void> _checkSession() async {
    final token = _authToken;
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$kLicenseApiUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 && token == _authToken) {
        await _signOutLocally();
      }
    } catch (_) {}
  }

  Future<void> _signOutLocally() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _authToken = null;
    _sessionToken = null;
    isLoggedInRx.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAuthTokenKey);
    } catch (_) {}
    bind.mainSetLocalOption(key: _kAuthTokenKey, value: '');
    onSessionRevoked?.call();
  }

  Future<void> logout() async {
    final token = _authToken;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _authToken = null;
    isLoggedInRx.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthTokenKey);
    // Clear from cross-window config too.
    bind.mainSetLocalOption(key: _kAuthTokenKey, value: '');
    // Revoke the login_session on the backend so it no longer counts toward
    // the concurrent session limit. Fire-and-forget: local logout must succeed
    // even if the network call fails.
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('$kLicenseApiUrl/api/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> getSubscription() async {
    if (_authToken == null) throw Exception('Not logged in');
    final response = await http.get(
      Uri.parse('$kLicenseApiUrl/api/subscription'),
      headers: {'Authorization': 'Bearer $_authToken'},
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Who is signed in ({ user: { username, email, ... } }).
  Future<Map<String, dynamic>> getProfile() async {
    if (_authToken == null) throw Exception('Not logged in');
    final response = await http.get(
      Uri.parse('$kLicenseApiUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $_authToken'},
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// One device may be unbound per 30 days: { days, locked, last_at, next_allowed_at }, or null if it cannot be read
  /// (the server still enforces the limit when the delink is sent).
  Future<Map<String, dynamic>?> getUnbindStatus() async {
    if (_authToken == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$kLicenseApiUrl/api/devices'),
        headers: {'Authorization': 'Bearer $_authToken'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final unbind = (jsonDecode(response.body) as Map<String, dynamic>)['unbind'];
      return unbind is Map<String, dynamic> ? unbind : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> delinkCurrentDevice() async {
    final id = _deviceId;
    if (id == null) throw Exception('No device linked');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_authToken != null) headers['Authorization'] = 'Bearer $_authToken';
    final response = await http
        .delete(
          Uri.parse('$kLicenseApiUrl/api/devices/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? 'Delink failed (${response.statusCode})');
    }
    _deviceId = null;
    bind.mainSetLocalOption(key: _kDeviceIdKey, value: '');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDeviceIdKey);
    } catch (_) {}
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

  /// Computer name + the RustDesk id/uuid this install connects with, so the backend links the
  /// device exactly instead of guessing by IP. Empty values are left out.
  Future<Map<String, String>> _identityFields() async {
    final out = <String, String>{};
    try {
      final name = Platform.localHostname;
      if (name.isNotEmpty) out['device_name'] = name;
    } catch (_) {}
    try {
      final id = await bind.mainGetMyId();
      if (id.isNotEmpty) out['rustdesk_id'] = id;
      final uuid = await bind.mainGetUuid();
      if (uuid.isNotEmpty) out['rustdesk_uuid'] = uuid;
    } catch (e) {
      debugPrint('LicenseService: could not read RustDesk id/uuid ($e)');
    }
    return out;
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
