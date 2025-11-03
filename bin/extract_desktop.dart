import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

import 'chrome_helper.dart';

Future<void> main() async {
  final version = ChromeInfoConfig.lastVersion;
  final cachePath = ChromeInfoConfig.localChromeDirectory;
  final savePath = Directory.current.path;

  print('Using cachePath = $cachePath');

  try {
    final chromeInfo = await ChromeHelper.justExtractChrome(
      version: version,
      cachePath: p.join(savePath, cachePath),
    );
    print('Chrome extracted to: ${chromeInfo.executablePath}');
  } catch (e) {
    print('Error extracting Chrome: $e');
    exit(1);
  }
}
