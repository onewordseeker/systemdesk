import 'package:flutter/material.dart';
import 'package:flutter_hbb/screens/sd_icons.dart';
import 'package:flutter_hbb/screens/sd_kit.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// The card of the required-update screen in the new design (`.modal` with `.tag`, `.notes` and `.pbar`): what the update is, what it brings (the lines of the
/// administrators' message, one point each), and one wide button that starts it.
class SdUpdateCard extends StatelessWidget {
  const SdUpdateCard({super.key, required this.version, required this.message, required this.onUpdate, this.onQuit});

  /// the version that is needed
  final String version;

  /// what the administrators wrote about it, a point to a line (may be empty)
  final String message;
  final VoidCallback onUpdate;
  final VoidCallback? onQuit;

  /// the lines of [message] without the dash or bullet an administrator may have put in front
  static List<String> notesOf(String message) => [
        for (final line in message.split(RegExp(r'[\r\n]+')))
          if (line.replaceFirst(RegExp(r'^\s*[-*•]\s*'), '').trim().isNotEmpty) line.replaceFirst(RegExp(r'^\s*[-*•]\s*'), '').trim(),
      ];

  @override
  Widget build(BuildContext context) {
    final t = SdSkin.of(context);
    final notes = notesOf(message);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SdBox(
        key: const ValueKey('sd-update-gate'),
        radius: SdLook.dialogRadius,
        gradient: t.raised,
        borderColor: t.line,
        shadows: const [BoxShadow(color: Color(0x99140E08), blurRadius: 80, spreadRadius: -28, offset: Offset(0, 40))],
        inner: [SdInner(0, 1, 0, t.hi)],
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [SdTag('Required update', kind: SdTagKind.gold)]),
            const SizedBox(height: 14),
            Text('SystemDesk $version is ready', style: sdTs(24, FontWeight.w600, t.ink, ls: -0.24)),
            const SizedBox(height: 6),
            Text('This version is needed to keep connecting. It takes about a minute.', style: sdTs(14.5, FontWeight.w400, t.mut)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var i = 0; i < notes.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 22, child: Padding(padding: const EdgeInsets.only(top: 1), child: SdIcon(SdIcons.check, size: 20, color: t.ok, stroke: 2.4))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(notes[i], style: sdTs(14.5, FontWeight.w400, t.ink))),
                ]),
              ],
            ],
            const SizedBox(height: 22),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onUpdate,
                child: SdInset(
                  radius: 15,
                  height: 56,
                  child: Center(child: Text('Update now', style: sdTs(16, FontWeight.w600, t.goldInk))),
                ),
              ),
            ),
            if (onQuit != null) ...[
              const SizedBox(height: 8),
              Center(child: SdLink('Quit', onTap: onQuit)),
            ],
          ],
        ),
      ),
    );
  }
}
