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
    final chromeInfo = await ChromiumHelper.justExtractChrome(
      version: version,
      cachePath: p.join(savePath, cachePath),
    );
    print('Chrome extracted to: ${chromeInfo.executablePath}');
  } catch (e) {
    print('Error extracting Chrome: $e');
    exit(1);
  }
}
