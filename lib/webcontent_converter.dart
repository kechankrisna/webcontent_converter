import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:webcontent_converter/webview_widget.dart';
import 'page.dart';
import 'package:puppeteer/puppeteer.dart' as pp;
export 'page.dart';
export 'webview_widget.dart';

/// [WebcontentConverter] will convert html, html file, web uri, into raw bytes image or pdf file
class WebcontentConverter {
  static const MethodChannel _channel =
      const MethodChannel('webcontent_converter');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// ## `WebcontentConverter.logger`
  /// `allow to pretty text`
  /// #### Example:
  /// ```
  /// WebcontentConverter.logger('Your log text', level: LevelMessages.info);
  /// ```
  static final logger = EasyLogger(
    name: 'webcontent_converter',
    defaultLevel: LevelMessages.debug,
    enableBuildModes: [BuildMode.debug, BuildMode.profile, BuildMode.release],
    enableLevels: [
      LevelMessages.debug,
      LevelMessages.info,
      LevelMessages.error,
      LevelMessages.warning
    ],
  );

  /**
   * `IMAGE`
   * Convert html content, file, uri to image
   * Methods: [filePathToImage], [webUriToImage], [contentToImage]
   */

  /// ## `WebcontentConverter.filePathToImage`
  /// `this method read content from file vai path then call contentToImage`
  /// #### Example:
  /// ```
  ///  var bytes = await WebcontentConverter.filePathToImage(path: "assets/receipt.html");
  /// if (bytes.length > 0){
  ///   var dir = await getTemporaryDirectory();
  ///   var path = join(dir.path, "receipt.jpg");
  ///   File file = File(path);
  ///   await file.writeAsBytes(bytes);
  /// }
  /// ```
  static Future<Uint8List> filePathToImage({
    required String path,
    double duration: 2000,
    String? executablePath,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      String content = await rootBundle.loadString(path);

      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:filePathToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// ## `WebcontentConverter.webUriToImage`
  /// `This method read content from uri by using dio then call contentToImage`
  /// #### Example:
  /// ```
  /// var bytes = await WebcontentConverter.webUriToImage(uri: "http://127.0.0.1:5500/example/assets/receipt.html");
  /// if (bytes.length > 0){
  ///   var dir = await getTemporaryDirectory();
  ///   var path = join(dir.path, "receipt.jpg");
  ///   File file = File(path);
  ///   await file.writeAsBytes(bytes);
  /// }
  /// ```
  static Future<Uint8List> webUriToImage({
    required String uri,
    double duration: 2000,
    String? executablePath,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      var response = await Dio().get(uri);
      final String content = response.data.toString();
      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// ## `WebcontentConverter.contentToImage`
  /// `This method use html content directly to convert html to List<Int> image`
  /// ### Example:
  /// ```
  /// final content = Demo.getReceiptContent();
  /// var bytes = await WebcontentConverter.contentToImage(content: content);
  /// if (bytes.length > 0){
  ///   var dir = await getTemporaryDirectory();
  ///   var path = join(dir.path, "receipt.jpg");
  ///   File file = File(path);
  ///   await file.writeAsBytes(bytes);
  /// }
  /// ```
  static Future contentToImage({
    required String content,
    double duration: 2000,
    String? executablePath,
  }) async {
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration
    };
    Uint8List? results = Uint8List.fromList([]);
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        WebcontentConverter.logger.info("Desktop support");
        var browser = await pp.puppeteer.launch(executablePath: executablePath);
        var page = await browser.newPage();
        await page.setContent(content, wait: pp.Until.load);
        await page.emulateMediaType(pp.MediaType.print);
        var offsetHeight = await page.evaluate('document.body.offsetHeight');
        var offsetWidth = await page.evaluate('document.body.offsetWidth');
        results = await page.screenshot(
          format: pp.ScreenshotFormat.png,
          clip: pp.Rectangle.fromPoints(
              pp.Point(0, 0), pp.Point(offsetWidth, offsetHeight)),
          fullPage: false,
          omitBackground: true,
        );
        await page.close();
      } else {
        WebcontentConverter.logger.info("Mobile support");
        results = await (_channel.invokeMethod('contentToImage', arguments));
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:contentToImage]: $e");
      throw Exception("Error: $e");
    }
    return results;
  }

  /**
   * `PDF`
   * Convert html content, file, uri to pdf
   * Methods: [filePathToPdf], [webUriToPdf], [contentToPDF]
   */

  /// ## `WebcontentConverter.filePathToPdf`
  /// `This method read content from file vai path`
  /// #### Example:
  /// ```
  /// var dir = await getApplicationDocumentsDirectory();
  /// var savedPath = join(dir.path, "sample.pdf");
  /// var result = await WebcontentConverter.filePathToPdf(
  ///   path: "assets/invoice.html",
  ///   savedPath: savedPath,
  ///   format: PaperFormat.a4,
  ///   margins: PdfMargins.px(top: 35, bottom: 35, right: 35, left: 35),
  /// );
  ///```

  static Future<String?> filePathToPdf({
    required String path,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
  }) async {
    var result;
    try {
      String content = await rootBundle.loadString(path);
      result = await contentToPDF(
        content: content,
        duration: duration,
        savedPath: savedPath,
        margins: margins,
        format: format,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:filePathToPdf]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// ## WebcontentConverter.webUriToPdf
  /// `This method read content from uri by using dio`
  /// #### Example:
  /// ```
  /// var dir = await getApplicationDocumentsDirectory();
  /// var savedPath = join(dir.path, "sample.pdf");
  /// var result = await WebcontentConverter.webUriToPdf(
  ///     uri: "http://127.0.0.1:5500/example/assets/invoice.html",
  ///     savedPath: savedPat,
  /// );
  /// ```
  static Future<String?> webUriToPdf({
    required String uri,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
  }) async {
    var result;
    try {
      var response = await Dio().get(uri);
      final String content = response.data.toString();
      result = await contentToPDF(
        content: content,
        duration: duration,
        savedPath: savedPath,
        margins: margins,
        format: format,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// ## `WebcontentConverter.contentToPDF`
  /// `This method use html content directly to convert html to pdf then return path`
  /// #### Example:
  /// ```
  /// final content = Demo.getInvoiceContent();
  /// var dir = await getApplicationDocumentsDirectory();
  /// var savedPath = join(dir.path, "sample.pdf");
  /// var result = await WebcontentConverter.contentToPDF(
  ///     content: content,
  ///     savedPath: savedPath,
  ///     format: PaperFormat.a4,
  ///     margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
  /// );
  /// ```
  static Future<String?> contentToPDF({
    required String content,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
  }) async {
    PdfMargins _margins = margins ?? PdfMargins.zero;
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration,
      'savedPath': savedPath,
      'margins': _margins.toMap(),
      'format': format.toMap(),
    };
    WebcontentConverter.logger.info(arguments['savedPath']);
    WebcontentConverter.logger.info(arguments['margins']);
    WebcontentConverter.logger.info(arguments['format']);
    var result;
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        WebcontentConverter.logger.info("Desktop support");
        var browser = await pp.puppeteer.launch(executablePath: executablePath);
        var page = await browser.newPage();
        await page.setContent(content,
            wait: pp.Until.all([
              pp.Until.load,
              pp.Until.domContentLoaded,
              pp.Until.networkAlmostIdle,
              pp.Until.networkIdle,
            ]));
        await page.pdf(
          format: pp.PaperFormat.inches(
            width: format.width,
            height: format.height,
          ),
          margins: pp.PdfMargins.inches(
            top: _margins.top,
            bottom: _margins.bottom,
            left: _margins.left,
            right: _margins.right,
          ),
          printBackground: true,
          output: File(savedPath).openWrite(),
        );
        await page.close();
        result = savedPath;
      } else {
        WebcontentConverter.logger.info("Mobile support");
        result = await _channel.invokeMethod('contentToPDF', arguments);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:contentToPDF]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// [WevView]
  static Widget webivew(String content, {double? width, double? height}) =>
      WebViewWidget(
        content,
        width: width,
        height: height,
      );
}
