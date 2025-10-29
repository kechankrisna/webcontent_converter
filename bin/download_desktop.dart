import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

import 'chromium_helper.dart';

Future<void> main(List<String> args) async {
  // ✅ PARSE: Command line arguments
  final parser = ArgParser()
    ..addOption('platform', 
        abbr: 'p', 
        help: 'Target platform (macos, windows, linux, mac-arm64, mac-x64, win32, win64, linux64)',
        allowed: ['macos', 'windows', 'linux', 'mac-arm64', 'mac-x64', 'win32', 'win64', 'linux64'])
    ..addFlag('help', 
        abbr: 'h', 
        help: 'Show usage information', 
        negatable: false);

  ArgResults argResults;
  
  try {
    argResults = parser.parse(args);
  } catch (e) {
    print('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }

  // ✅ HELP: Show usage if requested
  if (argResults['help']) {
    _printUsage(parser);
    return;
  }

  // ✅ PLATFORM: Get platform from argument or detect automatically
  final platformString = argResults['platform'] as String?;
  final BrowserPlatform platform;

  if (platformString != null) {
    // Use specified platform
    try {
      platform = BrowserPlatform.fromString(platformString);
      print('📱 Using specified platform: ${platform.folder}');
    } catch (e) {
      print('❌ Invalid platform: $platformString');
      _printUsage(parser);
      exit(1);
    }
  } else {
    // Auto-detect platform
    platform = BrowserPlatform.fromDartPlatform(Platform.operatingSystem);
    print('📱 Auto-detected platform: ${platform.folder}');
  }

  final version = ChromiumInfoConfig.lastVersion;
  final cachePath = ChromiumInfoConfig.localChromeDirectory;
  final savePath = Directory.current.path;

  print('🔧 Configuration:');
  print('   Platform: ${platform.folder}');
  print('   Version: $version');
  print('   Cache path: $cachePath');
  print('   Save path: $savePath');
  print('');

  RevisionInfo chromiumInfo;

  try {
    final progress = DownloadProgress();
    chromiumInfo = await ChromiumHelper.justDownloadChrome(
      version: version,
      cachePath: p.join(savePath, cachePath),
      platform: platform, // Pass the platform
    );
    print('');
    print('✅ Download finished: ${chromiumInfo.executablePath}');
  } catch (e) {
    print('❌ Error downloading Chrome: $e');
    exit(1);
  }
}

// ✅ HELPER: Print usage information
void _printUsage(ArgParser parser) {
  print('Chrome Downloader');
  print('');
  print('Usage: dart download_desktop.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart download_desktop.dart                    # Auto-detect platform');
  print('  dart download_desktop.dart --platform macos  # Download for macOS');
  print('  dart download_desktop.dart -p win64          # Download for Windows 64-bit');
  print('  dart download_desktop.dart --help            # Show this help');
  print('');
  print('Available platforms:');
  print('  macos, mac-arm64, mac-x64    - macOS (auto-detect arch or specify)');
  print('  windows, win32, win64        - Windows (auto-detect arch or specify)');  
  print('  linux, linux64               - Linux (64-bit)');
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
      stdout.write('🔽 Downloading Chrome $percentage% (${speed.toStringAsFixed(1)} KB/s)');
    }
  }
}
