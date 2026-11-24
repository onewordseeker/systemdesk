import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The Settings screen of the design: a navigation panel at the left (248 px), at the right a title with its line of explanation and the cards of the open
/// section in two columns. These are the pieces; `desktop_setting_page.dart` puts the app's own sections in them.

/// One entry of the navigation.
class SdSettingsTab {
  const SdSettingsTab(this.id, this.label, [this.group, this.icon, this.keywords = '']);
  final Object id;
  final String label;

  /// the heading the entry is listed under (Account, Security, Experience, System); entries of one group follow each other
  final String? group;

  /// the drawing of its icon ([SdIcons])
  final String? icon;

  /// what the search looks in besides the name: the words of the options on the page
  final String keywords;
}

/// `.snav`: the navigation panel, at the full height of the page, flush with the window's edge: a search field, the pages listed under their group headings,
/// and [footer] fixed at the bottom (it does not scroll with the pages). The open page is the amber row with a bar at its left.
class SdSettingsNav extends StatefulWidget {
  const SdSettingsNav({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.footer,
    this.searchHint = 'Search settings',
    this.noMatch = 'Nothing matches',
  });
  final List<SdSettingsTab> tabs;
  final Object selected;
  final ValueChanged<Object> onSelect;
  final Widget? footer;
  final String searchHint, noMatch;

  @override
  State<SdSettingsNav> createState() => _SdSettingsNavState();
}

