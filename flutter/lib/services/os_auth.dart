import 'dart:io';
import 'dart:isolate';

import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/services/os_auth_windows.dart';

/// "Prove you are at this computer": the operating system's own password prompt (the one used for administrator
/// actions), so the license key is not shown to anyone who merely sits down at an unlocked app.
///   Windows  Windows Security credential dialog (current account name pre-filled), checked with LogonUser
///   macOS    the administrator password dialog of osascript
///   Linux    polkit (pkexec)
///   Android  the phone's screen lock (PIN / pattern / password / biometrics)
/// The password never reaches this app's own UI and is wiped from memory right after the check.
enum OsAuthStatus { ok, cancelled, failed, unavailable }

class OsAuthResult {
  const OsAuthResult(this.status, [this.message = '']);
  final OsAuthStatus status;
  final String message;
  bool get ok => status == OsAuthStatus.ok;
}

const _kDefaultReason = 'Confirm it is you to show your license key.';

Future<OsAuthResult> verifyOsUser({String reason = _kDefaultReason}) async {
  try {
    if (Platform.isWindows) return await _verifyWindows(reason);
    if (Platform.isMacOS) return await _verifyMac(reason);
    if (Platform.isLinux) return await _verifyLinux(reason);
    if (Platform.isAndroid) return await _verifyAndroid(reason);
  } catch (e) {
    return OsAuthResult(OsAuthStatus.failed, 'Could not verify your identity: $e');
  }
  return const OsAuthResult(OsAuthStatus.unavailable,
      'Showing the license key is not supported on this device. Sign in at systemdesk.net to see it.');
}

// ───────────────────────────── macOS / Linux / Android ─────────────────────────────

Future<OsAuthResult> _verifyMac(String reason) async {
  final prompt = reason.replaceAll('"', '').replaceAll('\\', '');
  final r = await Process.run('osascript', [
    '-e',
    'do shell script "true" with administrator privileges with prompt "$prompt"',
  ]);
  if (r.exitCode == 0) return const OsAuthResult(OsAuthStatus.ok);
  if ('${r.stderr}'.contains('-128')) return const OsAuthResult(OsAuthStatus.cancelled);
  return const OsAuthResult(OsAuthStatus.failed, 'Password check failed. Please try again.');
}

Future<OsAuthResult> _verifyLinux(String reason) async {
  final has = await Process.run('which', ['pkexec']);
  if (has.exitCode != 0) {
    return const OsAuthResult(OsAuthStatus.unavailable,
        'Showing the license key needs polkit (pkexec) on this system. Sign in at systemdesk.net to see it.');
  }
  final r = await Process.run('pkexec', ['true']);
  if (r.exitCode == 0) return const OsAuthResult(OsAuthStatus.ok);
  if (r.exitCode == 126) return const OsAuthResult(OsAuthStatus.cancelled);
  return const OsAuthResult(OsAuthStatus.failed, 'Password check failed. Please try again.');
}

Future<OsAuthResult> _verifyAndroid(String reason) async {
  final res = await gFFI.invokeMethodWithResult<String>('verify_device_credential', reason);
  switch (res) {
    case 'ok':
      return const OsAuthResult(OsAuthStatus.ok);
    case 'no_lock':
      return const OsAuthResult(OsAuthStatus.unavailable,
          'Set a screen lock (PIN, pattern or password) on this phone to show your license key, or sign in at systemdesk.net.');
    case 'busy':
      return const OsAuthResult(OsAuthStatus.cancelled);
    default:
      return const OsAuthResult(OsAuthStatus.cancelled);
  }
}

// ───────────────────────────── Windows ─────────────────────────────

Future<OsAuthResult> _verifyWindows(String reason) async {
  final code = await Isolate.run(() => windowsPasswordPrompt(reason)); // the dialog blocks its thread, never the UI
  switch (code) {
    case kWinAuthOk:
      return const OsAuthResult(OsAuthStatus.ok);
    case kWinAuthCancelled:
      return const OsAuthResult(OsAuthStatus.cancelled);
    case kWinAuthWrong:
      return const OsAuthResult(OsAuthStatus.failed, 'That password is not correct.');
    default:
      return const OsAuthResult(OsAuthStatus.failed,
          'Could not check your Windows password. Sign in with a password (not a PIN) or use systemdesk.net.');
  }
}

