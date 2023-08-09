import 'dart:async';
import 'dart:typed_data';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart';
import 'package:puppeteer/puppeteer.dart' as pp;
import '../../page.dart';

pp.Browser? windowBrower;
pp.Page? windowBrowserPage;

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

  static Future<void> ensureInitialized({
    String? executablePath,
    String? content,
  }) async {
    UnimplementedError('ensureInitialized');
  }

  static Future<void> initWebcontentConverter({
    String? executablePath,
    String? content,
  }) async {
    UnimplementedError('initWebcontentConverter');
  }

  static Future<void> deinitWebcontentConverter({
    bool isClosePage = true,
    bool isCloseBrower = true,
  }) async {
    UnimplementedError('deinitWebcontentConverter');
  }

  static Future<Uint8List> filePathToImage({
    required String path,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    UnimplementedError('filePathToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<Uint8List> webUriToImage({
    required String uri,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    UnimplementedError('webUriToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<Uint8List> contentToImage({
    required String content,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    UnimplementedError('contentToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<String?> filePathToPdf({
    required String path,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) async {
    UnimplementedError('filePathToPdf');
    return null;
  }

  static Future<String?> webUriToPdf({
    required String uri,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) async {
    UnimplementedError('webUriToPdf');
    return null;
  }

  static Future<String?> contentToPDF({
    required String content,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    UnimplementedError('contentToPDF');
    return null;
  }

  /// [WevView]
  static Widget embedWebView(
      {String? url, String? content, double? width, double? height}) {
    UnimplementedError('webivew');
    return Container();
  }

  static Future<bool> printPreview(
      {String? url, String? content, bool autoClose = true, double? duration}) {
    UnimplementedError('printPreview');
    return Future.value(false);
  }
}
