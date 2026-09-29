import 'package:flutter/material.dart';
import 'package:flutter_hbb/services/license_service.dart';

/// Shown from Settings → Account. Handles login, register, and plan display.
class LicenseAccountScreen extends StatefulWidget {
  const LicenseAccountScreen({super.key});

  @override
  State<LicenseAccountScreen> createState() => _LicenseAccountScreenState();
}

class _LicenseAccountScreenState extends State<LicenseAccountScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;
  String _error = '';
  Map<String, dynamic>? _subscription;

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
        await LicenseService.instance.register(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await LicenseService.instance.login(_emailCtrl.text.trim(), _passwordCtrl.text);
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
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        elevation: 0,
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
            color: const Color(0xFFE53935).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFFE53935)),
              const SizedBox(width: 12),
              Text(tierDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Today\'s Usage'),
        const SizedBox(height: 8),
        Text('$todayUsed minutes used today', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        Text('$deviceCount device(s) linked', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
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
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          onSubmitted: (_) => _submit(),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isRegister ? 'Create Account' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
            child: Text(
              _isRegister ? 'Already have an account? Sign in' : 'No account? Create one',
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      );
}
