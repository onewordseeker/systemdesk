import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/screens/sd_bell.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_signin_modal.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/account_summary.dart';
import 'package:flutter_hbb/services/license_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// The four pages of the main window.
enum SdPage { dashboard, devices, sessions, settings }

/// Which page of the main window is open. Dashboard, Devices and Sessions are the home tab; Settings is the settings tab, so the page shown in the
/// header also follows whichever tab is selected (other parts of the app open Settings by themselves).
class SdNav {
  SdNav._();

  /// the page of the home tab
  static final home = SdPage.dashboard.obs;

  static SdPage current() {
    try {
      final c = Get.find<DesktopTabController>();
      final tabs = c.state.value.tabs;
      final i = c.state.value.selected;
      if (i >= 0 && i < tabs.length && tabs[i].key == kTabLabelSettingPage) return SdPage.settings;
    } catch (_) {}
    return home.value;
  }

  static void go(SdPage page) {
    if (page == SdPage.settings) {
      DesktopTabPage.onAddSetting();
      return;
    }
    home.value = page;
    try {
      Get.find<DesktopTabController>().jumpToByKey(kTabLabelHomePage);
    } catch (_) {}
  }
}

/// The plan as the design's pill words it.
String sdPlanLabel(AccountInfo? info) {
  if (info == null) return 'Free Plan';
  if (info.isFree) return info.expired ? 'Free Plan · expired' : 'Free Plan';
  final shared = info.isShared ? ' · shared' : '';
  switch (info.tier) {
    case 'personal_paid':
      return 'Personal Plan$shared';
    case 'business_payg':
      return 'Pay as you go$shared';
    case 'business_org':
      return 'Business Plan$shared';
    default:
      return '${info.tier.replaceAll('_', ' ')}$shared';
  }
}

const double kSdTitleBarHeight = 40;
const double kSdHeaderHeight = 72;

/// The mark of the header: an "S" in silver blue with a gold dot.
class SdMark extends StatelessWidget {
  const SdMark({super.key, this.size = 34, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final stroke = onDark
        ? '<stop offset="0" stop-color="#F4F6FB"/><stop offset="1" stop-color="#C8D0E2"/>'
        : '<stop offset="0" stop-color="#8E99B2"/><stop offset="1" stop-color="#26324E"/>';
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 34" fill="none"><defs><linearGradient id="g" x1="6" y1="4" x2="28" y2="30" gradientUnits="userSpaceOnUse">$stroke</linearGradient></defs>'
        '<path d="M25 9.5c-1.7-2.6-4.6-4-8.2-4-4.6 0-7.8 2.4-7.8 6 0 9 16 4.2 16 12.2 0 3.7-3.4 6-8.2 6-3.8 0-7-1.5-8.8-4.3" stroke="url(#g)" stroke-width="4.4" stroke-linecap="round"/>'
        '<circle cx="26" cy="9" r="2.1" fill="#E2AC50"/></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// A 12 x 12 line glyph of the window buttons.
class _Glyph extends StatelessWidget {
  const _Glyph(this.body, this.color);
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" fill="none" stroke="#000" stroke-width="1.3">$body</svg>',
        width: 12,
        height: 12,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

class SdGlyphs {
  SdGlyphs._();
  static const String minimise = '<path d="M1.5 6h9"/>';
  static const String maximise = '<rect x="1.8" y="1.8" width="8.4" height="8.4" rx="1"/>';
  static const String restore = '<rect x="3.4" y="1.4" width="7.2" height="7.2" rx="1"/><path d="M1.4 3.6v6a1 1 0 0 0 1 1h6"/>';
  static const String close = '<path d="M1.8 1.8l8.4 8.4M10.2 1.8l-8.4 8.4"/>';
}

/// The colour the window buttons below it draw their symbols in, where it is not the usual one (the dark bar of a remote session).
class SdWinInk extends InheritedWidget {
  const SdWinInk({super.key, required this.color, required super.child});
  final Color color;

  static Color? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SdWinInk>()?.color;

  @override
  bool updateShouldNotify(SdWinInk old) => old.color != color;
}

/// `.wc`: a button of the window (minimise, maximise, close): 46 x 40, a soft square under the pointer, the close one turns red.
class SdWinButton extends StatefulWidget {
  const SdWinButton({super.key, this.glyph, this.icon, this.onTap, this.isClose = false, this.tooltip, this.width = 46, this.height = kSdTitleBarHeight});
  final String? glyph;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isClose;
  final String? tooltip;
  final double width, height;

  @override
  State<SdWinButton> createState() => _SdWinButtonState();
}

class _SdWinButtonState extends State<SdWinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final enabled = widget.onTap != null;
    final red = widget.isClose && _hover;
    final ink = SdWinInk.of(context) ?? t.mut;
    final color = !enabled ? ink.withOpacity(0.5) : (red ? Colors.white : ink);
    Widget w = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          color: red ? const Color(0xFFC42B1C) : (_hover && enabled ? (t.dark ? const Color(0x14FFFFFF) : const Color(0x1428241C)) : Colors.transparent),
          child: widget.glyph != null ? _Glyph(widget.glyph!, color) : Icon(widget.icon, size: 14, color: color),
        ),
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) w = Tooltip(message: widget.tooltip!, waitDuration: const Duration(seconds: 1), child: w);
    return w;
  }
}

