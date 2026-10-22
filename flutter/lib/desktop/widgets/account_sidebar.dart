import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_hbb/services/server_profile.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

// The sidebar is dark in both themes (same palette as desktop_home_page.dart).
const _kCard = Color(0xFF24262E);
const _kBorder = Color(0xFF333640);
const _kInk = Color(0xFFE2E4EA);
const _kMuted = Color(0xFF8B8F99);
const _kAmber = Color(0xFFF59E0B);
const _kOnAmber = Color(0xFF241700);
const _kGood = Color(0xFF3FB27F);
const _kDanger = Color(0xFFE5645F);

void _openSettings(SettingsTabKey page) => DesktopSettingPage.switch2page(page);

/// A page of the account portal of the server this build talks to (the TEST portal on test builds).
Future<void> openPortalPage(String page) async {
  final host = kIsTestMode ? 'https://my.test.systemdesk.net' : 'https://my.systemdesk.net';
  final url = Uri.parse('$host/$page');
  if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
}

String _minutes(num m) {
  final mins = m.round();
  if (mins < 60) return '${mins}m';
  final h = mins ~/ 60, r = mins % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

String? _date(DateTime? d) {
  if (d == null) return null;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ───────────────────────────── title bar: the current plan ─────────────────────────────

/// The current plan in the top bar ("Free license (non-commercial use)", "Personal (paid)", ...). Click: the Account page.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final info = AccountSummary.instance.info.value;
      final text = planTitle(info);
      final paid = info != null && !info.isFree;
      return Tooltip(
        message: text,
        child: InkWell(
          onTap: () => _openSettings(SettingsTabKey.account),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 330),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1F2027) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dark ? const Color(0xFF333640) : const Color(0xFFECE7DB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: paid ? _kGood : _kAmber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: dark ? const Color(0xFFE2E4EA) : const Color(0xFF1A1712),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).marginOnly(right: 6);
    });
  }
}

// ───────────────────────────── sidebar: settings menu ─────────────────────────────

/// "Settings" in the sidebar menu with its pages below. One click on the row opens Settings, the arrow folds the pages in and out
/// (folded at first, so the sidebar stays calm and the plan card has room).
class SidebarSettingsNav extends StatefulWidget {
  const SidebarSettingsNav({super.key});

  @override
  State<SidebarSettingsNav> createState() => _SidebarSettingsNavState();
}

class _SidebarSettingsNavState extends State<SidebarSettingsNav> {
  static bool _open = false; // stays as the user left it while the window lives

  @override
  Widget build(BuildContext context) {
    final keys = DesktopSettingPage.tabKeys;
    final pages = <(SettingsTabKey, String)>[
      (SettingsTabKey.account, 'Account'),
      (SettingsTabKey.safety, 'Security'),
      (SettingsTabKey.network, 'Network'),
      (SettingsTabKey.display, 'Display'),
    ].where((p) => keys.contains(p.$1)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavRow(
          icon: Icons.settings_outlined,
          label: translate('Settings'),
          onTap: () {
            if (keys.isNotEmpty) _openSettings(keys[0]);
            if (pages.isNotEmpty && !_open) setState(() => _open = true);
          },
          trailing: pages.isEmpty
              ? null
              : Tooltip(
                  message: _open ? 'Hide pages' : 'Show pages',
                  child: InkWell(
                    onTap: () => setState(() => _open = !_open),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: AnimatedRotation(
                        turns: _open ? 0.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.chevron_right, size: 18, color: _kMuted),
                      ),
                    ),
                  ),
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open || pages.isEmpty
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(left: 35, right: 10, bottom: 4),
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(border: Border(left: BorderSide(color: _kBorder))),
                  child: Column(
                    children: [for (final p in pages) _SubNavRow(label: p.$2, onTap: () => _openSettings(p.$1))],
                  ),
                ),
        ),
      ],
    );
  }
}

