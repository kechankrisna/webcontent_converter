import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

class ChromiumHelper {
  /// Download Chrome without extracting for use in your app
  static Future<RevisionInfo> justDownloadChrome(
      {String? version, String? cachePath}) async {
    version ??= ChromiumInfoConfig.lastVersion;
    cachePath ??= '.local-chrome';
    final platform = BrowserPlatform.current;

    var versionDirectory = Directory(p.join(cachePath, version));
    if (!versionDirectory.existsSync()) {
      versionDirectory.createSync(recursive: true);
    }

    var url = _versionDownloadUrl(platform, version);
    var zipPath = p.join(cachePath, '${version}_${p.url.basename(url)}');
    print("url $url");
    print("zipPath $zipPath");
    var zipFile = File(zipPath);
    if (!zipFile.existsSync()) {
      await downloadFile(url, zipPath);
    }

    if (!zipFile.existsSync()) {
      throw Exception("$zipPath doesn't exist");
    }

    return RevisionInfo(
        folderPath: versionDirectory.path,
        executablePath: zipFile.path,
        version: version);
  }

  /// Extract Chrome from a previously downloaded file
  static Future<RevisionInfo> justExtractChrome(
      {String? version, String? cachePath}) async {
    version ??= ChromiumInfoConfig.lastVersion;
    cachePath ??= '.local-chrome';
    final platform = BrowserPlatform.current;

    var versionDirectory = Directory(p.join(cachePath, version));
    if (!versionDirectory.existsSync()) {
      versionDirectory.createSync(recursive: true);
    }

    var executableRelativePath = ChromiumInfoConfig.getExecutableRelativePath(platform);
    var exePath = p.join(versionDirectory.path, executableRelativePath);
    var executableFile = File(exePath);

    var url = _versionDownloadUrl(platform, version);
    var zipPath = p.join(cachePath, '${version}_${p.url.basename(url)}');

    if (!executableFile.existsSync()) {
      unzip(zipPath, versionDirectory.path);
    }

    if (!executableFile.existsSync()) {
      throw Exception("$exePath doesn't exist");
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', executableFile.absolute.path]);
    }

    if (Platform.isMacOS) {
      final chromeAppPath = executableFile.absolute.parent.parent.parent.path;
      await Process.run('xattr', ['-d', 'com.apple.quarantine', chromeAppPath]);
    }

    return RevisionInfo(
        folderPath: versionDirectory.path,
        executablePath: executableFile.path,
        version: version);
  }

  /// Download and extract Chrome in one operation (will delete the zip file after extraction)
  static Future<RevisionInfo> downloadChrome({
    String? version,
    String? cachePath,
    void Function(int received, int total)? onDownloadProgress
  }) async {
    version ??= ChromiumInfoConfig.lastVersion;
    cachePath ??= '.local-chrome';
    final platform = BrowserPlatform.current;

    var versionDirectory = Directory(p.join(cachePath, version));
    if (!versionDirectory.existsSync()) {
      versionDirectory.createSync(recursive: true);
    }

    var executableRelativePath = ChromiumInfoConfig.getExecutableRelativePath(platform);
    var exePath = p.join(versionDirectory.path, executableRelativePath);
    var executableFile = File(exePath);

    if (!executableFile.existsSync()) {
      var url = _versionDownloadUrl(platform, version);
      var zipPath = p.join(versionDirectory.path, p.url.basename(url));
      await _downloadFileWithProgress(url, zipPath, onDownloadProgress);
      unzip(zipPath, versionDirectory.path);
      File(zipPath).deleteSync();
    }

    if (!executableFile.existsSync()) {
      throw Exception("$exePath doesn't exist");
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', executableFile.absolute.path]);
    }

    if (Platform.isMacOS) {
      final chromeAppPath = executableFile.absolute.parent.parent.parent.path;
      await Process.run('xattr', ['-d', 'com.apple.quarantine', chromeAppPath]);
    }

    return RevisionInfo(
        folderPath: versionDirectory.path,
        executablePath: executableFile.path,
        version: version);
  }

  static Future downloadFile(String url, String output) async {
    var client = http.Client();
    var response = await client.send(http.Request('get', Uri.parse(url)));
    var ouputFile = File(output);
    await response.stream.pipe(ouputFile.openWrite());
    client.close();

    if (!ouputFile.existsSync() || ouputFile.lengthSync() == 0) {
      throw Exception('File was not downloaded from $url to $output');
    }
  }

  static Future _downloadFileWithProgress(
    String url,
    String output,
    void Function(int, int)? onReceiveProgress,
  ) async {
    final client = http.Client();
    final response = await client.send(http.Request('get', Uri.parse(url)));
    final totalBytes = response.contentLength ?? 0;
    final outputFile = File(output);
    var receivedBytes = 0;

    await response.stream
        .map((s) {
          receivedBytes += s.length;
          onReceiveProgress?.call(receivedBytes, totalBytes);
          return s;
        })
        .pipe(outputFile.openWrite());

    client.close();
    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      throw Exception('File was not downloaded from $url to $output');
    }
  }

  static void unzip(String path, String targetPath) {
    if (!Platform.isWindows) {
      // The _simpleUnzip doesn't support symlinks so we prefer a native command
      Process.runSync('unzip', [path, '-d', targetPath]);
    } else {
      try {
        var result = Process.runSync('tar', ['-xf', path, '-C', targetPath]);
        if (result.exitCode != 0) {
          throw Exception('Failed to unzip chrome binaries:\n${result.stderr}');
        }
      } on ProcessException {
        simpleUnzip(path, targetPath);
      }
    }
  }

//TODO(xha): implement a more complete unzip
//https://github.com/maxogden/extract-zip/blob/master/index.js
  static void simpleUnzip(String path, String targetPath) {
    var targetDirectory = Directory(targetPath);
    if (targetDirectory.existsSync()) {
      targetDirectory.deleteSync(recursive: true);
    }

    var bytes = File(path).readAsBytesSync();
    var archive = ZipDecoder().decodeBytes(bytes);

    for (var file in archive) {
      var filename = file.name;
      var data = file.content as List<int>;
      if (data.isNotEmpty) {
        File(p.join(targetPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }
  }

  static const _versionBaseUrl = 
      'https://storage.googleapis.com/chrome-for-testing-public';

  static String _versionDownloadUrl(BrowserPlatform platform, String version) {
    return '$_versionBaseUrl/$version/${platform.folder}/chrome-${platform.folder}.zip';
  }
}
