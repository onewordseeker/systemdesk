import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

/// The colours of SystemDesk's own dialogs and overlays (the plan-limit dialog, messages from the administrators, the required-update screen).
/// A dialog that paints its OWN surface and takes its text colours from here can never end up with dark text on a dark surface: the surface and the text
/// always come from the same palette, whatever theme the window around them is in. Which palette: the theme the person chose in the settings
/// (light, dark or "follow the system"), the window's own theme only when the setting cannot be read.
class SdPalette {
  const SdPalette._({
    required this.dark,
    required this.fill,
    required this.border,
    required this.ink,
    required this.muted,
    required this.card,
    required this.line,
    required this.hit,
    required this.onAmber,
  });

  final bool dark;

  /// the surface of the dialog
  final Color fill;
  final Color border;

  /// headings and values
  final Color ink;

  /// body text
  final Color muted;

  /// a card inside the dialog, and the lines inside it
  final Color card;
  final Color line;

  /// text on the amber accent / the "limit reached" tone
  final Color hit;
  final Color onAmber;

  static const Color amber = Color(0xFFF59E0B);

  static const SdPalette light = SdPalette._(
    dark: false,
    fill: Color(0xFFFFFFFF),
    border: Color(0xFFECE7DB),
    ink: Color(0xFF1A1712),
    muted: Color(0xFF5E584B),
    card: Color(0xFFF7F4ED),
    line: Color(0xFFECE7DB),
    hit: Color(0xFF8A5A00),
    onAmber: Color(0xFF241700),
  );

  static const SdPalette darkPalette = SdPalette._(
    dark: true,
    fill: Color(0xFF18191E),
    border: Color(0xFF30323A),
    ink: Color(0xFFECEAE4),
    muted: Color(0xFFB4B7C0),
    card: Color(0xFF24252B),
    line: Color(0xFF30323A),
    hit: Color(0xFFF0C26B),
    onAmber: Color(0xFF241700),
  );

  /// A test can make the choice.
  @visibleForTesting
  static bool? debugDark;

  static SdPalette of(BuildContext context) {
    final forced = debugDark;
    if (forced != null) return forced ? darkPalette : light;
    var dark = Theme.of(context).brightness == Brightness.dark;
    try {
      dark = MyTheme.currentThemeMode() == ThemeMode.dark;
    } catch (_) {
      // the setting cannot be read here (no core yet): the window's own theme stands
    }
    return dark ? darkPalette : light;
  }

  /// The rounded outline of a dialog in this palette.
  ShapeBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      );
}
