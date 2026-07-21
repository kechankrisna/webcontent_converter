# webcontent_converter

This plugin was made for developer to convert any webcontent, web uri to image bitmap or pdf file. It uses each platform's native webview directly: `WebView` on Android, `WKWebView` on iOS/macOS, and `WebView2` on Windows. No bundled/downloaded Chrome or Puppeteer is required on any platform.

## Support :

- &check; Android Minimum SDK Version: 21
- &check; IOS minimum target Version: 11
- &check; Desktop: windows, macos

| Android | iOS | macOS | Windows |
| --- | --- | --- | --- |
| WebView | WKWebView | WKWebView | WebView2 |


## Methods

`CONVERT TO IMAGE`

- filePathToImage(String path, double duration) : path is asset path and duration is delay time. This function will return Uint8List Image

Example: 

```
var bytes = await WebcontentConverter.filePathToImage(path: "assets/receipt.html");
if (bytes.length > 0) _saveFile(bytes);
```

- webUriToImage(String uri, double duration) : uri is web uri(url) and duration is delay time. This function will return Uint8List Image

Example:

```
var bytes = await WebcontentConverter.webUriToImage(
uri: "http://127.0.0.1:5500/example/assets/receipt.html");
if (bytes.length > 0) _saveFile(bytes);
```

- contentToImage(String content, double duration) : content is html or web content and duration is delay time. This function will return Uint8List Image

Example:

```
final content = Demo.getReceiptContent();
var bytes = await WebcontentConverter.contentToImage(content: content);
if (bytes.length > 0) _saveFile(bytes);
```

`*** Purpose: The three above functions will help developer to get screenshot of html content as  Uint8List Image and push it to esc printer`

![Receipt screenshot](screenshots/receipt.jpeg?raw=true "Receipt")

`CONVERT TO PDF`

- filePathToPdf(String path, double duration, String savedPath, PdfMargins margins, PaperFormat format )

Example:

```
var dir = await getApplicationDocumentsDirectory();
var savedPath = join(dir.path, "sample.pdf");
var result = await WebcontentConverter.filePathToPdf(
    path: "assets/invoice.html",
    savedPath: savedPath,
    format: PaperFormat.a4,
    margins: PdfMargins.px(top: 35, bottom: 35, right: 35, left: 35),
);
```

- webUriToPdf(String uri, double duration, String savedPath, PdfMargins margins, PaperFormat format )

Example:

```
var dir = await getApplicationDocumentsDirectory();
var savedPath = join(dir.path, "sample.pdf");
var result = await WebcontentConverter.webUriToPdf(
    uri: "http://127.0.0.1:5500/example/assets/invoice.html",
    savedPath: savedPath,
    format: PaperFormat.a4,
    margins: PdfMargins.px(top: 35, bottom: 35, right: 35, left: 35),
);
```

- contentToPDF(String content, double duration, String savedPath, PdfMargins margins, PaperFormat format )

Example:

```
final content = Demo.getInvoiceContent();
var dir = await getApplicationDocumentsDirectory();
var savedPath = join(dir.path, "sample.pdf");
var result = await WebcontentConverter.contentToPDF(
    content: content,
    savedPath: savedPath,
    format: PaperFormat.a4,
    margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
);
```

`*** Purpose: The three above functions will help developer to get pdf printed file of html content as. It will return a savedPath when saved successful otherwise null`


### Desktop (Windows/macOS)

Windows and macOS work out of the box through `WebView2` and `WKWebView` respectively -- there's no Chrome/Chromium to download, bundle, or point the plugin at. Just call `ensureInitialized()` (or any convert method) directly:

```dart
await WebcontentConverter.ensureInitialized();
```

> Older versions of this plugin (pre-0.0.11) shipped a Puppeteer-based fallback for desktop that required downloading a Chrome binary via `flutter pub run webcontent_converter:install_desktop` and pointing `WebViewHelper.customBrowserPath` at it. That code path has no effect on the current native `WebView2`/`WKWebView` implementation and should no longer be used.

![Invoice screenshot](screenshots/invoice.pdf?raw=true "Invoice")