import 'dart:async';

import 'package:flutter/services.dart';
import 'package:webcontent_converter/revision_info.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:path/path.dart' as p;
import 'dart:io' as io;

class ChromeDesktopDirectoryHelper {
  static const version = ChromiumInfoConfig.lastVersion;

  static const String appsDirPath = ".apps";

  static String? assetChromeZipPath() {
    String? filename = zipFileName();
    // Use path separator consistent with asset paths in pubspec.yaml (always forward slashes)
    return appsDirPath.isEmpty
        ? 'assets/.local-chrome/${version}_$filename'
        : 'assets/$appsDirPath/.local-chrome/${version}_$filename';
  }

  static String zipFileName() {
    final platform = BrowserPlatform.current;
    if (platform == BrowserPlatform.macArm64 || platform == BrowserPlatform.macX64) {
      return 'chrome-${platform.folder}.zip';
    } else if (platform == BrowserPlatform.windows32 || platform == BrowserPlatform.windows64) {
      return 'chrome-${platform.folder}.zip';
    } else if (platform == BrowserPlatform.linux64) {
      return 'chrome-${platform.folder}.zip';
    }
    return "";
  }

  /// extract chrome to support dir
  /// and return the absolute path
  static FutureOr<String> saveChromeFromAssetToApp({
    String? assetPath = null,
  }) async {
    final targetPath = await applicationSupportPath();
    final platform = BrowserPlatform.current;
    
    final targetDirectory = io.Directory(
        p.joinAll([targetPath, 'chrome-${platform.folder}']));
    print("targetPath ${targetPath}");
    print("targetDirectory ${targetDirectory.path}");

    /// create target directory if not exist
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
    }

    final executablePath = ChromiumInfoConfig.getExecutablePath(targetPath, platform);
    
    final executableFile = io.File(executablePath);

    /// check zip from asset
    final _assetPath = assetPath ?? assetChromeZipPath();
    final zipPath = io.Directory(p.joinAll([
      (await path.getApplicationSupportDirectory()).path,
      zipFileName()
    ])).path;
    final zipFile = io.File(zipPath);

    /// if local chrome not exist
    if (!executableFile.existsSync()) {
      print("executableFile not exist");

      /// if zip never stored
      if (!zipFile.existsSync()) {
        print("zipFile not exist");
        print("assetPath $_assetPath");

        final value = await rootBundle.load(_assetPath!);
        Uint8List wzzip =
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
          'xattr', ['-d', 'com.apple.quarantine', chromeAppPath]);
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
    var targetDirectory = io.Directory(targetPath);
    if (targetDirectory.existsSync()) {
      targetDirectory.deleteSync(recursive: true);
    }

    var bytes = io.File(path).readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);

    for (var file in archive) {
      var filename = file.name;
      var data = file.content as List<int>;
      if (data.isNotEmpty) {
        io.File(p.join(targetPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }
  }

  static FutureOr<String> applicationSupportPath() async {
    var supportDir = await path.getApplicationSupportDirectory();
    return appsDirPath.isEmpty
        ? io.Directory(
                p.joinAll([supportDir.path, '.local-chrome', version]))
            .absolute
            .path
        : io.Directory(p.joinAll(
                [supportDir.path, appsDirPath, '.local-chrome', version]))
            .absolute
            .path;
  }

  static FutureOr<String> getChromeExecutablePath() {
    final platform = BrowserPlatform.current;
    return ChromiumInfoConfig.getExecutableRelativePath(platform);
  }
}