/// A menu row like the ones of the sidebar's own menu (icon in a 30 px box, label), with a hover state and an optional trailing widget.
class _NavRow extends StatefulWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hover = v),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(color: _hover ? _kCard : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            SizedBox(width: 30, height: 30, child: Icon(widget.icon, size: 17, color: _hover ? _kInk : _kMuted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _hover ? _kInk : _kMuted)),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

class _SubNavRow extends StatefulWidget {
  const _SubNavRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_SubNavRow> createState() => _SubNavRowState();
}

class _SubNavRowState extends State<_SubNavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hover = v),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 32,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _hover ? _kCard : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(translate(widget.label),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _hover ? _kInk : const Color(0xFFB7BAC4))),
      ),
    );
  }
}

// ───────────────────────────── sidebar: plan + usage ─────────────────────────────

/// The middle of the sidebar: how much of today's allowance is left, and what the plan allows.
class SidebarInfo extends StatelessWidget {
  const SidebarInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('PLAN & USAGE'),
              Obx(() {
                if (!LicenseService.instance.isLoggedInRx.value) return const _SignedOutCard();
                final info = AccountSummary.instance.info.value;
                if (info == null) return _LoadingCard(AccountSummary.instance.loading.value);
                return _UsageCard(info);
              }),
            ],
          ),
        ),
        // when the window is short and the card scrolls, it fades out above the account card instead of being cut off
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 14,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x001A1C22), Color(0xFF1A1C22)]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 1.0)),
      );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder)),
        child: child,
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard(this.loading);
  final bool loading;

  @override
  Widget build(BuildContext context) => _CardShell(
        child: loading
            // a quiet placeholder with the card's own shape instead of a spinner
            ? Column(
                children: [
                  Container(width: 92, height: 92, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2B2D36))),
                  const SizedBox(height: 14),
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 10,
                      decoration: BoxDecoration(color: const Color(0xFF2B2D36), borderRadius: BorderRadius.circular(5)),
                    ),
                ],
              )
            : Row(
                children: [
                  const Expanded(child: Text('Your plan could not be loaded', style: TextStyle(fontSize: 11.5, color: _kMuted))),
                  InkWell(
                    onTap: AccountSummary.instance.refresh,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.refresh, size: 16, color: _kAmber)),
                  ),
                ],
              ),
      );
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Free license', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 4),
            const Text('Sign in to see your plan, your usage and how long it lasts.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: _kMuted)),
            const SizedBox(height: 12),
            _SmallButton(label: 'Sign in', filled: true, onTap: () => _openSettings(SettingsTabKey.account)),
          ],
        ),
      );
}

class _UsageCard extends StatelessWidget {
  const _UsageCard(this.info);
  final AccountInfo info;

  @override
  Widget build(BuildContext context) {
    final limited = info.dailyLimit > 0;
    final usedFraction = limited ? (info.usedToday / info.dailyLimit).clamp(0.0, 1.0) : 1.0;
    final ringColor = !limited ? _kGood : (usedFraction >= 0.9 ? _kDanger : _kAmber);
    final days = info.daysLeft();
    final ends = _date(info.expiresAt);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // one focus: how much of today is left
          Center(
            child: _Donut(
              fraction: usedFraction,
              color: ringColor,
              big: limited ? _minutes(info.minutesLeftToday) : '∞',
              small: limited ? 'left today' : 'no daily limit',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            limited ? '${_minutes(info.usedToday)} of ${_minutes(info.dailyLimit)} used today' : '${_minutes(info.usedToday)} used today',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: _kMuted),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),
          _Row('Per session', info.sessionLimit > 0 ? _minutes(info.sessionLimit) : 'No limit'),
          _Row('Devices', info.maxDevices > 0 ? '${info.devices} of ${info.maxDevices}' : '${info.devices}'),
          _Row('Sessions at once', info.maxConcurrent > 0 ? '${info.maxConcurrent}' : 'No limit'),
          if (info.hasAddons) _Row('Add-ons', info.addonSummary),
          if (info.isShared) _Row('Plan shared by', info.sharedBy!),
          if (!info.isFree && ends != null) ...[
            _Row(info.isShared ? 'Shared until' : (info.cancelling ? 'Ends' : 'Renews'), ends),
            if (days != null) _DaysBar(info: info, days: days),
          ] else if (!info.isFree)
            const _Row('Plan', 'Active')
          else
            _Row('Plan', info.expired ? 'Expired' : 'Free, no end date'),
          if (info.isFree) ...[
            const SizedBox(height: 12),
            _SmallButton(label: 'Upgrade plan', filled: true, onTap: () => _openSettings(SettingsTabKey.account)),
          ],
          // more connections or devices on top of the plan, bought on the website (shown when something is for sale or already held)
          if ((info.addonsForSale || info.hasAddons) && (info.maxDevices > 0 || info.maxConcurrent > 0)) ...[
            const SizedBox(height: 8),
            _SmallButton(label: 'Add connections or devices', onTap: () => openPortalPage('addons')),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: _kMuted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kInk, fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ],
        ),
      );
}

