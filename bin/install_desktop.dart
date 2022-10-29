import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

class ChromiumHelper {
  /// use in case when user just only want to download chromium version for their app
  /// 
  static Future<RevisionInfo> justDownloadChrome(
      {int? revision, String? cachePath}) async {
    revision ??= ChromiumInfoConfig.lastRevision;
    cachePath ??= '.local-chromium';

    var revisionDirectory = Directory(p.join(cachePath, '$revision'));
    if (!revisionDirectory.existsSync()) {
      revisionDirectory.createSync(recursive: true);
    }

    var url = downloadUrl(revision);
    var zipPath = p.join(cachePath, '${revision}_${p.url.basename(url)}');
    var zipFile = File(zipPath);
    if (!zipFile.existsSync()) {
      await downloadFile(url, zipPath);
    }

    if (!zipFile.existsSync()) {
      throw Exception("$zipPath doesn't exist");
    }

    return RevisionInfo(
        folderPath: revisionDirectory.path,
        executablePath: zipFile.path,
        revision: revision);
  }

  /// use in case when user just want to extract their downloaded chromium file
  /// 
  static Future<RevisionInfo> justExtractChrome(
      {int? revision, String? cachePath}) async {
    revision ??= ChromiumInfoConfig.lastRevision;
    cachePath ??= '.local-chromium';

    var revisionDirectory = Directory(p.join(cachePath, '$revision'));
    if (!revisionDirectory.existsSync()) {
      revisionDirectory.createSync(recursive: true);
    }

    var exePath = ChromiumInfoConfig.getExecutablePath(revisionDirectory.path);

    var executableFile = File(exePath);
    
    var url = downloadUrl(revision);
    var zipPath = p.join(cachePath, '${revision}_${p.url.basename(url)}');

    if (!executableFile.existsSync()) {
      unzip(zipPath, revisionDirectory.path);
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
        folderPath: revisionDirectory.path,
        executablePath: executableFile.path,
        revision: revision);
  }


  /// originally from pupeteer-dart in case download and extract chromium file when the download zip will be deleted
  /// 
  static Future<RevisionInfo> downloadChrome(
      {int? revision, String? cachePath}) async {
    revision ??= ChromiumInfoConfig.lastRevision;
    cachePath ??= '.local-chromium';

    var revisionDirectory = Directory(p.join(cachePath, '$revision'));
    if (!revisionDirectory.existsSync()) {
      revisionDirectory.createSync(recursive: true);
    }

    var exePath = ChromiumInfoConfig.getExecutablePath(revisionDirectory.path);

    var executableFile = File(exePath);

    if (!executableFile.existsSync()) {
      var url = downloadUrl(revision);
      var zipPath = p.join(cachePath, '${revision}_${p.url.basename(url)}');
      await downloadFile(url, zipPath);

      unzip(zipPath, revisionDirectory.path);
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
        folderPath: revisionDirectory.path,
        executablePath: executableFile.path,
        revision: revision);
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

  static void unzip(String path, String targetPath) {
    if (!Platform.isWindows) {
      // The _simpleUnzip doesn't support symlinks so we prefer a native command
      Process.runSync('unzip', [path, '-d', targetPath]);
    } else {
      simpleUnzip(path, targetPath);
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

  static const _baseUrl =
      'https://storage.googleapis.com/chromium-browser-snapshots';

  static String downloadUrl(int revision) {
    if (Platform.isWindows) {
      return '$_baseUrl/Win_x64/$revision/chrome-win.zip';
    } else if (Platform.isLinux) {
      return '$_baseUrl/Linux_x64/$revision/chrome-linux.zip';
    } else if (Platform.isMacOS) {
      return '$_baseUrl/Mac/$revision/chrome-mac.zip';
    } else {
      throw UnsupportedError(
          "Can't download chrome for platform ${Platform.operatingSystem}");
    }
  }

}

void main(List<String> args) async {
  var revision =
      await ChromiumHelper.downloadChrome(cachePath: "assets/.local-chromium");
  print("path ${revision.executablePath}");
}

/// just download
void download(List<String> args) async {
  var revision =
      await ChromiumHelper.justDownloadChrome(cachePath: "assets/.local-chromium");
  print("path ${revision.executablePath}");
}

/// just extract the chromium in asset directory which can be shipped with application
void extract(List<String> args) async {
  var revision =
      await ChromiumHelper.justExtractChrome(cachePath: "assets/.local-chromium");
  print("path ${revision.executablePath}");
}