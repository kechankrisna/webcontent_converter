## 0.0.16

- feat: added Swift Package Manager support for iOS and macOS, alongside the existing CocoaPods support (both are required by Flutter's current plugin policy). Verified on the example app: `FlutterGeneratedPluginSwiftPackage` genuinely lists this plugin as a dependency, and the full integration test suite passes via both CocoaPods and SPM on iOS Simulator and macOS, including a real round-trip proving a never-migrated (CocoaPods-only) consumer still works unaffected.
- refactor: removed the unused Objective-C plugin registration shim (`WebcontentConverterPlugin.h`/`.m` — neither generated registrant referenced it) and renamed the Swift implementation class from `SwiftWebcontentConverterPlugin` to `WebcontentConverterPlugin`, updating `pluginClass` in `pubspec.yaml` to match. No behavior change.
- fix(example): removed a `flutter.config.enable-swift-package-manager: false` override in `example/pubspec.yaml` left over from before this plugin had SPM support, which was silently forcing every build back onto CocoaPods regardless of the global Flutter config.

## 0.0.15

- chore: verified support for Flutter 3.47.4/Dart 3.13.3. `pub get`, `flutter analyze` (0 issues), and the full unit + integration test suites pass on iOS Simulator and Android emulator; the example app also builds and boots cleanly in Chrome. `example/`'s iOS and macOS projects had their minimum deployment targets raised (iOS 13.0 → 15.0, macOS 10.15 → 12.0) by Flutter's own tooling migration, now required by current Flutter/Xcode toolchains.
- fix: `printPreview`'s web implementation no longer wraps its `try`-block return values in `Future.value(...)` inside an already-`async` function (flagged by a lint new to the 3.47.4 analyzer; no behavior change).
- fix(example): added the missing `flutter_lints` dev dependency so `example/analysis_options.yaml`'s lint include actually resolves (previously silently broken), then cleaned up the ~75 issues that enabling it surfaced: missing widget `key` parameters, `library_private_types_in_public_api` on every screen's `createState()`, an undeclared transitive `image` dependency, dead code from an always-false null-aware check, non-camelCase parameter names, and other style/lint fixes.
- fix(example): the integration test's `maximumContentSize` guard case asserted a `CONTENT_TOO_LARGE` exception on every platform, but Android/Windows are the only platforms that enforce that guard (macOS/iOS don't); the assertion is now platform-conditional, matching the group's own documented intent.

## 0.0.14

- feat(example): added short/long label PDF conversion sample screens, with `convert()`/`previewPDF()` now taking content file, format, and margins per call instead of alternating on a hardcoded counter.
- chore(android): upgraded the Gradle wrapper from 8.10.2 to 8.14 for both the plugin module and the example app.

## 0.0.13

- fix: Windows `contentToPDF`'s watchdog timeout now scales with the caller's `duration` (`max(20000ms, duration_ms + 30000ms)`) instead of a flat 20s, matching Android's own `requestTimeoutMs()` pattern. The flat timeout covered navigation + settle + font-wait + `PrintToPdf` combined regardless of content size, and reliably fired against a real 373MB/302-page document now that 0.0.12 raised the content-size cap to 1GB.

## 0.0.12

- feat: raised the default content-size guard on Windows and Android from 100MB to 1GB (`kMaxContentSizeBytes` / `MAX_CONTENT_SIZE_BYTES`), and added a new optional `maximumContentSize` parameter (in MB) to `contentToImage`, `contentToPDF`, `contentToPDFImage`, and `printPreview` (plus their `filePath*`/`webUri*` wrappers) to override it per call. macOS/iOS have no such guard and are unaffected.

## 0.0.11

- **BREAKING**: removed the `executablePath` and `ppWaits` parameters from every `WebcontentConverter` method (`contentToImage`, `contentToPDF`, `contentToPDFImage`, `printPreview`, `filePathToImage`, `webUriToImage`, `filePathToPdf`, `webUriToPdf`, `ensureInitialized`, `initWebcontentConverter`). Both were leftovers from the old Puppeteer-based implementation (a Chrome executable path and page-load wait conditions) and had no effect on any platform's current native WebView-based implementation. Callers passing either by name will need to remove them.

## 0.0.10+7

- feat: macOS now uses `flutter_inappwebview` `HeadlessInAppWebView` for PDF generation (no Chrome required)
- feat: Windows now tries `flutter_inappwebview` WebView2 for PDF generation, falls back to Puppeteer if WebView2 Runtime is not installed
- fix: null crash in Puppeteer `finally` blocks when `newPage()` threw an exception
- fix: Windows Puppeteer path now checks `isConnected` before reusing browser instance

## 0.0.10+6

- fix: web html content rendering issue by setting validator attribute to AllowAll

## 0.0.10+5

- fixed: load on windows for pp

## 0.0.10+4

- fixed: custom chromium args on windows

## 0.0.10+3

- fix: format.name = 'custom' on macos platform for pdf conversion

## 0.0.10+2

- fix: format.name = 'custom'

## 0.0.10+1
- fix download desktop script to support platform argument
- update chrome_helper to support platform argument in downloadChrome method
- support flutter 3.35

## 0.0.9+6

- fix download desktop script to support platform argument
- update chromium_helper to support platform argument in downloadChrome method

## 0.0.9+5
- fixed chrome path
- implement chrome builtin on windows/linux instead of chromium

## 0.0.9+4
- fix ios pdf content width issue with space
- increase content width to 300 DPI for high-quality print resolution
- remove zoom text for pdf convert in macos

## 0.0.9+3
* add method to convert content to pdf image bytes

## 0.0.9+2
* add #html2bitmap library to support android background
* add args allow more arguments in invoke methods

## 0.0.8+3

* customBrowserPath and chrome directory helper
* fixed cli

## 0.0.8+2

* add method justDownloadChrome, justExtractChrome, downloadChrome in bin/install_desktop

## 0.0.8+1

* add printPreview method for web, desktop and mobile
* add scale to convert content as image to make image screenshot clear

## 0.0.8

* puppeteer 2.17
* web initialize
* linux chrome path

## 0.0.7+2

* puppeteer 2.11
* inlucde browser path with initialize and deinitialize to close background browser
* flutter 3 integrate

## 0.0.7+1

* puppeteer 2.5

## 0.0.7

* null-safety merged

## 0.0.6+2

* fixed convert pdf on desktop (macos)

## 0.0.6+1

* fixed convert pdf on desktop (windows)

## 0.0.6

* add executablePath enable flexible for destkop deployment,

## 0.0.5

* add webview widget (allow to view webview in flutter app)

## 0.0.4

* add fromString to PaperFormat

## 0.0.3

* Hotfix IOS minimum version 11

## 0.0.2

* Hotfix IOS performance

## 0.0.1

* TODO: Describe initial release.