/// The paid plan's time as a slim bar (the days that are left of the period) with the number under it.
class _DaysBar extends StatelessWidget {
  const _DaysBar({required this.info, required this.days});
  final AccountInfo info;
  final int days;

  @override
  Widget build(BuildContext context) {
    final total = (info.startedAt != null && info.expiresAt != null) ? math.max(1, info.expiresAt!.difference(info.startedAt!).inHours / 24) : 30.0;
    final fraction = (days / total).clamp(0.0, 1.0);
    final color = days <= 3 ? _kDanger : (days <= 7 ? _kAmber : _kGood);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 5, backgroundColor: const Color(0xFF30323A), valueColor: AlwaysStoppedAnimation(color)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(days == 0 ? 'ends today' : '$days ${days == 1 ? 'day' : 'days'} left',
              textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: days <= 7 ? color : _kMuted)),
        ],
      ),
    );
  }
}

/// A ring (animated when the value changes) with the figure in the middle.
class _Donut extends StatelessWidget {
  const _Donut({required this.fraction, required this.color, required this.big, required this.small});
  final double fraction;
  final Color color;
  final String big, small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(painter: _DonutPainter(value, color), child: child),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _kInk, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 1),
              Text(small, style: const TextStyle(fontSize: 10, color: _kMuted, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.fraction, this.color);
  final double fraction;
  final Color color;
  static const _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = const Color(0xFF30323A));
    if (fraction <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction.clamp(0.0, 1.0), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.fraction != fraction || old.color != color;
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.filled = false});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? _kAmber : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: filled ? null : Border.all(color: _kBorder),
          ),
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: filled ? _kOnAmber : _kInk)),
        ),
      );
}

// ───────────────────────────── sidebar: who is signed in ─────────────────────────────

/// Bottom of the sidebar: the signed-in person (initials, name, plan) and Sign out. [testBadge] = the TEST pill of test builds.
class SidebarAccountFooter extends StatelessWidget {
  const SidebarAccountFooter({super.key, this.testBadge});
  final Widget? testBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
      child: Obx(() {
        final info = AccountSummary.instance.info.value;
        final signedIn = LicenseService.instance.isLoggedInRx.value;
        final name = info?.shownName ?? (gFFI.userModel.userName.value.isNotEmpty ? gFFI.userModel.userName.value : 'Guest');
        final initials = info?.initials ?? (signedIn ? initialsOf('', gFFI.userModel.userName.value) : '');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: signedIn ? _kAmber : const Color(0xFF3A3D48),
                  child: signedIn
                      ? Text(initials, style: const TextStyle(color: _kOnAmber, fontWeight: FontWeight.w800, fontSize: 13))
                      : const Icon(Icons.person_outline, size: 18, color: _kMuted),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _kInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(signedIn ? planShort(info) : 'Not signed in',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _kMuted, fontSize: 10.5)),
                      if (testBadge != null) ...[const SizedBox(height: 3), testBadge!],
                    ],
                  ),
                ),
                if (signedIn)
                  Tooltip(
                    message: translate('Sign out'),
                    child: InkWell(
                      onTap: () => gFFI.userModel.logOut(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                        child: const Icon(Icons.logout, size: 15, color: _kMuted),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}