class _SdSettingsNavState extends State<SdSettingsNav> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(SdSettingsTab tab, String q) =>
      tab.label.toLowerCase().contains(q) || tab.keywords.toLowerCase().contains(q) || (tab.group ?? '').toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final q = _query.text.trim().toLowerCase();
    final tabs = q.isEmpty ? widget.tabs : widget.tabs.where((x) => _matches(x, q)).toList();
    String? group;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.chrome, border: Border(right: BorderSide(color: t.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SdBox(
            radius: 10,
            color: t.pa,
            borderColor: t.line2,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              SdIcon(SdIcons.search, size: 17, color: t.mut, stroke: 1.9),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('sd-settings-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: sdTs(14, FontWeight.w400, t.ink),
                  cursorColor: t.goldA,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.searchHint,
                    hintStyle: sdTs(14, FontWeight.w400, t.mut),
                  ),
                ),
              ),
              if (q.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('sd-settings-search-clear'),
                  onTap: () => setState(_query.clear),
                  child: SdIcon(SdIcons.close, size: 16, color: t.mut, stroke: 1.9),
                ),
            ]),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (tabs.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 0), child: Text(widget.noMatch, style: sdTs(13.5, FontWeight.w400, t.mut))),
              for (var i = 0; i < tabs.length; i++) ...[
                if (tabs[i].group != null && tabs[i].group != group) ...[
                  Padding(padding: EdgeInsets.fromLTRB(12, i == 0 ? 8 : 18, 12, 6), child: Text((group = tabs[i].group)!.toUpperCase(), style: sdTs(11, FontWeight.w600, t.mut, ls: 0.8, lh: 1.0))),
                ],
                _NavItem(key: ValueKey('sd-nav-${tabs[i].id}'), label: tabs[i].label, icon: tabs[i].icon, selected: tabs[i].id == widget.selected, onTap: () => widget.onSelect(tabs[i].id), skin: t),
                const SizedBox(height: 2),
              ],
            ]),
          ),
        ),
        if (widget.footer != null) DecoratedBox(decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))), child: widget.footer!),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({super.key, required this.label, required this.selected, required this.onTap, required this.skin, this.icon});
  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;
  final SdSkin skin;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.skin;
    final on = widget.selected;
    final fg = on ? t.goldTxt : t.ink;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          selected: on,
          label: widget.label,
          child: SdBox(
            radius: 10,
            color: on ? t.goldSoft : (_hover ? t.chip : Colors.transparent),
            borderColor: on ? t.goldA.withOpacity(0.55) : Colors.transparent,
            height: 42,
            child: Stack(children: [
              // the bar at the left edge of the open page
              if (on) Positioned(left: 0, top: 0, bottom: 0, child: Container(key: const ValueKey('sd-nav-bar'), width: 3.5, decoration: BoxDecoration(color: t.goldA, borderRadius: const BorderRadius.horizontal(left: Radius.circular(10))))),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    if (widget.icon != null) ...[SdIcon(widget.icon!, size: 19, color: on ? t.goldTxt : t.mut, stroke: 1.7), const SizedBox(width: 12)],
                    Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(14.5, on ? FontWeight.w600 : FontWeight.w400, fg))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The line fixed at the bottom of the menu: "About SystemDesk" and, as a small pill, the version of this copy with what the last look for updates found
/// ("Up to date", or "Update available" in amber). Without a [note] the pill is the version alone, grey. It opens the About page.
class SdAboutLine extends StatelessWidget {
  const SdAboutLine({
    super.key,
    required this.label,
    required this.version,
    this.note,
    this.noteKind = SdTagKind.ok,
    this.selected = false,
    this.onTap,
  });
  final String label, version;
  final String? note;
  final SdTagKind noteKind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final on = selected;
    final color = note == null ? t.mut : (noteKind == SdTagKind.gold ? t.goldTxt : t.ok);
    final pill = [version, if (note != null) note!].where((s) => s.isNotEmpty).join(' • ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('sd-settings-about'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: on ? t.goldSoft : Colors.transparent,
            child: Row(children: [
              SdIcon(SdIcons.info, size: 16, color: on ? t.goldTxt : t.mut, stroke: 1.8),
              const SizedBox(width: 6),
              // the name keeps its whole width; the version gives way if the room is short
              Text(label, maxLines: 1, softWrap: false, style: sdTs(12.5, on ? FontWeight.w600 : FontWeight.w400, on ? t.goldTxt : t.mut)),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: pill.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: const ValueKey('sd-settings-version'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            border: Border.all(color: color.withOpacity(0.35)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(pill, maxLines: 1, overflow: TextOverflow.ellipsis, style: sdTs(10.5, FontWeight.w500, color)),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The whole screen: navigation, title, and [child] (the open section: its cards).
class SdSettingsFrame extends StatelessWidget {
  const SdSettingsFrame({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.title,
    required this.subtitle,
    required this.child,
    this.navFooter,
    this.footerTab,
    this.searchHint = 'Search settings',
    this.noMatch = 'Nothing matches',
  });
  final List<SdSettingsTab> tabs;
  final Object selected;
  final ValueChanged<Object> onSelect;
  final String title, subtitle;
  final Widget child;

  /// fixed at the bottom of the navigation (About and the version); [footerTab] is the page it opens, shown as a last chip when the window is narrow
  final Widget? navFooter;
  final SdSettingsTab? footerTab;
  final String searchHint, noMatch;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 980;
      final head = Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: sdTs(24, FontWeight.w600, t.ink, ls: -0.2)),
          Text(subtitle, style: sdTs(14, FontWeight.w400, t.mut)),
        ]),
      );
      final nav = SdSettingsNav(tabs: tabs, selected: selected, onSelect: onSelect, footer: navFooter, searchHint: searchHint, noMatch: noMatch);
      if (stacked) {
        final chips = [...tabs, if (footerTab != null) footerTab!];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final tab in chips) Padding(padding: const EdgeInsets.only(right: 8), child: _Chip(tab: tab, selected: tab.id == selected, onTap: () => onSelect(tab.id)))])),
            const SizedBox(height: 16),
            head,
            Expanded(child: child),
          ]),
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 300, child: nav),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, Expanded(child: child)]),
          ),
        ),
      ]);
    });
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.tab, required this.selected, required this.onTap});
  final SdSettingsTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SdBox(
        radius: 12,
        color: selected ? t.chip : Colors.transparent,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        child: Text(tab.label, style: sdTs(15, selected ? FontWeight.w500 : FontWeight.w400, t.ink)),
      ),
    );
  }
}

/// What a settings page lists, sorted: an `Offstage` that carries [lockKey] and is on is an unlock button (it goes above the cards, over the whole width);
/// any other `Offstage` is a card that is wrapped so it can be left out: shown, it is the card itself, otherwise it is not there.
({List<Widget> locks, List<Widget> cards}) sdSplitSettings(List<Widget> children, Key lockKey) {
  final locks = <Widget>[];
  final cards = <Widget>[];
  for (final c in children) {
    if (c is Offstage) {
      if (c.key == lockKey) {
        if (!c.offstage) locks.add(c);
      } else if (!c.offstage && c.child != null) {
        cards.add(c.child!);
      }
    } else {
      cards.add(c);
    }
  }
  return (locks: locks, cards: cards);
}

