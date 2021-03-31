# webcontent_converter

This plugin was made for developer to convert any webcontent, web uri to image bitmap or pdf file. This plugin use WebView on android, WKWebView on Ios and chromium for desktop support. This plugin was test for android, ios and desktop. 

## Support :

- &check; Android Minimum SDK Version: 21
- &check; IOS minimum target Version: 11
- &check; Deskop linux, windows, macos

| Android | IOS | Desktop|
| --- | --- | --- |
|  WebView | WkWebView | Puppeteer |


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

![Invoice screenshot](screenshots/invoice.pdf?raw=true "Invoice")