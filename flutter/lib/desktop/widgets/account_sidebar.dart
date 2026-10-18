import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:get/get.dart';

// The sidebar is dark in both themes (same palette as desktop_home_page.dart).
const _kCard = Color(0xFF24262E);
const _kCardHover = Color(0xFF2C2E37);
const _kBorder = Color(0xFF333640);
const _kInk = Color(0xFFE2E4EA);
const _kMuted = Color(0xFF8B8F99);
const _kAmber = Color(0xFFF59E0B);
const _kOnAmber = Color(0xFF241700);
const _kGood = Color(0xFF3FB27F);
const _kDanger = Color(0xFFE5645F);

void _openSettings(SettingsTabKey page) => DesktopSettingPage.switch2page(page);

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

// ───────────────────────────── sidebar: shortcuts + usage ─────────────────────────────

/// The middle of the sidebar: quick links to the settings pages and the account's usage / plan.
class SidebarInfo extends StatelessWidget {
  const SidebarInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final keys = DesktopSettingPage.tabKeys;
    final shortcuts = <(SettingsTabKey, IconData, String)>[
      (SettingsTabKey.account, Icons.person_outline, 'Account'),
      (SettingsTabKey.safety, Icons.shield_outlined, 'Security'),
      (SettingsTabKey.network, Icons.lan_outlined, 'Network'),
      (SettingsTabKey.display, Icons.monitor_outlined, 'Display'),
    ].where((s) => keys.contains(s.$1)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shortcuts.isNotEmpty) ...[
            const _SectionLabel('QUICK SETTINGS'),
            Row(
              children: [
                for (var i = 0; i < shortcuts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(child: _ShortcutTile(icon: shortcuts[i].$2, label: shortcuts[i].$3, onTap: () => _openSettings(shortcuts[i].$1))),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          const _SectionLabel('YOUR PLAN & USAGE'),
          Obx(() {
            if (!LicenseService.instance.isLoggedInRx.value) return const _SignedOutCard();
            final info = AccountSummary.instance.info.value;
            if (info == null) return _LoadingCard(AccountSummary.instance.loading.value);
            return _UsageCard(info);
          }),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.9)),
      );
}

class _ShortcutTile extends StatefulWidget {
  const _ShortcutTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ShortcutTile> createState() => _ShortcutTileState();
}

class _ShortcutTileState extends State<_ShortcutTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) => setState(() => _hover = v),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: _hover ? _kCardHover : _kCard,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 16, color: _hover ? _kAmber : _kMuted),
            const SizedBox(height: 3),
            Text(
              translate(widget.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: _hover ? _kInk : const Color(0xFFB7BAC4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder)),
        child: child,
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard(this.loading);
  final bool loading;

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Row(
          children: [
            if (loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kAmber)),
            if (loading) const SizedBox(width: 10),
            Expanded(
              child: Text(loading ? 'Loading your plan…' : 'Your plan could not be loaded',
                  style: const TextStyle(fontSize: 11.5, color: _kMuted)),
            ),
            if (!loading)
              InkWell(
                onTap: AccountSummary.instance.refresh,
                child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.refresh, size: 15, color: _kAmber)),
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
            const Text('Free license', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 3),
            const Text('Sign in to see your plan, your usage and how long it lasts.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: _kMuted)),
            const SizedBox(height: 10),
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
    // 1) today's usage: the ring is what is used of the daily limit
    final limited = info.dailyLimit > 0;
    final usedFraction = limited ? (info.usedToday / info.dailyLimit).clamp(0.0, 1.0) : 1.0;
    final usageColor = !limited ? _kGood : (usedFraction >= 0.9 ? _kDanger : _kAmber);

    // 2) the plan's time: a paid plan shows the days that are left, the free licence has none, so it shows the devices
    final days = info.daysLeft();
    Widget second;
    if (!info.isFree && days != null) {
      final total = (info.startedAt != null && info.expiresAt != null)
          ? math.max(1, info.expiresAt!.difference(info.startedAt!).inHours / 24)
          : 30.0;
      second = _Donut(
        fraction: (days / total).clamp(0.0, 1.0),
        color: days <= 3 ? _kDanger : (days <= 7 ? _kAmber : _kGood),
        big: '${days}d',
        small: 'left',
        caption: 'Plan',
      );
    } else if (!info.isFree) {
      second = const _Donut(fraction: 1, color: _kGood, big: 'Active', small: 'plan', caption: 'Plan', bigSize: 12);
    } else {
      final unlimited = info.maxDevices <= 0;
      second = _Donut(
        fraction: unlimited ? 1 : (info.devices / info.maxDevices).clamp(0.0, 1.0),
        color: unlimited ? _kGood : (info.devices >= info.maxDevices ? _kAmber : _kGood),
        big: unlimited ? '${info.devices}' : '${info.devices}/${info.maxDevices}',
        small: 'devices',
        caption: 'Devices',
      );
    }

    final ends = _date(info.expiresAt);
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Donut(
                fraction: usedFraction,
                color: usageColor,
                big: limited ? _minutes(info.minutesLeftToday) : '∞',
                small: limited ? 'left today' : 'no limit',
                caption: 'Today',
              ),
              second,
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 6),
          _Row('Used today', limited ? '${_minutes(info.usedToday)} of ${_minutes(info.dailyLimit)}' : _minutes(info.usedToday)),
          _Row('Per session', info.sessionLimit > 0 ? _minutes(info.sessionLimit) : 'No limit'),
          _Row('Devices', info.maxDevices > 0 ? '${info.devices} of ${info.maxDevices}' : '${info.devices}'),
          if (!info.isFree && ends != null) _Row(info.cancelling ? 'Ends' : 'Renews', ends),
          if (info.isFree && info.expired) const _Row('Plan', 'Expired'),
          if (info.isFree) ...[
            const SizedBox(height: 8),
            _SmallButton(label: 'Upgrade plan', filled: true, onTap: () => _openSettings(SettingsTabKey.account)),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: _kMuted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kInk)),
            ),
          ],
        ),
      );
}

/// A ring (animated when the value changes) with a figure in the middle and a caption under it.
class _Donut extends StatelessWidget {
  const _Donut({required this.fraction, required this.color, required this.big, required this.small, required this.caption, this.bigSize = 14});
  final double fraction;
  final Color color;
  final String big, small, caption;
  final double bigSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => CustomPaint(
              painter: _DonutPainter(value, color),
              child: child,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(big, style: TextStyle(fontSize: bigSize, fontWeight: FontWeight.w800, color: _kInk, height: 1.1)),
                  Text(small, style: const TextStyle(fontSize: 8.5, color: _kMuted, height: 1.2)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(caption, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _kMuted)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.fraction, this.color);
  final double fraction;
  final Color color;
  static const _stroke = 6.0;

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