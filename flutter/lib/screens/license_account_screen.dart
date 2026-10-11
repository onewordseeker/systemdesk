import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown from Settings → Account. Handles login, register, and plan display.
class LicenseAccountScreen extends StatefulWidget {
  const LicenseAccountScreen({super.key});

  @override
  State<LicenseAccountScreen> createState() => _LicenseAccountScreenState();
}

class _LicenseAccountScreenState extends State<LicenseAccountScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;
  String _error = '';
  Map<String, dynamic>? _subscription;

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberDeep = Color(0xFFC9820A);
  static const Color _btnText = Color(0xFF241700);
  static const Color _panelBg = Color(0xFF20222A);
  static const Color _settingsBg = Color(0xFF17181C);
  static const Color _nearWhite = Color(0xFFECEAE4);
  static const Color _muted = Color(0xFF8B8F99);
  static const Color _borderDark = Color(0xFF2C2F38);

  @override
  void initState() {
    super.initState();
    if (LicenseService.instance.isLoggedIn) _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    try {
      final data = await LicenseService.instance.getSubscription();
      if (mounted) setState(() => _subscription = data);
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    try {
      if (_isRegister) {
        await LicenseService.instance.register(_usernameCtrl.text.trim(), _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await LicenseService.instance.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
      if (mounted) { setState(() => _loading = false); _loadSubscription(); }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _logout() async {
    await LicenseService.instance.logout();
    if (mounted) setState(() { _subscription = null; });
  }

  Future<void> _delink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelBg,
        title: const Text('Delink this device?', style: TextStyle(color: _nearWhite)),
        content: const Text(
          'This will remove the device from your account. You can re-register it by logging in again.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delink', style: TextStyle(color: Color(0xFFD9534F))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _loading = true; _error = ''; });
    try {
      await LicenseService.instance.delinkCurrentDevice();
      await LicenseService.instance.logout();
      if (mounted) setState(() { _loading = false; _subscription = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  String _formatMinutes(num totalMinutes) {
    final mins = totalMinutes.round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _currentPlatform() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = LicenseService.instance.isLoggedIn;

    return Scaffold(
      backgroundColor: _settingsBg,
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(color: _nearWhite, fontWeight: FontWeight.w600)),
        backgroundColor: _panelBg,
        foregroundColor: _nearWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: _nearWhite),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoggedIn ? _buildAccountView() : _buildAuthForm(),
      ),
    );
  }

  Widget _buildAccountView() {
    final sub = _subscription;
    final tier = sub?['subscription']?['tier'] ?? 'free';
    final todayUsed = (sub?['today_minutes_used'] ?? 0.0) as num;
    final deviceCount = (sub?['device_count'] ?? 0) as num;
    final deviceId = LicenseService.instance.deviceId;

    final tierDisplay = {
      'free': 'Free',
      'personal_paid': 'Personal',
      'business_payg': 'Business PAYG',
      'business_org': 'Business Organisation',
    }[tier] ?? tier;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan card
          _sectionTitle('Your Plan'),
          const SizedBox(height: 8),
          _card(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified, color: _amber, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tierDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _nearWhite)),
                      const SizedBox(height: 2),
                      Text('$deviceCount device(s) linked', style: const TextStyle(color: _muted, fontSize: 13)),
                    ],
                  ),
                ),
                _smallChip('Upgrade', onTap: () async {
                  final url = Uri.parse('https://systemdesk.net/pricing');
                  if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Usage card
          _sectionTitle('Today\'s Usage'),
          const SizedBox(height: 8),
          _card(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B4DB8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFF7B8CDE), size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatMinutes(todayUsed), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _nearWhite)),
                    const SizedBox(height: 2),
                    const Text('used today', style: TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Device card
          _sectionTitle('This Device'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A6B3C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.computer_outlined, color: Color(0xFF4CAF82), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentPlatform(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _nearWhite)),
                          const SizedBox(height: 2),
                          if (deviceId != null)
                            Text(
                              'ID: ${deviceId.substring(0, 12)}…',
                              style: const TextStyle(color: _muted, fontSize: 12, fontFamily: 'monospace'),
                            )
                          else
                            const Text('Not registered', style: TextStyle(color: _muted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (deviceId != null) ...[
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFF2C2F38), height: 1),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _loading ? null : _delink,
                    child: Row(
                      children: [
                        const Icon(Icons.link_off, color: Color(0xFFD9534F), size: 16),
                        const SizedBox(width: 8),
                        const Text('Delink this device', style: TextStyle(color: Color(0xFFD9534F), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_error.isNotEmpty) ...[
            Text(_error, style: const TextStyle(color: Color(0xFFD9534F), fontSize: 13)),
            const SizedBox(height: 12),
          ],

          // Upgrade plan button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://systemdesk.net/pricing');
                if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View Plans & Pricing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: _btnText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD9534F),
                side: const BorderSide(color: Color(0xFFD9534F)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _smallChip(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _amber.withOpacity(0.5)),
        ),
        child: Text(label, style: const TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_isRegister ? 'Create Account' : 'Sign In'),
        const SizedBox(height: 4),
        Text(
          _isRegister
              ? 'Create an account to link your device and upgrade your plan.'
              : 'Sign in to access your plan and usage across devices.',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _darkField(_usernameCtrl, 'Username'),
        if (_isRegister) ...[
          const SizedBox(height: 16),
          _darkField(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
        ],
        const SizedBox(height: 16),
        _darkField(_passwordCtrl, 'Password', obscureText: true, onSubmitted: (_) => _submit()),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Color(0xFFD9534F), fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _amber,
              foregroundColor: _btnText,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Color(0xFF241700), strokeWidth: 2))
                : Text(_isRegister ? 'Create Account' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
            child: Text(
              _isRegister ? 'Already have an account? Sign in' : 'No account? Create one',
              style: const TextStyle(color: _amberDeep),
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: _nearWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _borderDark),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _amber),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: _panelBg,
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _nearWhite),
      );
}
