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
