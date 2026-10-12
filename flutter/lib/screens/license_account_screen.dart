import 'package:flutter/material.dart';

import 'license_account_panel.dart';

/// Full-page version of the account panel, for the places that push a route (address book / group "Login", mobile
/// settings). Settings > Account on desktop shows the same [LicenseAccountPanel] inline.
class LicenseAccountScreen extends StatelessWidget {
  const LicenseAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFECEAE4) : const Color(0xFF1A1712);
    return Scaffold(
      appBar: AppBar(
        title: Text('Account', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
        backgroundColor: dark ? const Color(0xFF20222A) : const Color(0xFFF7F4ED),
        foregroundColor: ink,
        elevation: 0,
        iconTheme: IconThemeData(color: ink),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: LicenseAccountPanel(),
      ),
    );
  }
}
