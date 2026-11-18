import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/screens/sd_look.dart';
import 'package:flutter_hbb/screens/sd_palette.dart';
import 'package:flutter_hbb/screens/sd_tone.dart';

/// A SystemDesk dialog drawn with plain widgets: a card with its own opaque fill, border and shadow (no Material surface, no clipping layer) over a
/// backdrop that paints its own colour. The framework's AlertDialog could be left without its fill over the remote screen of a session on a Mac
/// (text on the black picture of the ended session, a stray white block), so the dialogs that must always be readable do not depend on it.
///
/// [opaqueBackdrop]: the whole window behind the card is painted (the ended session's black screen is not shown any more); otherwise a dimming layer.
/// Enter calls [onSubmit], Escape [onCancel]. Clicks outside the card do nothing.
class SdModal extends StatelessWidget {
  const SdModal({
    Key? key,
    required this.content,
    this.actions = const [],
    this.maxWidth = 480,
    this.opaqueBackdrop = false,
    this.onSubmit,
    this.onCancel,
  }) : super(key: key);

  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final bool opaqueBackdrop;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;

  /// The new design's dialog (`.scrim`, `.modal`): the window behind it blurred and dimmed, a raised card with a 26 px corner and 30 px of room.
  Widget _buildSd(BuildContext context, SdPalette p) {
    final t = SdSkin.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (opaqueBackdrop)
          ColoredBox(key: const ValueKey('sd-modal-backdrop'), color: p.scrim)
        else
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: ColoredBox(key: const ValueKey('sd-modal-backdrop'), color: t.scrim),
          ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SdBox(
                key: const ValueKey('sd-modal-card'),
                radius: SdLook.dialogRadius,
                gradient: t.raised,
                borderColor: t.line,
                shadows: const [BoxShadow(color: Color(0x99140E08), blurRadius: 80, spreadRadius: -28, offset: Offset(0, 40))],
                inner: [SdInner(0, 1, 0, t.hi)],
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: actions),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SdPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && onCancel != null) {
            onCancel!();
            return KeyEventResult.handled;
          }
          if ((event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
              onSubmit != null) {
            onSubmit!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: SdLook.enabled ? _buildSd(context, p) : Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              key: const ValueKey('sd-modal-backdrop'),
              color: opaqueBackdrop ? p.scrim : Colors.black.withOpacity(p.dark ? 0.62 : 0.45),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: DecoratedBox(
                    key: const ValueKey('sd-modal-card'),
                    decoration: BoxDecoration(
                      color: p.fill,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 12)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          content,
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 10,
                              runSpacing: 8,
                              children: actions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
