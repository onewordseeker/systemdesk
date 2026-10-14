import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_hbb/screens/sd_dialog.dart';
import 'package:flutter_hbb/services/os_auth.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

// Palette of the home screen cards (Device ID / Temp Password), light and dark.
class _P {
  _P(BuildContext context) : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get card => dark ? const Color(0xFF20222A) : const Color(0xFFF7F4ED);
  Color get field => dark ? const Color(0xFF24252B) : Colors.white;
  Color get border => dark ? const Color(0xFF30323A) : const Color(0xFFECE7DB);
  Color get ink => dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
  Color get muted => dark ? const Color(0xFF8B8F99) : const Color(0xFF8F887B);
  static const amber = Color(0xFFF59E0B);
  static const amberDeep = Color(0xFFC9820A);
  static const onAmber = Color(0xFF241700);
  static const danger = Color(0xFFD9534F);
  static const good = Color(0xFF3FB27F);
}

const _tierNames = {
  'free': 'Free',
  'personal_paid': 'Personal',
  'business_payg': 'Business PAYG',
  'business_org': 'Business Organisation',
};

/// Everything about the signed-in account in one place (Settings > Account): who you are, your plan, your license
/// key (hidden until you ask), today's usage and this device. Signed out, it is the sign-in / create-account form.
class LicenseAccountPanel extends StatefulWidget {
  const LicenseAccountPanel({super.key});

  @override
  State<LicenseAccountPanel> createState() => _LicenseAccountPanelState();
}

