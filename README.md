# webcontent_converter

This plugin was made for developer to convert any webcontent, web uri to image bitmap or pdf file. It uses each platform's native webview directly: `WebView` on Android, `WKWebView` on iOS/macOS, and `WebView2` on Windows. On Web it renders through `html2canvas`/`html2pdf.js` in the browser instead (see [Web setup](#web) below). No bundled/downloaded Chrome or Puppeteer is required on any platform.

## Support

| Android | iOS | macOS | Windows | Web |
| --- | --- | --- | --- | --- |
| WebView | WKWebView | WKWebView | WebView2 | html2canvas / html2pdf.js |

- Android minimum SDK version: 21
- iOS minimum deployment target: 13.0
- macOS minimum deployment target: 10.15
- Windows: requires the WebView2 Runtime on the end-user's machine. It ships with modern Windows 10/11 via Edge, but isn't guaranteed on Windows Server or locked-down/LTSC images.
- Dart SDK `>=3.9.2 <4.0.0`, Flutter `>=3.0.0` (see `pubspec.yaml`)

## Installation

```yaml
dependencies:
  webcontent_converter: ^0.0.11
```

```
flutter pub get
```

## Platform setup

### Android

No manifest changes needed for `contentToImage`/`contentToPDF` (local HTML string content). If you use `webUriToImage`/`webUriToPdf` to fetch a remote URL, make sure your app declares network access in its **release** manifest (`android/app/src/main/AndroidManifest.xml`) -- it isn't added for you:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS / macOS

WKWebView's default App Transport Security policy blocks plain `http://` loads. If you pass an `http://` (not `https://`) URL to `webUriToImage`/`webUriToPdf`, add an ATS exception to your app's `Info.plist` (`ios/Runner/Info.plist`, `macos/Runner/Info.plist`) -- ideally scoped to your specific domain, or broadly for local development:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

If you distribute a sandboxed macOS app (e.g. via the Mac App Store), keep `com.apple.security.app-sandbox` enabled in your entitlements and make sure `com.apple.security.network.client` is `true` -- WKWebView needs it to reach remote URLs from inside the sandbox.

### Windows

