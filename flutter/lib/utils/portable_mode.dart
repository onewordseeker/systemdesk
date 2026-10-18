/// True when the running exe is the installed copy: it lives in the install folder (C:\Program Files\SystemDesk). A copy that runs from
/// anywhere else (Downloads, Desktop, the temporary folder a single-file exe unpacks itself into) is a portable run.
bool runsFromInstallFolder(String exePath, String installDir) {
  String norm(String p) =>
      p.toLowerCase().replaceAll('/', '\\').replaceFirst(RegExp(r'\\+$'), '');
  final dir = norm(installDir);
  if (dir.isEmpty) return false;
  return norm(exePath).startsWith('$dir\\');
}
