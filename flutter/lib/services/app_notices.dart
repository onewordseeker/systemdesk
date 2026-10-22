import 'dart:convert';
import 'dart:io';

/// What the running app learns from the license server every few seconds (POST /api/app/poll): messages the administrators sent to it,
/// and the version it must be updated to. Only the data and the rules live here; app_poll.dart does the asking and the showing.

/// "1.5.8" -> [1, 5, 8]; null when it is not three numbers.
List<int>? parseAppVersion(String? v) {
  final m = RegExp(r'^\s*(\d{1,6})\.(\d{1,6})\.(\d{1,6})\s*$').firstMatch(v ?? '');
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// -1 / 0 / 1 like compareTo. A version that is not three numbers counts as the lowest.
int compareAppVersions(String? a, String? b) {
  final x = parseAppVersion(a), y = parseAppVersion(b);
  if (x == null || y == null) return x == y ? 0 : (x == null ? -1 : 1);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return 0;
}

/// The name the license server knows this system by (windows, macos, linux, android, ios).
String appPlatformName() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'web';
}

/// A message an administrator sent to the app. [severity]: info | success | warning | critical.
class AppMessage {
  final String id;
  final String title;
  final String body;
  final String severity;
  const AppMessage({required this.id, required this.title, required this.body, this.severity = 'info'});

  static List<AppMessage> listFrom(dynamic json) {
    if (json is! List) return const [];
    final out = <AppMessage>[];
    for (final m in json) {
      if (m is! Map || m['id'] == null || m['title'] is! String || m['body'] is! String) continue;
      final sev = m['severity'];
      out.add(AppMessage(
        id: m['id'].toString(),
        title: m['title'] as String,
        body: m['body'] as String,
        severity: sev is String && const ['info', 'success', 'warning', 'critical'].contains(sev) ? sev : 'info',
      ));
    }
    return out;
  }
}

/// How many message ids the app remembers having shown (the oldest are forgotten first).
const kSeenMessagesKept = 60;

/// The messages not shown yet, in the order they came. [seen]: the remembered ids, comma separated.
List<AppMessage> unseenMessages(List<AppMessage> all, String seen) {
  final done = seen.split(',').where((s) => s.isNotEmpty).toSet();
  return [for (final m in all) if (!done.contains(m.id)) m];
}

/// [seen] with [id] added, keeping the newest [kSeenMessagesKept].
String rememberSeen(String seen, String id) {
  final ids = seen.split(',').where((s) => s.isNotEmpty && s != id).toList()..add(id);
  return ids.sublist(ids.length > kSeenMessagesKept ? ids.length - kSeenMessagesKept : 0).join(',');
}

/// The version every app must be at least at (the console's "Required update"), as the poll says it.
class RequiredUpdate {
  final String version;
  final String message;
  final String downloadUrl;
  const RequiredUpdate({required this.version, this.message = '', this.downloadUrl = ''});

  /// The poll's `update` object; null when no update is required.
  static RequiredUpdate? fromPoll(dynamic json) {
    if (json is! Map || json['required'] != true) return null;
    return fromJson(json);
  }

  static RequiredUpdate? fromJson(dynamic json) {
    if (json is! Map || parseAppVersion(json['version'] as String?) == null) return null;
    return RequiredUpdate(
      version: (json['version'] as String).trim(),
      message: json['message'] is String ? json['message'] as String : '',
      downloadUrl: json['download_url'] is String ? json['download_url'] as String : '',
    );
  }

  /// What is remembered between runs, so an app started offline cannot be used while an update is required.
  String toStored() => jsonEncode({'version': version, 'message': message, 'download_url': downloadUrl});

  static RequiredUpdate? fromStored(String stored) {
    if (stored.isEmpty) return null;
    try {
      return fromJson(jsonDecode(stored));
    } catch (_) {
      return null;
    }
  }

  /// Still in force for an app at [current] (an app whose version is unknown stays stopped).
  bool appliesTo(String current) => parseAppVersion(current) == null || compareAppVersions(current, version) < 0;

  @override
  bool operator ==(Object other) =>
      other is RequiredUpdate && other.version == version && other.message == message && other.downloadUrl == downloadUrl;

  @override
  int get hashCode => Object.hash(version, message, downloadUrl);
}
