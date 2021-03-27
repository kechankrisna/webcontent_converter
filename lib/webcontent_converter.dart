import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'page.dart';
import 'package:puppeteer/puppeteer.dart' as pp;
export 'page.dart';

/// [WebcontentConverter] will convert html, html file, web uri, into raw bytes image or pdf file
class WebcontentConverter {
  static const MethodChannel _channel =
      const MethodChannel('webcontent_converter');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// [logger] allow to pretty text
  ///
  /// [Usage]: `WebcontentConverter.logger('Your log text', level: LevelMessages.info);`
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
   * Convert html content, file, uri to image
   * Methods: [filePathToImage], [webUriToImage], [contentToImage]
   */

  /// [filePathToImage]: this method read content from file vai path
  ///
  /// [Goal]: `var content = await rootBundle.loadString(path) `
  ///
  /// [Usage]: `filePathToImage(path:path)`
  static Future<Uint8List> filePathToImage({
    @required String path,
    double duration: 2000,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      String content = await rootBundle.loadString(path);

      if (content != null) {
        result = await contentToImage(content: content, duration: duration);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:filePathToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// [webUriToImage]: this method read content from uri by using dio
  ///
  /// [Goal]: `var content = (await Dio().get(uri)).data.toString()`
  ///
  /// [Usage]: `webUriToImage(uri:uri)`
  static Future<Uint8List> webUriToImage({
    @required String uri,
    double duration: 2000,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      var response = await Dio().get(uri);
      final String content = response.data.toString();
      result = await contentToImage(content: content, duration: duration);
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// [contentToImage]: this method use html content directly to convert html to List<Int> image
  ///
  /// [Goal]: `var content = "<html> <body> <b>hello world</b></body> </html>"`
  ///
  /// [Usage]: `contentToImage(content:content)`
  static Future<Uint8List> contentToImage({
    @required String content,
    double duration: 2000,
  }) async {
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration
    };
    Uint8List results = Uint8List.fromList([]);
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        WebcontentConverter.logger.info("Desktop support");
        var browser = await pp.puppeteer.launch();
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
        results = await _channel.invokeMethod('contentToImage', arguments);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:contentToImage]: $e");
      throw Exception("Error: $e");
    }
    return results;
  }

  /**
   * Convert html content, file, uri to pdf
   * Methods: [filePathToPdf], [webUriToPdf], [contentToPDF]
   */

  /// [filePathToPdf]: this method read content from file vai path
  ///
  /// [Goal]: `var content = await rootBundle.loadString(path) `
  ///
  /// [Usage]: `filePathToPdf(path:path)`
  static Future<String> filePathToPdf({
    @required String path,
    double duration: 2000,
    @required String savedPath,
    PdfMargins margins,
    PaperFormat format: PaperFormat.a4,
  }) async {
    var result;
    try {
      String content = await rootBundle.loadString(path);
      if (content != null) {
        result = await contentToPDF(
          content: content,
          duration: duration,
          savedPath: savedPath,
          margins: margins,
          format: format,
        );
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:filePathToPdf]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// [webUriToPdf]: this method read content from uri by using dio
  ///
  /// [Goal]: `var content = (await Dio().get(uri)).data.toString()`
  ///
  /// [Usage]: `webUriToPdf(uri:uri)`
  static Future<String> webUriToPdf({
    @required String uri,
    double duration: 2000,
    @required String savedPath,
    PdfMargins margins,
    PaperFormat format: PaperFormat.a4,
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
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  /// [contentToPDF]: this method use html content directly to convert html to pdf then return path
  ///
  /// [Goal]: `var content = "<html> <body> <b>hello world</b></body> </html>"`
  ///
  /// [Usage]: `contentToPDF(content:content)`
  static Future<String> contentToPDF({
    @required String content,
    double duration: 2000,
    @required String savedPath,
    PdfMargins margins,
    PaperFormat format: PaperFormat.a4,
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
        var browser = await pp.puppeteer.launch();
        var page = await browser.newPage();
        await page.setContent(content, wait: pp.Until.load);
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
}
