import 'dart:io' as io;
import 'package:path/path.dart' as p;

class RevisionInfo {
  final String executablePath;
  final String folderPath;
  final String version;

  RevisionInfo({
    required this.executablePath,
    required this.folderPath,
    required this.version,
  });
}

class ChromiumInfoConfig {
  static const String lastVersion = '131.0.6778.204';

  static String getExecutablePath(
      String versionPath, BrowserPlatform platform) {
    return p.join(versionPath, getExecutableRelativePath(platform));
  }

  static String getExecutableRelativePath(BrowserPlatform platform) {
    return switch (platform) {
      BrowserPlatform.macArm64 || BrowserPlatform.macX64 => p.join(
          'chrome-${platform.folder}',
          'Google Chrome for Testing.app',
          'Contents',
          'MacOS',
          'Google Chrome for Testing',
        ),
      BrowserPlatform.linux64 => p.join('chrome-${platform.folder}', 'chrome'),
      BrowserPlatform.windows32 || BrowserPlatform.windows64 => p.join(
          'chrome-${platform.folder}',
          'chrome.exe',
        ),
    };
  }

  static String localChromeDirectory =
      p.joinAll(["assets", ".apps", ".local-chrome"]);

  static String getLocalChromeExecutablePath() {
    final platform = BrowserPlatform.current;
    return io.Directory(ChromiumInfoConfig.getExecutablePath(
            p.joinAll([localChromeDirectory, lastVersion]), platform))
        .absolute
        .path;
  }
}

enum BrowserPlatform {
  macArm64._('macos_arm64', 'mac-arm64'),
  macX64._('macos_x64', 'mac-x64'),
  linux64._('linux_x64', 'linux64'),
  windows32._('windows_ia32', 'win32'),
  windows64._('windows_x64', 'win64');

  final String dartPlatform;
  final String folder;

  const BrowserPlatform._(this.dartPlatform, this.folder);

  factory BrowserPlatform.fromDartPlatform(String versionStringFull) {
    final split = versionStringFull.split('"');
    if (split.length < 2) {
      throw FormatException(
        "Unknown version from Platform.version '$versionStringFull'.",
      );
    }
    final versionString = split[1];
    return values.firstWhere(
      (e) => e.dartPlatform == versionString,
      orElse: () => throw FormatException(
        "Unknown '$versionString' from Platform.version"
        " '$versionStringFull'.",
      ),
    );
  }

  static final BrowserPlatform current = BrowserPlatform.fromDartPlatform(
    io.Platform.version,
  );

  static BrowserPlatform fromString(String platformString) {
    switch (platformString.toLowerCase()) {
      case 'macos':
      case 'mac':
        return BrowserPlatform.macArm64; // Default to ARM64 for new Macs
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
        throw ArgumentError('Unsupported platform: $platformString');
    }
  }
}
