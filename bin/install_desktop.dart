import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

import 'chromium_helper.dart';

Future<void> main() async {
  final version = ChromiumInfoConfig.lastVersion;
  final cachePath = ChromiumInfoConfig.localChromeDirectory;
  final savePath = Directory.current.path;

  print('Using cachePath = $cachePath');

  try {
    final progress = DownloadProgress();
    final chromeInfo = await ChromiumHelper.downloadChrome(
      version: version,
      cachePath: p.join(savePath, cachePath),
      onDownloadProgress: progress.update,
    );
    print('');
    print('Chrome installed at: ${chromeInfo.executablePath}');
  } catch (e) {
    print('Error installing Chrome: $e');
    exit(1);
  }
}

class DownloadProgress {
  final stopwatch = Stopwatch()..start();
  int? lastProgressValue;
  int? lastTimeValue;
  int? totalBytes;

  void update(int downloadedBytes, int totalBytes) {
    this.totalBytes = totalBytes;
    final percentage = (100 * downloadedBytes / totalBytes).toInt();
    final now = stopwatch.elapsedMilliseconds;
    final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
    final speed = downloadedBytes / 1024 / elapsedSeconds;

    if (percentage != lastProgressValue || now > (lastTimeValue ?? 0) + 500) {
      lastProgressValue = percentage;
      lastTimeValue = now;
      stdout.write('\r');
      stdout.write('Downloading Chrome $percentage% ($speed kb/s)');
    }
  }
}
