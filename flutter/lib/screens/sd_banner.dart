import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// good = news that helps (an update), warn = something to do (install, finish the set-up)
enum SdBannerTone { good, warn }

class SdBannerAction {
  const SdBannerAction(this.label, this.onTap, {this.primary = false, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  /// shows a spinner instead of the label (and ignores taps)
  final bool busy;
}

/// A strip above the page (update ready, running without installing, finish the Mac set-up): a raised panel with an icon tile, a title and a line of text,
/// its actions as buttons, and a close button when it can be put off.
class SdBanner extends StatelessWidget {
  const SdBanner({
    super.key,
    required this.tone,
    this.svg,
    this.iconData,
    required this.title,
    required this.body,
    this.bodyIsError = false,
    this.actions = const [],
    this.onClose,
    this.margin = const EdgeInsets.fromLTRB(28, 16, 28, 0),
  });
  final SdBannerTone tone;
  final String? svg;
  final IconData? iconData;
  final String title, body;
  final bool bodyIsError;
  final List<SdBannerAction> actions;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final good = tone == SdBannerTone.good;
    final tileBg = good ? const Color(0x2417804F) : t.goldSoft;
    final tileFg = good ? t.ok : t.goldTxt;
    return Padding(
      padding: margin,
      child: SdPanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(14)),
            child: svg != null ? SdIcon(svg!, size: 18, color: tileFg, stroke: 2) : Icon(iconData, size: 20, color: tileFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: sdTs(14.5, FontWeight.w500, t.ink)),
              const SizedBox(height: 1),
              Text(body, style: sdTs(13, FontWeight.w400, bodyIsError ? t.bad : t.mut, lh: 1.35)),
            ]),
          ),
          for (final a in actions) ...[
            const SizedBox(width: 8),
            a.primary
                ? SdButton(small: true, kind: SdBtnKind.gold, label: a.label, onTap: a.onTap, busy: a.busy)
                : SdButton(small: true, label: a.label, onTap: a.onTap, busy: a.busy),
          ],
          if (onClose != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Later',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClose,
                  child: SizedBox(width: 32, height: 32, child: Center(child: SdIcon(SdIcons.close, size: 15, color: t.mut))),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
