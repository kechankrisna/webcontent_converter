import 'dart:io' as io;

class WebViewHelper {
  static List<String> get desktopBrowserAvailablePath {
    if (io.Platform.isWindows) {
      return windowBrowserAvailablePath;
    } else if (io.Platform.isMacOS) {
      return macosBrowserAvailablePath;
    }
    return [];
  }

  static List<String> get windowBrowserAvailablePath => [
        "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
        "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
        "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
        "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
        "C:\\Program Files\\Mozilla Firefox\\firefox.exe",
        io.Directory("chromium").absolute.path,
      ];

  static List<String> get macosBrowserAvailablePath => [
        "/Applications/Microsoft\ Edge\ Canary.app/Contents/MacOS/Microsoft\ Edge\ Canary",
        "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome",
        "/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Firefox.app/Contents/MacOS/firefox",
        "/Applications/Firefox.app/Contents/MacOS/firefox-bin",
        io.Directory("chromium").absolute.path,
      ];

  static bool get isChromeAvailable {
    List<String> paths = desktopBrowserAvailablePath;

    for (var path in paths) {
      bool isExist = io.File(path).existsSync();
      if (isExist) {
        return true;
      }
    }

    return false;
  }

  static String executablePath() {
    var result;
    var paths = desktopBrowserAvailablePath;
    if (paths.isNotEmpty) {
      for (var path in paths) {
        if (io.File(path).existsSync()) {
          print("====== exist ====== $path");
          result = path;
          return result;
        }
      }
    }
    print("====== not exist ====== ");
    return result;
  }
}