import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:webcontent_converter/revision_info.dart';

import 'chrome_helper.dart';

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
      platform = _platformFromString(platformString);
      print('📱 Using specified platform: ${platform.folder}');
    } catch (e) {
      print('❌ Invalid platform: $platformString');
      _printUsage(parser);
      exit(1);
    }
  } else {
    // Auto-detect platform using proper detection
    platform = _detectCurrentPlatform();
    print('📱 Auto-detected platform: ${platform.folder}');
  }

  final version = ChromeInfoConfig.lastVersion;
  final cachePath = ChromeInfoConfig.localChromeDirectory;
  final savePath = Directory.current.path;

  print('🔧 Configuration:');
  print('   Platform: ${platform.folder}');
  print('   Version: $version');
  print('   Cache path: $cachePath');
  print('   Save path: $savePath');
  print('');

  RevisionInfo chromeInfo;

  try {
    final progress = DownloadProgress();
    chromeInfo = await ChromeHelper.justDownloadChrome(
      version: version,
      cachePath: p.join(savePath, cachePath),
      platform: platform,
    );
    print('');
    print('✅ Download finished: ${chromeInfo.executablePath}');
  } catch (e) {
    print('❌ Error downloading Chrome: $e');
    exit(1);
  }
}

// ✅ FIXED: Platform detection function
BrowserPlatform _detectCurrentPlatform() {
  if (Platform.isMacOS) {
    // Check if it's Apple Silicon or Intel
    if (Platform.version.contains('arm64') || Platform.version.contains('aarch64')) {
      return BrowserPlatform.macArm64;
    } else {
      return BrowserPlatform.macX64;
    }
  } else if (Platform.isWindows) {
    // Check if it's 64-bit or 32-bit
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
    if (arch.contains('64') || arch.toUpperCase().contains('AMD64')) {
      return BrowserPlatform.windows64;
    } else {
      return BrowserPlatform.windows32;
    }
  } else if (Platform.isLinux) {
    return BrowserPlatform.linux64;
  } else {
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

// ✅ FIXED: Platform string conversion
BrowserPlatform _platformFromString(String platformString) {
  switch (platformString.toLowerCase()) {
    case 'macos':
    case 'mac':
      // Default to ARM64 for new Macs, but could auto-detect
      return _detectCurrentPlatform().name.contains('mac') ? _detectCurrentPlatform() : BrowserPlatform.macArm64;
    case 'mac-arm64':
    case 'macos-arm64':
      return BrowserPlatform.macArm64;
    case 'mac-x64':
    case 'macos-x64':
    case 'mac-intel':
      return BrowserPlatform.macX64;
    case 'windows':
    case 'win':
      return BrowserPlatform.windows64; // Default to 64-bit
    case 'win32':
    case 'windows32':
      return BrowserPlatform.windows32;
    case 'win64':
    case 'windows64':
      return BrowserPlatform.windows64;
    case 'linux':
    case 'linux64':
      return BrowserPlatform.linux64;
    default:
      throw ArgumentError('Unsupported platform: $platformString. '
          'Supported platforms: macos, mac-arm64, mac-x64, windows, win32, win64, linux, linux64');
  }
}

// ✅ HELPER: Print usage information
void _printUsage(ArgParser parser) {
  print('🚀 Chrome Desktop Downloader');
  print('');
  print('Usage: dart run webcontent_converter:download_desktop [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  dart run webcontent_converter:download_desktop                    # Auto-detect platform');
  print('  dart run webcontent_converter:download_desktop --platform macos  # Download for macOS');
  print('  dart run webcontent_converter:download_desktop -p win64          # Download for Windows 64-bit');
  print('  dart run webcontent_converter:download_desktop --help            # Show this help');
  print('');
  print('Available platforms:');
  print('  📱 macos, mac-arm64, mac-x64    - macOS (auto-detect arch or specify)');
  print('  🖥️  windows, win32, win64        - Windows (auto-detect arch or specify)');  
  print('  🐧 linux, linux64               - Linux (64-bit)');
  print('');
  print('💡 Tip: Run without --platform to auto-detect your current system');
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