class _LicenseAccountPanelState extends State<LicenseAccountPanel> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _isRegister = false;
  bool _showKey = false; // the key is hidden by default, like a password
  bool _loadFailed = false;
  String _error = '';
  Map<String, dynamic>? _sub; // GET /subscription: plan, license, usage
  Map<String, dynamic>? _me; // GET /auth/me: username, email
  Worker? _loginWatch;
  // showing or copying the key needs the computer's password; one check covers the next 30 seconds
  static const _keyWindow = Duration(seconds: 30);
  DateTime? _unlockedUntil;
  Timer? _hideTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    if (LicenseService.instance.isLoggedIn) _load();
    // signing in/out anywhere (also a login the server revoked) switches this panel
    _loginWatch = ever(LicenseService.instance.isLoggedInRx, (bool loggedIn) {
      if (!mounted) return;
      if (loggedIn) {
        _load();
      } else {
        _hideKey();
        setState(() {
          _sub = null;
          _me = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _loginWatch?.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final results = await Future.wait([
        LicenseService.instance.getSubscription(),
        LicenseService.instance.getProfile(),
      ]);
      if (mounted) {
        setState(() {
          _sub = results[0];
          _me = results[1];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_isRegister) {
        await LicenseService.instance
            .register(_usernameCtrl.text.trim(), _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await LicenseService.instance.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
      _passwordCtrl.clear();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      // this device may not use the account: say why in a proper dialog, not a red line under the form
      if (e is LicenseException && (e.code == 'DEVICE_LIMIT' || e.code == 'DEVICE_ALREADY_BOUND') && mounted) {
        final full = e.code == 'DEVICE_LIMIT';
        await showSdDialog(
          context,
          icon: full ? Icons.devices_other_outlined : Icons.lock_outline,
          tone: SdTone.warning,
          title: full ? "This device can't use this account yet" : 'This device belongs to another account',
          message: e.message,
          facts: full
              ? const [
                  'Sign in on one of your linked devices instead',
                  'Or unbind a linked device in your account on the website, then sign in here again',
                ]
              : const [],
          confirmLabel: 'OK',
        );
        return;
      }
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ───────────────────────────── license key (needs the computer's password) ─────────────────────────────

  bool get _unlocked => _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  String get _authHint => Platform.isAndroid ? 'your screen lock' : 'your computer password';

  Future<bool> _unlock() async {
    if (_unlocked) return true;
    if (_checking) return false;
    setState(() {
      _checking = true;
      _error = '';
    });
    final r = await verifyOsUser();
    if (!mounted) return false;
    setState(() {
      _checking = false;
      if (!r.ok && r.status != OsAuthStatus.cancelled) _error = r.message;
    });
    if (!r.ok) return false;
    _unlockedUntil = DateTime.now().add(_keyWindow);
    return true;
  }

  void _hideKey() {
    _hideTimer?.cancel();
    _unlockedUntil = null;
    if (mounted) setState(() => _showKey = false);
  }

  Future<void> _toggleKey() async {
    if (_showKey) {
      _hideKey();
      return;
    }
    if (!await _unlock()) return;
    setState(() => _showKey = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_keyWindow, _hideKey);
  }

  Future<void> _copyKey(String key) async {
    if (!await _unlock()) return;
    await Clipboard.setData(ClipboardData(text: key));
    showToast(translate('Copied'));
  }

  Future<void> _delink() async {
    // already used this month's unbind? say so up front instead of after a click on "Unbind"
    final lock = await LicenseService.instance.getUnbindStatus();
    if (!mounted) return;
    final days = lock?['days'] ?? 30;
    if (lock != null && lock['locked'] == true) {
      final next = _fmtDate(lock['next_allowed_at']);
      await showSdDialog(
        context,
        icon: Icons.lock_clock_outlined,
        tone: SdTone.warning,
        title: "You can't unbind a device right now",
        message: 'You already unbound a device in the last $days days. '
            'You can unbind another device${next != null ? ' on $next' : ' later'}.',
        facts: const ['Until then you can still link new devices if you have free slots'],
        confirmLabel: 'OK',
      );
      return;
    }
    final fp = LicenseService.instance.hardwareFingerprint;
    final next = DateTime.now().add(Duration(days: days is int ? days : 30));
    final confirmed = await showSdDialog(
      context,
      icon: Icons.link_off,
      tone: SdTone.danger,
      title: 'Unbind this device?',
      message: 'This device is removed from your account and you are signed out here. '
          'You can sign in again later if a device slot is free.',
      subject: SdDialogSubject(Icons.computer_outlined, _platform(), sub: fp != null ? 'FP ${fp.substring(0, 16)}…' : null),
      facts: const [
        'Any session running on this device ends right away',
        'The slot becomes free for another device',
      ],
      warning: SdDialogWarning(
        'You can unbind only one device every $days days',
        'Once you unbind this device, no other device can be unbound until ${_fmtDate(next.toIso8601String()) ?? 'later'}. '
            'Linking a new device to a free slot is not limited.',
      ),
      confirmLabel: 'Unbind device',
      cancelLabel: 'Cancel',
    );
    if (!confirmed) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await LicenseService.instance.delinkCurrentDevice();
      await gFFI.userModel.logOut();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openPlans() async {
    final url = Uri.parse('https://systemdesk.net/pricing');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ───────────────────────────── helpers ─────────────────────────────

  String _formatMinutes(num totalMinutes) {
    final mins = totalMinutes.round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String? _fmtDate(dynamic iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _platform() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  // ───────────────────────────── building blocks ─────────────────────────────

  Widget _card(BuildContext context, {required Widget child}) {
    final p = _P(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: p.border, width: 1),
      ),
      child: child,
    );
  }

  Widget _label(BuildContext context, String text, {List<Widget> actions = const []}) {
    final p = _P(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.muted, letterSpacing: 0.6)),
        if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }

  Widget _iconAction(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: _P(context).muted),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _pillButton(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _P.amber,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(color: _P.onAmber, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );

  // ───────────────────────────── signed in ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Align loosens the list's forced full width so the cards keep a readable width on big windows
    return Align(
      alignment: Alignment.topLeft,
      child: Obx(() => LicenseService.instance.isLoggedInRx.value
          ? _accountView(context)
          : _authForm(context)),
    );
  }

  Widget _accountView(BuildContext context) {
    final p = _P(context);
    final sub = (_sub?['subscription'] as Map?) ?? const {};
    final license = _sub?['license'] as Map?; // null while loading or on an older backend
    final tier = (license?['tier'] ?? sub['tier'] ?? 'free').toString();
    final state = (license?['state'] ?? (tier == 'free' ? 'free' : 'active')).toString();
    final key = license?['key']?.toString();
    final loaded = _sub != null;

    final deviceCount = (_sub?['device_count'] ?? 0) as num;
    final maxDevices = (sub['max_devices'] ?? 0) as num;
    final dailyLimit = (sub['daily_limit_minutes'] ?? 0) as num;
    final todayUsed = (_sub?['today_minutes_used'] ?? 0) as num;
    final validUntil = _fmtDate(license?['expires_at'] ?? sub['expires_at']);
    final cancelling = license?['cancel_at_period_end'] == true;

    final username = (_me?['user']?['username'] ?? gFFI.userModel.userName.value).toString();
    final email = (_me?['user']?['email'] ?? '').toString();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 730), // same right edge as the cards on the other tabs
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // who you are
          _card(
            context,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _P.amber,
                  child: Text(
                    username.isEmpty ? '?' : username.characters.first.toUpperCase(),
                    style: const TextStyle(color: _P.onAmber, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username.isEmpty ? 'Signed in' : username,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(fontSize: 12, color: p.muted)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => gFFI.userModel.logOut(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _P.danger,
                    side: const BorderSide(color: _P.danger),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Sign out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // plan + today's usage side by side, like Device ID / Temp Password on the home screen
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _card(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, 'Plan', actions: [
                          _pillButton(tier == 'free' ? 'Upgrade' : 'Change plan', _openPlans),
                        ]),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: Text(loaded ? (_tierNames[tier] ?? tier) : '…',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink)),
                            ),
                            const SizedBox(width: 8),
                            if (loaded && state == 'active' && tier != 'free') _chip('Active', _P.good),
                            if (loaded && state == 'expired') _chip('Expired', _P.danger),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          !loaded
                              ? ' '
                              : tier == 'free'
                                  ? 'Free plan'
                                  : state == 'expired'
                                      ? (validUntil != null ? 'Expired on $validUntil' : 'Expired')
                                      : validUntil == null
                                          ? 'No expiry date'
                                          : cancelling
                                              ? 'Cancels on $validUntil'
                                              : 'Valid until $validUntil',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loaded
                              ? '$deviceCount of ${maxDevices > 0 ? maxDevices : 'unlimited'} devices linked'
                              : ' ',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _card(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(context, 'Used today'),
                        const SizedBox(height: 8),
                        Text(loaded ? _formatMinutes(todayUsed) : '…',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink)),
                        const SizedBox(height: 4),
                        Text(
                          !loaded
                              ? ' '
                              : dailyLimit > 0
                                  ? 'of ${_formatMinutes(dailyLimit)} daily limit'
                                  : 'No daily limit',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                        if (loaded && dailyLimit > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (todayUsed / dailyLimit).clamp(0, 1).toDouble(),
                              minHeight: 5,
                              backgroundColor: p.border,
                              valueColor: const AlwaysStoppedAnimation(_P.amber),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // license key: hidden by default like a password (eye to show, copy always copies the real key)
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context, 'License key', actions: [
                  if (key != null) ...[
                    _iconAction(
                      context,
                      _showKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      _showKey ? 'Hide license key' : 'Show license key (asks for $_authHint)',
                      _toggleKey,
                    ),
                    const SizedBox(width: 4),
                    _iconAction(context, Icons.copy_outlined, 'Copy license key (asks for $_authHint)',
                        () => _copyKey(key)),
                  ],
                ]),
                const SizedBox(height: 8),
                if (!loaded)
                  Text('…', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.muted))
                else if (key == null)
                  Text(
                    tier == 'free' ? 'FREE' : 'Not available yet',
                    style: TextStyle(
                        fontSize: tier == 'free' ? 24 : 16,
                        fontWeight: FontWeight.w700,
                        color: p.muted,
                        letterSpacing: tier == 'free' ? 3 : 0),
                  )
                else
                  Row(
                    children: [
                      Flexible(
                        child: SelectableText(
                          _showKey ? key : _maskKey(key),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: state == 'expired' ? p.muted : _P.amber,
                            decoration: state == 'expired' ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (state == 'expired') _chip('Expired', _P.danger),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  !loaded
                      ? ' '
                      : tier == 'free' && key == null
                          ? 'You are on the Free plan, so there is no license key. It appears here when you upgrade.'
                          : 'Identifies your paid subscription: quote it if you contact support. You do not need to type it anywhere, signing in activates your plan. Showing or copying it asks for $_authHint.',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // this device
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context, 'This device'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.computer_outlined, size: 20, color: p.muted),
                    const SizedBox(width: 10),
                    Text(_platform(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
                    const SizedBox(width: 10),
                    if (LicenseService.instance.deviceId != null) _chip('Linked', _P.good),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  LicenseService.instance.hardwareFingerprint != null
                      ? 'FP ${LicenseService.instance.hardwareFingerprint!.substring(0, 16)}…'
                      : (LicenseService.instance.deviceId != null ? 'Registered' : 'Not registered'),
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
                if (LicenseService.instance.deviceId != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: p.border, height: 1),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _busy ? null : _delink,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_off, size: 15, color: _P.danger),
                          SizedBox(width: 6),
                          Text('Delink this device',
                              style: TextStyle(color: _P.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_loadFailed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text("Couldn't load your plan details.", style: TextStyle(fontSize: 12, color: p.muted)),
                TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _P.amberDeep))),
              ],
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: _P.danger, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // SD-ABCD-EFGH-IJKL-MNOP -> SD-••••-••••-••••-••••
  String _maskKey(String key) =>
      key.split('-').map((part) => part == 'SD' ? part : '••••').join('-');

  // ───────────────────────────── signed out ─────────────────────────────

  Widget _authForm(BuildContext context) {
    final p = _P(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isRegister ? 'Create account' : 'Sign in',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 4),
            Text(
              _isRegister
                  ? 'Create an account to link your device and upgrade your plan.'
                  : 'Sign in to access your plan, license key and usage across devices.',
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
            const SizedBox(height: 18),
            _field(context, _usernameCtrl, 'Username'),
            if (_isRegister) ...[
              const SizedBox(height: 12),
              _field(context, _emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
            ],
            const SizedBox(height: 12),
            _field(context, _passwordCtrl, 'Password', obscure: true, onSubmitted: (_) => _submit()),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: _P.danger, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.amber,
                  foregroundColor: _P.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: _P.onAmber, strokeWidth: 2))
                    : Text(_isRegister ? 'Create account' : 'Sign in',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _isRegister = !_isRegister;
                  _error = '';
                }),
                child: Text(_isRegister ? 'Already have an account? Sign in' : 'No account? Create one',
                    style: const TextStyle(color: _P.amberDeep)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(BuildContext context, TextEditingController ctrl, String label,
      {bool obscure = false, TextInputType? keyboardType, ValueChanged<String>? onSubmitted}) {
    final p = _P(context);
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(color: p.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.muted),
        filled: true,
        fillColor: p.field,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.border),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _P.amber),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
