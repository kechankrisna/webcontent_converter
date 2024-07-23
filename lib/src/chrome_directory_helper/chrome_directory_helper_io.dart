import 'dart:async';
import 'dart:io' as io;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path;

import '../../revision_info.dart';

class ChromeDesktopDirectoryHelper {
  static const revision = ChromiumInfoConfig.lastRevision;

  static const String appsDirPath = 'apps';

  static String? assetChromeZipPath() {
    final filename = zipFileName();
    return appsDirPath.isEmpty
        ? p.joinAll(['assets', '.local-chromium', '${revision}_$filename'])
        : p.joinAll([
            'assets',
            appsDirPath,
            '.local-chromium',
            '${revision}_$filename',
          ]);
  }

  static String zipFileName() {
    if (io.Platform.isMacOS) {
      return 'chrome-mac.zip';
    } else if (io.Platform.isWindows) {
      return 'chrome-win.zip';
    } else if (io.Platform.isLinux) {
      return 'chrome-linux.zip';
    }
    return '';
  }

  /// extract chrome to support dir
  /// and return the absolute path
  static FutureOr<String> saveChromeFromAssetToApp({
    String? assetPath,
  }) async {
    final targetPath = await applicationSupportPath();

    final tagetDirectory = io.Directory(
        p.joinAll([targetPath, zipFileName().replaceAll('.zip', '')]),);
    print('targetPath $targetPath');
    print('tagetDirectory ${tagetDirectory.path}');

    /// create tareget direcotry if not exist
    if (!tagetDirectory.existsSync()) {
      tagetDirectory.createSync(recursive: true);
    }

    final executablePath =
        p.joinAll([targetPath, await getChromeExecutablePath()]);

    /// print("targetPath $targetPath");
    /// print("getExecutablePath $getExecutablePath");
    /// print("executablePath $executablePath");
    final executableFile = io.File(executablePath);

    /// check zip from asset
    final assetPath0 = assetPath ?? assetChromeZipPath();
    final zipPath = io.Directory(p.joinAll([
      (await path.getApplicationSupportDirectory()).path,
      zipFileName(),
    ]),).path;
    final zipFile = io.File(zipPath);

    /// if locale chrome not exist
    if (!executableFile.existsSync()) {
      print('executableFile not exist');

      /// if zip never stored
      if (!zipFile.existsSync()) {
        print('zipFile not exist');
        print('assetPath $assetPath0');

        final value = await rootBundle.load(assetPath0!);
        final wzzip =
            value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);
        zipFile.writeAsBytesSync(wzzip);
      }

      await unzip(zipFile.path, targetPath);
    }

    if (!executableFile.existsSync()) {
      throw Exception("$executablePath doesn't exist");
    }

    if (!io.Platform.isWindows) {
      await io.Process.run('chmod', ['+x', executableFile.absolute.path]);
    }

    if (io.Platform.isMacOS) {
      final chromeAppPath = executableFile.absolute.parent.parent.parent.path;

      await io.Process.run(
          'xattr', ['-d', 'com.apple.quarantine', chromeAppPath],);
    }

    return executableFile.absolute.path;
  }

  static FutureOr<void> unzip(String path, String targetPath) async {
    if (!io.Platform.isWindows) {
      // The _simpleUnzip doesn't support symlinks so we prefer a native command
      await io.Process.run('unzip', [path, '-d', targetPath]);
    } else {
      simpleUnzip(path, targetPath);
    }
  }

//https://github.com/maxogden/extract-zip/blob/master/index.js
  static FutureOr<void> simpleUnzip(String path, String targetPath) {
    final targetDirectory = io.Directory(targetPath);
    if (targetDirectory.existsSync()) {
      targetDirectory.deleteSync(recursive: true);
    }

    final bytes = io.File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      final data = file.content as List<int>;
      if (data.isNotEmpty) {
        io.File(p.join(targetPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }
  }

  static FutureOr<String> applicationSupportPath() async {
    final supportDir = await path.getApplicationSupportDirectory();
    return appsDirPath.isEmpty
        ? io.Directory(
                p.joinAll([supportDir.path, '.local-chromium', '$revision']),)
            .absolute
            .path
        : io.Directory(p.joinAll(
                [supportDir.path, appsDirPath, '.local-chromium', '$revision'],),)
            .absolute
            .path;
  }

  static FutureOr<String> getChromeExecutablePath() {
    if (io.Platform.isWindows) {
      return p.join('chrome-win', 'chrome.exe');
    } else if (io.Platform.isLinux) {
      return p.join('chrome-linux', 'chrome');
    } else if (io.Platform.isMacOS) {
      return p.join(
          'chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium',);
    } else {
      throw UnsupportedError('Unknown platform ${io.Platform.operatingSystem}');
    }
  }
}