/// `.cards`: the cards of a section in two columns (one when narrow), each row of the grid starting at the top. [single] puts them one under the other,
/// in the order they are given, at a width that reads well.
class SdSettingsGrid extends StatelessWidget {
  const SdSettingsGrid({super.key, required this.children, this.single = false});
  final List<Widget> children;
  final bool single;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (single || c.maxWidth < 700) {
        final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 20), children[i]],
        ]);
        return single ? Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: column)) : column;
      }
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        final a = children[i];
        final b = i + 1 < children.length ? children[i + 1] : const SizedBox.shrink();
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 20), Expanded(child: b)]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 20), rows[i]],
      ]);
    });
  }
}

/// A settings page: the unlock button of a locked page (if any), then the cards. The button is as wide as the cards under it and starts where they start:
/// a page of one column keeps its cards at 760, a page with a single card has it in one column of two, and with several cards it goes over both columns.
class SdSettingsPage extends StatelessWidget {
  const SdSettingsPage({super.key, this.controller, this.locks = const [], required this.cards, this.single = false});
  final ScrollController? controller;
  final List<Widget> locks, cards;
  final bool single;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 28),
      child: LayoutBuilder(builder: (context, c) {
        final double? width = single ? 760 : (cards.length <= 1 && c.maxWidth >= 700 ? (c.maxWidth - 20) / 2 : null);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final l in locks)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: width == null ? l : Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: l)),
            ),
          SdSettingsGrid(children: cards, single: single),
        ]);
      }),
    );
  }
}

/// `.card`: one card of the grid: its title (18 / 500) and its rows, a hairline between the rows.
class SdSettingsCard extends StatelessWidget {
  const SdSettingsCard({super.key, required this.title, required this.rows, this.titleSuffix});
  final String title;
  final List<Widget> rows;
  final List<Widget>? titleSuffix;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final shown = rows.where((r) => r is! SizedBox || (r.width != 0 || r.height != 0)).toList();
    return SdPanel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: Text(title, style: sdTs(16.5, FontWeight.w600, t.ink))),
            ...?titleSuffix,
          ]),
        ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) Container(height: 1, color: t.line),
          shown[i],
        ],
      ]),
    );
  }
}

/// `.orow`: a line of a card: the words at the left (15 / 500, and a smaller grey line under them), the control at the right.
class SdSettingRow extends StatelessWidget {
  const SdSettingRow({super.key, required this.label, this.sub, this.trailing, this.onTap, this.labelColor, this.stacked = false});
  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  /// the control goes under the words instead of beside them: for a wide control (a row of choices) in a card that is not wide
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: sdTs(15, FontWeight.w500, labelColor ?? t.ink)),
      if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(sub!, style: sdTs(12.5, FontWeight.w400, t.mut))),
    ]);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: stacked && trailing != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              words,
              const SizedBox(height: 12),
              // a control wider than the card is scrolled sideways rather than cut
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: trailing!),
            ])
          : Row(children: [
              Expanded(child: words),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ]),
    );
    if (onTap == null) return row;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row));
  }
}

/// A toggle row: the words and the ON | OFF control.
class SdToggleRow extends StatelessWidget {
  const SdToggleRow({super.key, required this.label, required this.value, this.onChanged, this.sub, this.labelColor, this.labelSuffix});
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? labelColor;
  final Widget? labelSuffix;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdSettingRow(
      label: label,
      sub: sub,
      labelColor: onChanged == null ? t.mut : labelColor,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (labelSuffix != null) ...[labelSuffix!, const SizedBox(width: 10)], SdOnOff(value: value, onChanged: onChanged)]),
    );
  }
}

/// A kind of "label  value" row (the About card): the label in grey, the value bold.
class SdValueRow extends StatelessWidget {
  const SdValueRow({super.key, required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: sdTs(15, FontWeight.w500, t.ink))),
        const SizedBox(width: 16),
        Flexible(child: SelectableText(value, textAlign: TextAlign.right, style: sdTs(14.5, FontWeight.w400, t.mut))),
      ]),
    );
  }
}

/// A button row of a card (Change ID, Set permanent password): the button, small, at the left.
class SdActionRow extends StatelessWidget {
  const SdActionRow({super.key, required this.label, required this.onTap, this.tip});
  final String label;
  final VoidCallback? onTap;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [SdButton(small: true, label: label, onTap: onTap, tooltip: tip)]),
    );
  }
}
