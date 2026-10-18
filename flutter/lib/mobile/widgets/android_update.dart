import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _releases = 'https://github.com/onewordseeker/systemdesk/releases/';

/// The part of this device's APK name that says which processor it is built for (rustdesk-<version>-<this>.apk), or null.
Future<String?> apkAbiSuffix() async {
  final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
  for (final abi in abis) {
    if (abi == 'arm64-v8a') return 'aarch64';
    if (abi == 'armeabi-v7a') return 'armv7';
    if (abi == 'x86_64') return 'x86_64';
  }
  return null;
}

/// The address of this device's APK inside a release page address (.../releases/tag/1.7.2), or null when the page is not one of ours.
String? apkUrlFor(String releasePageUrl, String abiSuffix) {
  if (!releasePageUrl.startsWith('${_releases}tag/')) return null;
  final version = releasePageUrl.substring(releasePageUrl.lastIndexOf('/') + 1);
  if (!RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(version)) return null;
  return '${_releases}download/$version/rustdesk-$version-$abiSuffix.apk';
}

/// The hash a SHA256SUMS.txt line gives for [fileName], or null.
String? checksumFor(String sums, String fileName) {
  for (final line in sums.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 2 && parts[1].replaceFirst('*', '') == fileName) {
      return parts[0].toLowerCase();
    }
  }
  return null;
}

/// Update the Android app in place: download this device's APK from our release (with progress), check it against the release's
/// SHA256SUMS.txt, then hand it to Android's installer. Android asks the person to confirm and only accepts an APK signed with the same
/// key as the installed app; after the install the new version is opened from the installer's own "Open" button.
Future<void> startAndroidUpdate(BuildContext context, String releasePageUrl) async {
  Future<void> openPage() => launchUrl(Uri.parse(releasePageUrl));
  final abi = await apkAbiSuffix();
  final url = abi == null ? null : apkUrlFor(releasePageUrl, abi);
  if (abi == null || url == null) {
    await openPage();
    return;
  }
  final fileName = url.substring(url.lastIndexOf('/') + 1);
  final progress = ValueNotifier<double?>(null);
  var cancelled = false;
  final client = http.Client();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Downloading the update'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: v),
            const SizedBox(height: 10),
            Text(v == null ? 'Starting...' : '${(v * 100).round()} %'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            client.close();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  void closeDialog() {
    if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> fail(String text) async {
    closeDialog();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('The update was not installed'),
        content: Text(text),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openPage();
              },
              child: const Text('Download')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  try {
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');
    if (await file.exists()) await file.delete();
    final response = await client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      await fail('The download answered ${response.statusCode}. You can download it from the release page instead.');
      return;
    }
    final total = response.contentLength ?? 0;
    var got = 0;
    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress.value = got / total;
    }
    await sink.close();
    if (cancelled) return;
    if (got < 1024 * 1024) {
      await fail('The downloaded file is too small to be the app.');
      return;
    }
    // the release lists a hash for every file: a damaged or swapped file is not installed
    try {
      final sums = await http.get(Uri.parse('${url.substring(0, url.lastIndexOf('/'))}/SHA256SUMS.txt'));
      if (sums.statusCode == 200) {
        final expected = checksumFor(sums.body, fileName);
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (expected != null && expected != actual) {
          await file.delete();
          await fail('The downloaded file does not match the release\'s checksum, so it was not installed.');
          return;
        }
      }
    } catch (_) {
      // no checksum list reachable: Android still refuses an APK that was not signed with this app's key
    }
    closeDialog();
    final result = await platformFFI.invokeMethod('install_apk', file.path);
    if (result == 'needs_permission' && context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow installing updates'),
          content: const Text(
              'Android needs your permission for SystemDesk to install its own updates. Allow it on the screen that just opened, then tap the update again.'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
    } else if (result is String && result.startsWith('error')) {
      await fail('Android could not start the installer ($result).');
    }
  } catch (e) {
    if (!cancelled) await fail('$e');
  } finally {
    client.close();
  }
}
