import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart' show TabbarTheme;
import 'package:flutter_hbb/screens/sd_tone.dart';
import 'package:flutter_hbb/services/server_profile.dart';

/// `--dart-define=SD_NEW_LOOK=1` (on) or `=0` (off) decides by hand; without it the new look follows [kIsTestMode].
const String _kNewLookDefine = String.fromEnvironment('SD_NEW_LOOK');

/// The new app design (soft raised panels, champagne gold, navy Quick Connect), behind one switch. With the switch off every theme, shape and colour of
/// the app is exactly the one it had before: [light] and [dark] hand out [MyTheme.lightTheme] and [MyTheme.darkTheme] themselves, and each place that
/// reads a new-look value keeps its old value on the other side of `SdLook.enabled`. New-look code is added here and in new files.
class SdLook {
  SdLook._();

  /// A test can make the choice.
  @visibleForTesting
  static bool? debugEnabled;

  /// On in a test build or an app a developer started, off in a production build, until the new look is approved for release.
  static bool get enabled {
    final forced = debugEnabled;
    if (forced != null) return forced;
    if (_kNewLookDefine == '1') return true;
    if (_kNewLookDefine == '0') return false;
    try {
      return kIsTestMode;
    } catch (_) {
      return false; // no core yet (a widget test): the old look stands
    }
  }

  /// Inter (SIL Open Font License, files in assets/fonts). Roboto stays behind it for any character it does not have.
  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Roboto'];

  static const double dialogRadius = 26;
  static const double controlRadius = 12;
  static const double fieldRadius = 12;
  static const double menuRadius = 14;

  static ThemeData get light => enabled ? _light : MyTheme.lightTheme;
  static ThemeData get dark => enabled ? _dark : MyTheme.darkTheme;

  static final ThemeData _light = _restyle(MyTheme.lightTheme);
  static final ThemeData _dark = _restyle(MyTheme.darkTheme);

  /// The theme of the app in the new look. Every screen that takes its colours from the theme follows by itself. Only API the app's own theme already
  /// uses is used, so every Flutter version the app is built with takes it.
  static ThemeData _restyle(ThemeData t) {
    final isDark = t.brightness == Brightness.dark;
    final desktop = isDesktop || isWebDesktop;
    final tone = isDark ? SdSkin.darkTone : SdSkin.light;

    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );
    final text = t.textTheme.apply(fontFamily: fontFamily, fontFamilyFallback: fontFallback);
    // a button's own text style replaces the theme's (it is not merged), so it is built from the new text theme to keep the font
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w500);

    final colorExt = t.extension<ColorThemeExtension>();
    final tabExt = t.extension<TabbarTheme>();
    return t.copyWith(
      scaffoldBackgroundColor: tone.bg,
      dialogBackgroundColor: tone.pa,
      cardColor: tone.pa,
      dividerColor: tone.line,
      hoverColor: tone.chip,
      // ignore: deprecated_member_use (the app's own theme sets background too)
      colorScheme: t.colorScheme.copyWith(primary: tone.goldB, secondary: tone.goldB, background: tone.bg),
      // ignore: deprecated_member_use (WidgetState does not exist in the older Flutter versions the app is also built with)
      menuBarTheme: MenuBarThemeData(style: MenuStyle(backgroundColor: MaterialStatePropertyAll(tone.pa))),
      // copyWith on the theme's own value: the class of this setting is TabBarTheme in Flutter 3.24 and TabBarThemeData in 3.44 (Windows ARM64), and copyWith takes either
      tabBarTheme: t.tabBarTheme.copyWith(labelColor: tone.ink, unselectedLabelColor: tone.mut, indicatorColor: tone.goldB),
      // the switches that are still Material ones (the Network list, dialogs): gold track when on, a faint one when off, a white knob
      switchTheme: SwitchThemeData(
        splashRadius: t.switchTheme.splashRadius,
        // ignore: deprecated_member_use
        thumbColor: MaterialStatePropertyAll(Colors.white),
        // ignore: deprecated_member_use
        trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? tone.goldB : (isDark ? const Color(0x33FFFFFF) : const Color(0x29161410))),
        // ignore: deprecated_member_use
        trackOutlineColor: const MaterialStatePropertyAll(Colors.transparent),
      ),
      extensions: <ThemeExtension<dynamic>>[
        if (colorExt != null) colorExt.copyWith(border: tone.line, highlight: tone.chip, divider: tone.line),
        if (tabExt != null)
          // the tabs of the other windows: the open one is a gold chip
          tabExt.copyWith(
              selectedTabIconColor: tone.goldInk,
              unSelectedTabIconColor: tone.mut,
              selectedTextColor: tone.goldInk,
              unSelectedTextColor: tone.mut,
              selectedIconColor: tone.goldInk,
              unSelectedIconColor: tone.mut,
              dividerColor: tone.line,
              hoverColor: tone.chip,
              closeHoverColor: tone.ink.withOpacity(0.12),
              selectedTabBackgroundColor: tone.goldB),
      ],
      textTheme: text,
      primaryTextTheme: t.primaryTextTheme.apply(fontFamily: fontFamily, fontFamilyFallback: fontFallback),
      // as above: DialogTheme in Flutter 3.24, DialogThemeData in 3.44
      dialogTheme: t.dialogTheme.copyWith(
        elevation: 15,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
          side: BorderSide(width: 1, color: tone.line),
        ),
      ),
      inputDecorationTheme: desktop
          ? InputDecorationTheme(
              fillColor: tone.ib,
              filled: true,
              isDense: true,
              border: field(tone.line, 1),
              enabledBorder: field(tone.line, 1),
              focusedBorder: field(tone.goldRing, 1.5),
            )
          : t.inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tone.goldB,
          foregroundColor: tone.goldInk,
          disabledForegroundColor: isDark ? Colors.white70 : null,
          disabledBackgroundColor: isDark ? Colors.white10 : null,
          elevation: 0,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      textButtonTheme: desktop
          ? TextButtonThemeData(
              style: TextButton.styleFrom(
                splashFactory: NoSplash.splashFactory,
                disabledForegroundColor: isDark ? Colors.white70 : null,
                foregroundColor: tone.goldTxt,
                textStyle: buttonText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
              ),
            )
          : t.textButtonTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: tone.pa,
          foregroundColor: tone.ink,
          disabledForegroundColor: isDark ? Colors.white70 : null,
          side: BorderSide(color: tone.line),
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tone.pa,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tone.line),
          borderRadius: const BorderRadius.all(Radius.circular(menuRadius)),
        ),
      ),
    );
  }
}
