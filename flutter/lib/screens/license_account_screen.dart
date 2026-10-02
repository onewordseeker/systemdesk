import 'package:flutter/material.dart';
import 'package:flutter_hbb/services/license_service.dart';

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

    final tierDisplay = {
      'free': 'Free',
      'personal_paid': 'Personal',
      'business_payg': 'Business PAYG',
      'business_org': 'Business Organisation',
    }[tier] ?? tier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Your Plan'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _panelBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _amber.withOpacity(0.4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: _amber),
              const SizedBox(width: 12),
              Text(tierDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _nearWhite)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Today\'s Usage'),
        const SizedBox(height: 8),
        Text('$todayUsed minutes used today', style: const TextStyle(fontSize: 15, color: _nearWhite)),
        const SizedBox(height: 8),
        Text('$deviceCount device(s) linked', style: const TextStyle(color: _muted)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD9534F),
              side: const BorderSide(color: Color(0xFFD9534F)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Sign Out'),
          ),
        ),
      ],
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
