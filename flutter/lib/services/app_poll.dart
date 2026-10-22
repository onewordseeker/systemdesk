import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_message_dialog.dart';
import 'package:flutter_hbb/screens/sd_update_gate.dart';
import 'package:flutter_hbb/services/app_notices.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_hbb/services/server_profile.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';

/// The main window asks the license server every 15 seconds for two things, and nothing about the person is sent but the system, the
/// app version and whether somebody is signed in:
///   - messages the administrators sent (to people with an account, to guests, to some systems): each is shown once, over whatever
///     the app is showing;
///   - the version the app must be updated to: below it, the whole app is covered by a screen that cannot be closed (SdUpdateGate).
/// An update requirement is remembered on this computer, so an app started without a connection is stopped too.
class AppPoll {
  AppPoll._();
  static final instance = AppPoll._();

  static const _kSeen = 'sd_seen_messages';
  static const _kRequired = 'sd_required_update';
  static const interval = Duration(seconds: 15);

  Timer? _timer;
  bool _busy = false;
  bool _showing = false;
  String _version = '';

  Future<void> start() async {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => poll());
    try {
      _version = (await bind.mainGetVersion()).trim();
    } catch (_) {}
    SdUpdateGate.currentVersion = _version;
    final stored = RequiredUpdate.fromStored(bind.mainGetLocalOption(key: _kRequired));
    if (stored != null) {
      if (stored.appliesTo(_version)) {
        SdUpdateGate.set(stored);
        unawaited(_bringToFront());
      } else {
        bind.mainSetLocalOption(key: _kRequired, value: '');
      }
    }
    Timer(const Duration(seconds: 3), poll);
  }

  Future<void> poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final response = await http
          .post(
            Uri.parse('$kLicenseApiUrl/api/app/poll'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'platform': appPlatformName(),
              if (_version.isNotEmpty) 'version': _version,
              'signed_in': LicenseService.instance.isLoggedIn,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return; // an older server, or a hiccup: nothing changes
      final data = jsonObjectOrEmpty(response.body);
      if (data.containsKey('update')) _applyUpdate(RequiredUpdate.fromPoll(data['update']));
      unawaited(_showMessages(AppMessage.listFrom(data['messages'])));
    } catch (e) {
      debugPrint('AppPoll.poll: $e'); // offline: the last answer stands
    } finally {
      _busy = false;
    }
  }

  void _applyUpdate(RequiredUpdate? next) {
    if (next == null) {
      if (SdUpdateGate.required.value != null) SdUpdateGate.set(null);
      if (bind.mainGetLocalOption(key: _kRequired).isNotEmpty) bind.mainSetLocalOption(key: _kRequired, value: '');
      return;
    }
    if (next == SdUpdateGate.required.value) return;
    SdUpdateGate.set(next);
    bind.mainSetLocalOption(key: _kRequired, value: next.toStored());
    unawaited(_bringToFront());
  }

  Future<void> _showMessages(List<AppMessage> all) async {
    if (_showing || SdUpdateGate.showing || globalKey.currentState?.overlay == null) return;
    final fresh = unseenMessages(all, bind.mainGetLocalOption(key: _kSeen));
    if (fresh.isEmpty) return;
    _showing = true;
    try {
      for (final m in fresh) {
        if (SdUpdateGate.showing) break; // the update comes first; the rest is shown after it
        bind.mainSetLocalOption(key: _kSeen, value: rememberSeen(bind.mainGetLocalOption(key: _kSeen), m.id));
        if (m.severity == 'critical') await _bringToFront();
        await showAppMessage(m);
      }
    } catch (e) {
      debugPrint('AppPoll.showMessages: $e');
    } finally {
      _showing = false;
    }
  }

  /// A window that is hidden in the tray or minimised comes forward for what must be seen now.
  Future<void> _bringToFront() async {
    if (!isDesktop) return;
    try {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }
}
