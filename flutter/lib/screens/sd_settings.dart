import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The Settings screen of the design: a navigation panel at the left (248 px), at the right a title with its line of explanation and the cards of the open
/// section in two columns. These are the pieces; `desktop_setting_page.dart` puts the app's own sections in them.

/// One entry of the navigation.
class SdSettingsTab {
  const SdSettingsTab(this.id, this.label);
  final Object id;
  final String label;
}

/// `.snav`: the navigation panel. The open section has the pressed look of the header's pages.
class SdSettingsNav extends StatelessWidget {
  const SdSettingsNav({super.key, required this.tabs, required this.selected, required this.onSelect});
  final List<SdSettingsTab> tabs;
  final Object selected;
  final ValueChanged<Object> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return SdPanel(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _NavItem(label: tabs[i].label, selected: tabs[i].id == selected, onTap: () => onSelect(tabs[i].id), skin: t),
        ],
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.label, required this.selected, required this.onTap, required this.skin});
  final String label;
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
          selected: on,
          label: widget.label,
          child: SdBox(
            radius: 12,
            color: on ? base.withOpacity(t.dark ? 0.07 : 0.075) : (_hover ? t.chip : Colors.transparent),
            inner: on ? [SdInner(0, 1, 3, t.dark ? const Color(0x80000000) : const Color(0x2928241C))] : const [],
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Text(widget.label, style: sdTs(16, on ? FontWeight.w500 : FontWeight.w400, t.ink)),
          ),
        ),
      ),
    );
  }
}

/// The whole screen: navigation, title, and [child] (the open section: its cards).
class SdSettingsFrame extends StatelessWidget {
  const SdSettingsFrame({super.key, required this.tabs, required this.selected, required this.onSelect, required this.title, required this.subtitle, required this.child});
  final List<SdSettingsTab> tabs;
  final Object selected;
  final ValueChanged<Object> onSelect;
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    return LayoutBuilder(builder: (context, c) {
      final stacked = c.maxWidth < 980;
      final head = Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: sdTs(26, FontWeight.w500, t.ink, ls: -0.26)),
          Text(subtitle, style: sdTs(14, FontWeight.w400, t.mut)),
        ]),
      );
      final nav = SdSettingsNav(tabs: tabs, selected: selected, onSelect: onSelect);
      if (stacked) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final tab in tabs) Padding(padding: const EdgeInsets.only(right: 8), child: _Chip(tab: tab, selected: tab.id == selected, onTap: () => onSelect(tab.id)))])),
            const SizedBox(height: 16),
            head,
            Expanded(child: child),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 248, child: nav),
          const SizedBox(width: 28),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, Expanded(child: child)])),
        ]),
      );
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

/// `.cards`: the cards of a section in two columns (one when narrow), each row of the grid starting at the top.
class SdSettingsGrid extends StatelessWidget {
  const SdSettingsGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 700) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 20), children[i]],
        ]);
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
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(child: Text(title, style: sdTs(18, FontWeight.w500, t.ink, ls: -0.18))),
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
  const SdSettingRow({super.key, required this.label, this.sub, this.trailing, this.onTap, this.labelColor});
  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: sdTs(15, FontWeight.w500, labelColor ?? t.ink)),
            if (sub != null && sub!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 1), child: Text(sub!, style: sdTs(12.5, FontWeight.w400, t.mut))),
          ]),
        ),
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
