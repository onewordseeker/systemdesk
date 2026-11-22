import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The menu of a native title bar (Restore, Move, Size, Minimize, Maximize, Close): the windows of the app draw their own title bar, so the runner shows the
/// window's system menu when the bar asks for it (`windows/runner`, channel `systemdesk/window_menu`; every window has its own engine and so its own
/// handler). The runner enables and disables the entries by the state of the window (a maximized window cannot be maximized again), and runs what is chosen.
/// Windows only: other systems have no such menu.
class SdWindowMenu {
  SdWindowMenu._();

  static const _channel = MethodChannel('systemdesk/window_menu');

  /// where a request goes: the runner's channel, unless a test brings its own. It gets the point in pixels of the window, or null for the cursor.
  @visibleForTesting
  static Future<void> Function(int? x, int? y)? debugOpen;

  /// Where the menu of a native title bar opens when it comes from the keyboard: under the icon, at the left end of the bar.
  static const Offset keyboardAnchor = Offset(8, 34);

  static bool get available => debugOpen != null || (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

  static Future<void> _send(int? x, int? y) async {
    final open = debugOpen;
    if (open != null) return open(x, y);
    try {
      await _channel.invokeMethod('showSystemMenu', x == null || y == null ? null : {'x': x, 'y': y});
    } catch (_) {
      // an old runner without the menu: nothing happens, as before
    }
  }

  /// Opens the menu where the pointer is (a click on the bar).
  static Future<void> openAtCursor() => available ? _send(null, null) : Future.value();

  /// Opens the menu at [logical], a point of the window in logical pixels (the position of a pointer event, or of a widget on the screen of the window).
  static Future<void> openAt(BuildContext context, Offset logical) {
    if (!available) return Future.value();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return _send((logical.dx * ratio).round(), (logical.dy * ratio).round());
  }

  /// Opens the menu under the widget of [context], at its left edge: under the icon of the window.
  static Future<void> openBelow(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return Future.value();
    return openAt(context, box.localToGlobal(Offset(0, box.size.height)));
  }
}

/// The icon of the window: a click on it opens the window menu, under the icon. It does not take dragging, so the bar can still be dragged by it.
class SdWindowMenuIcon extends StatelessWidget {
  const SdWindowMenuIcon({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!SdWindowMenu.available) return child;
    return Builder(
      builder: (context) => MouseRegion(
        child: GestureDetector(
          key: const ValueKey('sd-window-menu-icon'),
          behavior: HitTestBehavior.opaque,
          onTap: () => SdWindowMenu.openBelow(context),
          child: child,
        ),
      ),
    );
  }
}

/// The empty part of the bar: a right click on it opens the window menu at the pointer. What has a right click of its own (a tab) keeps it.
class SdWindowMenuRegion extends StatelessWidget {
  const SdWindowMenuRegion({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!SdWindowMenu.available) return child;
    return GestureDetector(
      key: const ValueKey('sd-window-menu-region'),
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (_) => SdWindowMenu.openAtCursor(),
      child: child,
    );
  }
}

/// Alt+Space anywhere in the window opens the window menu under the icon, like in every Windows window. It is seen by the window as a whole (whatever has the
/// focus), except where [keepsKeys] says the focused part sends its keys elsewhere: the screen of another computer in a session keeps Alt+Space, which
/// then goes to that computer.
class SdWindowMenuKeys extends StatefulWidget {
  const SdWindowMenuKeys({super.key, required this.child, this.keepsKeys, this.enabled = true});
  final Widget child;

  /// false where the window has a title bar of the system (it opens its own menu on Alt+Space)
  final bool enabled;

  /// gets the context of the focused widget; true = it keeps the key
  final bool Function(BuildContext focused)? keepsKeys;

  @override
  State<SdWindowMenuKeys> createState() => _SdWindowMenuKeysState();
}

class _SdWindowMenuKeysState extends State<SdWindowMenuKeys> {
  // a window may hold more than one of these (nested pages): only the first one opens the menu, or it would open twice
  static final List<_SdWindowMenuKeysState> _all = [];

  @override
  void initState() {
    super.initState();
    _all.add(this);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _all.remove(this);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled || !SdWindowMenu.available || _all.isEmpty || !identical(_all.first, this)) return false;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.space) return false;
    final k = HardwareKeyboard.instance;
    if (!k.isAltPressed || k.isControlPressed || k.isShiftPressed || k.isMetaPressed) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && focused.mounted && (widget.keepsKeys?.call(focused) ?? false)) return false;
    SdWindowMenu.openAt(context, SdWindowMenu.keyboardAnchor);
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