No extra project setup, but see the WebView2 Runtime requirement noted under [Support](#support) above -- it's expected to already be present on the machine running your app.

### Web

Run this once after adding the dependency:

```
flutter pub run webcontent_converter:install_web
```

This injects the `html2canvas`/`html2pdf.js`/`jspdf` script tags this platform's implementation depends on into `web/index.html`. Without it, `ensureInitialized()` fails its debug-mode assertion, and `contentToImage`/`contentToPDF` fail outright since those scripts won't be defined.

## Methods

### Convert to image

```dart
static Future<Uint8List> contentToImage({
  required String content,
  double duration = 2000,
  int scale = 3,
  Map<String, dynamic> args = const {},
  bool enableLogger = true,
})
```

`filePathToImage({required String path, ...})` and `webUriToImage({required String uri, ...})` take the same `duration`/`scale`/`args`/`enableLogger` parameters, read their HTML from an asset path or a remote URL respectively, then call `contentToImage` under the hood.

- `duration` -- milliseconds to wait for the page to finish loading/rendering before capturing.
- `scale` -- capture scale factor (mobile/web paths).

Basic example:

```dart
final content = Demo.getReceiptContent();
final bytes = await WebcontentConverter.contentToImage(content: content);
if (bytes.isNotEmpty) _saveFile(bytes);
```

![Receipt screenshot](screenshots/receipt.jpeg?raw=true "Receipt")

`contentToImage` also accepts a `format` (and optional `margins`) through `args`, which routes it through each platform's PDF-page rasterizer instead of a plain screenshot -- useful for producing a paginated, print-accurate bitmap (e.g. for a receipt/invoice at a specific paper size) rather than a screenshot sized to the page's natural content:

```dart
final bytes = await WebcontentConverter.contentToImage(
  content: Demo.getInvoiceContent(),
  args: {
    'format': {
      'width': PaperFormat.letter.width,
      'height': PaperFormat.letter.height,
      'name': PaperFormat.letter.name,
    },
    'margins': {'top': 0.25, 'bottom': 0.25, 'left': 0.25, 'right': 0.25},
  },
);
```

Note: each platform rasterizes this path through a different native renderer, so the exact output pixel size per page isn't identical across Android/iOS/macOS/Windows (see `example/integration_test/webcontent_converter_test.dart` for the verified per-platform pixel formulas if you need to reason about exact dimensions).

`*** Purpose: get a screenshot of html content as a `Uint8List` PNG/JPEG, e.g. to push to an ESC/POS receipt printer.`

### Convert to PDF

```dart
static Future<String?> contentToPDF({
  required String content,
  double duration = 2000,
  required String savedPath,
  PdfMargins? margins,
  PaperFormat format = PaperFormat.a4,
  Map<String, dynamic> args = const {},
  bool enableLogger = true,
})
```

`filePathToPdf`/`webUriToPdf` mirror this with `path`/`uri` in place of `content`. All three write the PDF to `savedPath` and return that path on success (`null` on failure).

```dart
final content = Demo.getInvoiceContent();
final dir = await getApplicationDocumentsDirectory();
final savedPath = join(dir.path, "sample.pdf");
final result = await WebcontentConverter.contentToPDF(
  content: content,
  savedPath: savedPath,
  format: PaperFormat.a4,
  margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
);
```

`contentToPDFImage({required String content, double duration = 2000, PdfMargins? margins, PaperFormat format = PaperFormat.a4, Map<String, dynamic> args = const {}, bool enableLogger = true})` returns `Future<Uint8List?>` -- the same PDF generation as `contentToPDF`, but returned as raw bytes (via a temp file under the hood) instead of a saved path, for when you want the PDF in memory:

```dart
final bytes = await WebcontentConverter.contentToPDFImage(
  content: Demo.getInvoiceContent(),
  format: PaperFormat.a4,
);
```

`*** Purpose: produce a real, paginated PDF file (or its bytes) of html content, e.g. for an invoice.`

[Sample invoice PDF](screenshots/invoice.pdf?raw=true)

### Print preview

```dart
static Future<bool> printPreview({
  String? url,
  String? content,
  bool autoClose = true,
  double? duration,
  PdfMargins? margins,
  PaperFormat format = PaperFormat.a4,
  Map<String, dynamic> args = const {},
})
```

Opens the platform's native print UI: a `WebView2`/`WKWebView`-backed preview window on Windows/macOS, the OS print sheet on Android/iOS, and a `window.print()` popup on Web.

### Utilities

- `isWebviewAvailable()` -- `Future<bool>`, whether this platform's native webview (WebView2/WKWebView/`android.webkit.WebView`) is actually usable right now. Always `true` on Web.
- `embedWebView({String? url, String? content, double? width, double? height, Map<String, dynamic> args})` -- a `Widget` that embeds the content/url directly in your widget tree.
- `ensureInitialized({String? content})` -- warms up the native webview once (skips if already done); call it early (e.g. at app start) to avoid a cold-start delay on the first real conversion.

## PaperFormat & PdfMargins

`PaperFormat` (`lib/page.dart`) has named presets in inches -- `.a0`-`.a6`, `.letter`, `.legal`, `.tabloid`, `.ledger` -- plus `PaperFormat.px(width:, height:)`, `.cm(...)`, `.mm(...)`, and `.inches(...)` constructors if you need a custom size.

`PdfMargins` mirrors this: `PdfMargins.zero`, or `PdfMargins.px(top:, bottom:, left:, right:)` / `.cm(...)` / `.mm(...)` / `.inches(...)`.

## Desktop (Windows/macOS)

Windows and macOS work through `WebView2`/`WKWebView` -- there's no Chrome/Chromium to download or bundle. Just call `ensureInitialized()` (or any convert method) directly:

```dart
await WebcontentConverter.ensureInitialized();
```

> Older versions of this plugin (pre-0.0.11) shipped a Puppeteer-based fallback for desktop that required downloading a Chrome binary via `flutter pub run webcontent_converter:install_desktop` and pointing `WebViewHelper.customBrowserPath` at it. That code path has no effect on the current native `WebView2`/`WKWebView` implementation and should no longer be used.
