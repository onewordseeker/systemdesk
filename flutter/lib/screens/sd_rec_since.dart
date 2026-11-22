/// When a recording began: set when it starts, forgotten when it ends, so the next one counts from its own start. The REC tag counts from it.
class SdRecSince {
  DateTime? _at;

  /// When the running recording began; null while none runs.
  DateTime? get at => _at;

  /// Tell it whether a recording runs now. The first time it is told "yes" the moment is kept (it is [now], the clock of the day unless a test brings its
  /// own); "no" forgets it.
  void update(bool recording, {DateTime Function()? now}) {
    if (!recording) {
      _at = null;
    } else {
      _at ??= (now ?? DateTime.now)();
    }
  }
}