/// `.tb`: what the title bar of the main window shows at the left: the window icon and the name.
class SdTitleBrand extends StatelessWidget {
  const SdTitleBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SdIcon(SdIcons.tiles, size: 14, color: t.mut, stroke: 2),
        const SizedBox(width: 10),
        Text('SystemDesk', style: sdTs(12.5, FontWeight.w400, t.mut)),
      ]),
    );
  }
}

/// The fill and the hairline under the title bar.
class SdTitleBarBox extends StatelessWidget {
  const SdTitleBarBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Container(
      height: kSdTitleBarHeight,
      decoration: BoxDecoration(
        color: t.dark ? const Color(0x06FFFFFF) : const Color(0x66FFFFFF),
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: child,
    );
  }
}

/// `.nav a`: one page link of the header.
class _NavLink extends StatefulWidget {
  const _NavLink({required this.label, required this.current, required this.onTap});
  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final cur = widget.current;
    final base = t.dark ? const Color(0xFFFFFFFF) : const Color(0xFF28241C);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: cur,
          label: widget.label,
          child: SdBox(
            radius: 12,
            color: cur ? base.withOpacity(t.dark ? 0.07 : 0.075) : (_hover ? base.withOpacity(0.05) : Colors.transparent),
            inner: cur ? [SdInner(0, 1, 3, t.dark ? const Color(0x80000000) : const Color(0x2928241C))] : const [],
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(widget.label, style: sdTs(17, FontWeight.w400, t.ink)),
          ),
        ),
      ),
    );
  }
}

/// `.hd`: the header under the title bar: brand, the four pages, the plan, the bell and the person.
class SdHeaderView extends StatelessWidget {
  const SdHeaderView({
    super.key,
    required this.page,
    required this.onPage,
    required this.plan,
    this.planTip,
    this.onPlan,
    required this.initials,
    this.onAvatar,
    this.bell,
    this.labels = const {SdPage.dashboard: 'Dashboard', SdPage.devices: 'Devices', SdPage.sessions: 'Sessions', SdPage.settings: 'Settings'},
    this.link,
  });
  final SdPage page;
  final ValueChanged<SdPage> onPage;
  final String plan;
  final String? planTip;
  final VoidCallback? onPlan;
  final String initials;
  final VoidCallback? onAvatar;

  /// the bell (a button; the header gives it its place)
  final Widget? bell;
  final Map<SdPage, String> labels;

  /// the bell's list opens under bell and avatar: this link marks them
  final LayerLink? link;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    Widget tools = Row(mainAxisSize: MainAxisSize.min, children: [
      if (bell != null) ...[bell!, const SizedBox(width: 12)],
      SdAvatar(initials: initials, onTap: onAvatar),
    ]);
    if (link != null) tools = CompositedTransformTarget(link: link!, child: tools);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      return Container(
        height: kSdHeaderHeight,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(children: [
          const SdMark(),
          const SizedBox(width: 12),
          Text('SystemDesk', style: sdTs(20, FontWeight.w500, t.ink, ls: -0.2)),
          SizedBox(width: wide ? 34 : 16),
          for (final p in SdPage.values) ...[
            if (p != SdPage.dashboard) const SizedBox(width: 6),
            _NavLink(label: labels[p] ?? p.name, current: p == page, onTap: () => onPage(p)),
          ],
          if (wide) ...[
            const SizedBox(width: 34),
            Tooltip(message: planTip ?? plan, waitDuration: const Duration(milliseconds: 700), child: SdGoldPill(label: plan, onTap: onPlan)),
          ],
          const Spacer(),
          tools,
        ]),
      );
    });
  }
}

/// The header of the real window: reads the page, the plan and the person from the app.
class SdHeader extends StatefulWidget {
  const SdHeader({super.key});

  @override
  State<SdHeader> createState() => _SdHeaderState();
}

class _SdHeaderState extends State<SdHeader> {
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // the tab controller is read here so the header follows the selected tab
      try {
        Get.find<DesktopTabController>().state.value;
      } catch (_) {}
      final info = AccountSummary.instance.info.value;
      final signedIn = LicenseService.instance.isLoggedInRx.value;
      return SdHeaderView(
        page: SdNav.home.value == SdPage.settings ? SdPage.dashboard : _page(),
        onPage: SdNav.go,
        plan: sdPlanLabel(info),
        planTip: planTitle(info),
        onPlan: () => SdNav.go(SdPage.settings),
        initials: signedIn && info != null ? info.initials : '',
        onAvatar: signedIn ? () => SdNav.go(SdPage.settings) : showSdSignIn,
        link: _link,
        labels: {
          SdPage.dashboard: translate('Dashboard'),
          SdPage.devices: translate('Devices'),
          SdPage.sessions: translate('Sessions'),
          SdPage.settings: translate('Settings'),
        },
        bell: SdBell(
          link: _link,
          text: SdBellText(
            title: translate('Notifications'),
            clear: translate('Clear all'),
            empty: translate('You are all caught up'),
            emptyHint: translate('Announcements from SystemDesk appear here.'),
          ),
        ),
      );
    });
  }

  SdPage _page() => SdNav.current();
}
