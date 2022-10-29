import 'dart:io' as io;
import 'package:path/path.dart' as p;

class RevisionInfo {
  final String executablePath;
  final String folderPath;
  final int revision;

  RevisionInfo(
      {required this.executablePath,
      required this.folderPath,
      required this.revision});
}

class ChromiumInfoConfig {
  static const int lastRevision = 1056772;

  static String getExecutablePath(String revisionPath) {
    if (io.Platform.isWindows) {
      return p.join(revisionPath, 'chrome-win', 'chrome.exe');
    } else if (io.Platform.isLinux) {
      return p.join(revisionPath, 'chrome-linux', 'chrome');
    } else if (io.Platform.isMacOS) {
      return p.join(revisionPath, 'chrome-mac', 'Chromium.app', 'Contents',
          'MacOS', 'Chromium');
    } else {
      throw UnsupportedError('Unknown platform ${io.Platform.operatingSystem}');
    }
  }

  static String localChromiumDirectory =
      p.joinAll(["assets", ".local-chromium"]);

  static String getLocalChromeExecutablePath() {
    return io.Directory(ChromiumInfoConfig.getExecutablePath(
        p.joinAll([localChromiumDirectory, "$lastRevision"]))).absolute.path;
  }
}
