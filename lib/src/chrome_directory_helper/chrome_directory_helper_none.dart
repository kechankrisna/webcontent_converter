import 'dart:async';

class ChromeDesktopDirectoryHelper {
  
  static const String appsDirPath = ".apps";

  static String? assetChromeZipPath() => null;

  static FutureOr<String> zipFileName() => "";

  static FutureOr<String> saveChromeFromAssetToApp({
    String? assetPath = null,
  }) => "";
  
  static FutureOr<String> ensureChromeExecutable({
    String? assetPath = null,
  }) => "";
  
  static FutureOr<String> getChromeExecutableOrExtract({
    String? assetPath,
    bool forceReextract = false,
  })  => "";

  static FutureOr<String> getOrCreateChromeExecutable({
    String? assetPath = null,
  }) => "";

  static FutureOr<void> unzip(String path, String targetPath) {}

  static FutureOr<void> simpleUnzip(String path, String targetPath) {}

  static FutureOr<String> applicationSupportPath() => "";

  static FutureOr<String> getChromeExecutablePath() => "";
}