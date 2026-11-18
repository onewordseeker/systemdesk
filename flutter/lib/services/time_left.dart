import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/screens/sd_look.dart';

/// How many minutes the account has left today. The main window keeps the account's summary; it hands the figure to the windows of the sessions through a
/// local option, and they count down from it until the next one comes (once a minute).
class SdTimeLeft {
  SdTimeLeft._();

  static const String _key = 'sd_time_left';

  /// a figure older than this is not shown (the main window is not refreshing it)
  static const Duration _stale = Duration(minutes: 5);

  /// [dailyLimit] <= 0: no daily limit, so there is nothing to count down
  static void publish({required int dailyLimit, required double minutesLeft}) {
    if (!SdLook.enabled) return;
    final value = dailyLimit <= 0 ? '' : '${minutesLeft.toStringAsFixed(2)}|${DateTime.now().millisecondsSinceEpoch}';
    bind.mainSetLocalOption(key: _key, value: value);
  }

  static void clear() {
    if (!SdLook.enabled) return;
    bind.mainSetLocalOption(key: _key, value: '');
  }

  /// null: not known (signed out, no daily limit, or the figure is too old)
  static int? minutesLeft() {
    final parts = bind.mainGetLocalOption(key: _key).split('|');
    if (parts.length != 2) return null;
    final left = double.tryParse(parts[0]);
    final at = int.tryParse(parts[1]);
    if (left == null || at == null) return null;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (age > _stale) return null;
    final rest = left - age.inSeconds / 60;
    return rest <= 0 ? 0 : rest.ceil();
  }
}
