import 'dart:async';

import 'package:flutter/services.dart';
import 'package:webcontent_converter/revision_info.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart' as path;
import 'package:path/path.dart' as p;
import 'dart:io' as io;

class ChromeDesktopDirectoryHelper {
  static const version = ChromeInfoConfig.lastVersion;

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

    final executablePath = ChromeInfoConfig.getExecutablePath(targetPath, platform);
    
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
    return ChromeInfoConfig.getExecutableRelativePath(platform);
  }

  /// Check if Chrome executable exists, if not then extract from assets
  /// Returns the absolute path to the Chrome executable
  static FutureOr<String> ensureChromeExecutable({
    String? assetPath,
  }) async {
    final targetPath = await applicationSupportPath();
    final platform = BrowserPlatform.current;
    
    final executablePath = ChromeInfoConfig.getExecutablePath(targetPath, platform);
    final executableFile = io.File(executablePath);
    
    print("Checking Chrome executable at: $executablePath");
    
    // ✅ CHECK: If executable already exists, return its path
    if (executableFile.existsSync()) {
      print("✅ Chrome executable found at: ${executableFile.absolute.path}");
      
      // Verify it's actually executable on non-Windows platforms
      if (!io.Platform.isWindows) {
        final result = await io.Process.run('test', ['-x', executableFile.absolute.path]);
        if (result.exitCode != 0) {
          print("⚠️ Executable exists but not executable, fixing permissions...");
          await io.Process.run('chmod', ['+x', executableFile.absolute.path]);
        }
      }
      
      return executableFile.absolute.path;
    }
    
    // ✅ VALIDATE: Check if asset exists before extraction
    final _assetPath = assetPath ?? assetChromeZipPath();
    if (_assetPath == null || _assetPath.isEmpty) {
      throw Exception("❌ No Chrome asset path configured for platform: ${platform.folder}");
    }
    
    // ✅ CHECK: Asset availability
    try {
      print("🔍 Validating asset availability: $_assetPath");
      final assetData = await rootBundle.load(_assetPath);
      if (assetData.lengthInBytes == 0) {
        throw Exception("❌ Chrome asset exists but is empty: $_assetPath");
      }
      print("✅ Chrome asset validated: ${assetData.lengthInBytes} bytes");
    } catch (e) {
      throw Exception("❌ Chrome asset not found or invalid: $_assetPath\n"
          "Make sure to add the Chrome asset to your pubspec.yaml:\n"
          "flutter:\n"
          "  assets:\n"
          "    - $_assetPath\n"
          "Error: $e");
    }
    
    // ✅ EXTRACT: If validation passes, extract from assets
    print("📦 Chrome executable not found, extracting from assets...");
    return await saveChromeFromAssetToApp(assetPath: assetPath);
  }

  /// Alternative version with more detailed checking
  static FutureOr<String> getChromeExecutableOrExtract({
    String? assetPath,
    bool forceReextract = false,
  }) async {
    final targetPath = await applicationSupportPath();
    final platform = BrowserPlatform.current;
    
    final executablePath = ChromeInfoConfig.getExecutablePath(targetPath, platform);
    final executableFile = io.File(executablePath);
    
    print("Chrome executable check: $executablePath");
    
    // ✅ FORCE: Re-extract if requested
    if (forceReextract) {
      print("🔄 Force re-extraction requested");
      await _validateAssetBeforeExtraction(assetPath);
      return await saveChromeFromAssetToApp(assetPath: assetPath);
    }
    
    // ✅ CHECK: Executable exists and is valid
    if (executableFile.existsSync()) {
      try {
        // Verify file size (should be > 0)
        final fileSize = executableFile.lengthSync();
        if (fileSize == 0) {
          print("⚠️ Chrome executable is empty, re-extracting...");
          await _validateAssetBeforeExtraction(assetPath);
          return await saveChromeFromAssetToApp(assetPath: assetPath);
        }
        
        // Verify permissions on non-Windows
        if (!io.Platform.isWindows) {
          final result = await io.Process.run('test', ['-x', executableFile.absolute.path]);
          if (result.exitCode != 0) {
            print("⚠️ Fixing Chrome executable permissions...");
            await io.Process.run('chmod', ['+x', executableFile.absolute.path]);
          }
        }
        
        // Additional macOS quarantine check
        if (io.Platform.isMacOS) {
          final chromeAppPath = executableFile.absolute.parent.parent.parent.path;
          await io.Process.run('xattr', ['-d', 'com.apple.quarantine', chromeAppPath])
              .catchError((e) => print("Quarantine removal failed (may already be removed): $e"));
        }
        
        print("✅ Chrome executable verified: ${executableFile.absolute.path}");
        return executableFile.absolute.path;
        
      } catch (e) {
        print("⚠️ Error verifying Chrome executable: $e");
        print("Re-extracting from assets...");
        await _validateAssetBeforeExtraction(assetPath);
        return await saveChromeFromAssetToApp(assetPath: assetPath);
      }
    }
    
    // ✅ EXTRACT: File doesn't exist
    print("❌ Chrome executable not found, extracting from assets...");
    await _validateAssetBeforeExtraction(assetPath);
    return await saveChromeFromAssetToApp(assetPath: assetPath);
  }

  /// Helper method to validate asset before extraction
  static Future<void> _validateAssetBeforeExtraction(String? assetPath) async {
    final _assetPath = assetPath ?? assetChromeZipPath();
    final platform = BrowserPlatform.current;
    
    if (_assetPath == null || _assetPath.isEmpty) {
      throw Exception("❌ No Chrome asset configured for platform: ${platform.folder}");
    }
    
    try {
      print("🔍 Validating Chrome asset: $_assetPath");
      final assetData = await rootBundle.load(_assetPath);
      if (assetData.lengthInBytes == 0) {
        throw Exception("❌ Chrome asset is empty");
      }
      print("✅ Asset validated: ${(assetData.lengthInBytes / 1024 / 1024).toStringAsFixed(1)} MB");
    } catch (e) {
      final availableAssets = await _listAvailableAssets();
      throw Exception("❌ Chrome asset validation failed: $_assetPath\n"
          "Platform: ${platform.folder}\n"
          "Error: $e\n\n"
          "💡 Solutions:\n"
          "1. Add the asset to pubspec.yaml:\n"
          "   flutter:\n"
          "     assets:\n"
          "       - $_assetPath\n\n"
          "2. Check if the file exists in your assets folder\n"
          "3. Run 'flutter clean' and rebuild\n\n"
          "Available assets: $availableAssets");
    }
  }

  /// Helper to list available Chrome assets for debugging
  static Future<List<String>> _listAvailableAssets() async {
    final possibleAssets = [
      'assets/.apps/.local-chrome/${version}_chrome-mac-arm64.zip',
      'assets/.apps/.local-chrome/${version}_chrome-mac-x64.zip',
      'assets/.apps/.local-chrome/${version}_chrome-win32.zip',
      'assets/.apps/.local-chrome/${version}_chrome-win64.zip',
      'assets/.apps/.local-chrome/${version}_chrome-linux64.zip',
      'assets/.local-chrome/${version}_chrome-mac-arm64.zip',
      'assets/.local-chrome/${version}_chrome-mac-x64.zip',
      'assets/.local-chrome/${version}_chrome-win32.zip',
      'assets/.local-chrome/${version}_chrome-win64.zip',
      'assets/.local-chrome/${version}_chrome-linux64.zip',
    ];
    
    final available = <String>[];
    for (final asset in possibleAssets) {
      try {
        await rootBundle.load(asset);
        available.add(asset);
      } catch (e) {
        // Asset doesn't exist, skip
      }
    }
    
    return available;
  }

  /// Safe version that handles missing assets gracefully
  static FutureOr<String?> tryGetChromeExecutable({
    String? assetPath,
  }) async {
    try {
      return await ensureChromeExecutable(assetPath: assetPath);
    } catch (e) {
      print("⚠️ Chrome executable setup failed: $e");
      return null;
    }
  }
}
