import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_hbb/services/server_profile.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

/// The sign-in of the new design (`Sign in` board): a card over the blurred app, opened by the avatar of a person who is not signed in. It signs in with the
/// same call as Settings > Account, so the two cannot disagree; a person who is signed in never sees it.
Future<void> showSdSignIn() {
  return gFFI.dialogManager.show<void>(
    (setState, close, context) => SdSignInModal(onClose: () => close()),
    tag: 'sd-signin',
    forceGlobal: true,
  );
}

/// `.mark`: the navy tile with the logo on it (and, in other cards, an icon)
class SdMarkTile extends StatelessWidget {
  const SdMarkTile({super.key, required this.child});
  final Widget child;

  /// the real SystemDesk logo (assets/logo_white.svg) on the tile
  static Widget logo() => SvgPicture.asset('assets/logo_white.svg', width: 34);

  @override
  Widget build(BuildContext context) {
    return SdBox(
      radius: 14,
      color: const Color(0xFF1A1712),
      width: 56,
      height: 56,
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// `.fld`: a label above an inset field (48 high). The field has a gold ring while it has the focus.
class SdField extends StatefulWidget {
  const SdField({super.key, required this.label, required this.controller, this.obscure = false, this.onSubmitted, this.labelTrailing, this.autofocus = false});
  final String label;
  final TextEditingController controller;
  final bool obscure, autofocus;
  final ValueChanged<String>? onSubmitted;

  /// at the right end of the label line (Forgot password?)
  final Widget? labelTrailing;

  @override
  State<SdField> createState() => _SdFieldState();
}

class _SdFieldState extends State<SdField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(widget.label, style: sdTs(13.5, FontWeight.w400, t.mut))),
          if (widget.labelTrailing != null) widget.labelTrailing!,
        ]),
        const SizedBox(height: 6),
        SdInset(
          radius: 12,
          ring: _focus.hasFocus,
          height: 48,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            obscureText: widget.obscure,
            onSubmitted: widget.onSubmitted,
            cursorColor: t.goldTxt,
            style: sdTs(15.5, FontWeight.w400, t.ink),
            textAlignVertical: TextAlignVertical.center,
            decoration: const InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}

/// What is inside the card of the sign-in. It draws and nothing else, so the real dialog and the test picture use the same widget.
class SdSignInForm extends StatelessWidget {
  const SdSignInForm({
    super.key,
    required this.user,
    required this.password,
    this.error = '',
    this.busy = false,
    required this.onSubmit,
    this.onGuest,
    this.onCreate,
    this.onForgot,
  });
  final TextEditingController user, password;
  final String error;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback? onGuest, onCreate, onForgot;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SdMarkTile(child: SdMarkTile.logo()),
        const SizedBox(height: 18),
        Text('Sign in to SystemDesk', style: sdTs(24, FontWeight.w600, t.ink, ls: -0.24)),
        const SizedBox(height: 6),
        Text('Your plan, devices and usage follow you to every computer.', style: sdTs(14.5, FontWeight.w400, t.mut)),
        const SizedBox(height: 16),
        SdField(label: 'Username or email', controller: user, autofocus: true, onSubmitted: (_) => FocusScope.of(context).nextFocus()),
        const SizedBox(height: 16),
        SdField(
          label: 'Password',
          controller: password,
          obscure: true,
          onSubmitted: (_) => onSubmit(),
          labelTrailing: onForgot == null
              ? null
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(onTap: onForgot, child: Text('Forgot password?', style: sdTs(12.5, FontWeight.w600, t.goldTxt))),
                ),
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(error, style: sdTs(13.5, FontWeight.w500, t.bad)),
        ],
        const SizedBox(height: 22),
        SdButton(label: 'Sign in', kind: SdBtnKind.gold, block: true, height: 50, fontSize: 16, busy: busy, onTap: onSubmit),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SdLink('Continue as guest', onTap: onGuest),
          SdLink('Create an account', onTap: onCreate),
        ]),
      ],
    );
  }
}

class SdSignInModal extends StatefulWidget {
  const SdSignInModal({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<SdSignInModal> createState() => _SdSignInModalState();
}

class _SdSignInModalState extends State<SdSignInModal> {
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Type your username or email and your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await LicenseService.instance.login(_user.text.trim(), _password.text);
      if (mounted) widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is LicenseException ? e.message : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // Creating an account needs the "I am not a robot" check, and a forgotten password needs the emailed code, so both happen on the website.
  Future<void> _portal(String page) async {
    final host = kIsTestMode ? 'https://my.test.systemdesk.net' : 'https://my.systemdesk.net';
    final url = Uri.parse('$host/$page');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SdModal(
      maxWidth: 440,
      onCancel: widget.onClose,
      content: SdSignInForm(
        user: _user,
        password: _password,
        error: _error,
        busy: _busy,
        onSubmit: _submit,
        onGuest: widget.onClose,
        onCreate: () => _portal('register'),
        onForgot: () => _portal('forgot-password'),
      ),
    );
  }
}
