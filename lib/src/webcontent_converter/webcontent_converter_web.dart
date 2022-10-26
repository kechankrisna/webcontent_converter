import 'dart:async';
import 'dart:convert';
import 'dart:js';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart';
import 'package:js/js.dart';
import 'package:puppeteer/puppeteer.dart' as pp;
import '../../webview_widget.dart';
import '../../page.dart';

pp.Browser? windowBrower;
pp.Page? windowBrowserPage;

@JS('html2pdf')
external JsFunction html2pdf(html.Element src, Object opt);

@JS('html2pdf.Worker')
external JsFunction Worker;

/// @JS('Worker')
/// external JsObject Worker(Object option);

/// @JS('html2pdf.Worker')
/// @anonymous
/// class Worker {
///   final Object? src;
///   final Map? opt;

///   Worker({this.src, this.opt});

///   /// external factory Worker({bool responsive});
/// }

/// extension WorkerExt on html2pdf {
///   /// final Object src;
///   /// final Map opt;

///   /// Worker(this.src, this.opt);

/// }

@JS('JSON.stringify')
external stringify(Object ojb);

bool checkhtml2pdfInstallation() => context['html2pdf'] != null;

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

  static Future<void> ensureInitialized() async {
    if (!checkhtml2pdfInstallation()) {
      assert(
          checkhtml2pdfInstallation(),
          'html2pdf not added in web/index.html. '
          'Run «flutter pub run webcontent_converter:install_web» or add script manually');
    }
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
    double duration: 2000,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    UnimplementedError('filePathToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<Uint8List> webUriToImage({
    required String uri,
    double duration: 2000,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    UnimplementedError('webUriToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<Uint8List> contentToImage({
    required String content,
    double duration: 2000,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    UnimplementedError('contentToImage');
    return Future.value(Uint8List.fromList([]));
  }

  static Future<String?> filePathToPdf({
    required String path,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
  }) async {
    UnimplementedError('filePathToPdf');
    return null;
  }

  static Future<String?> webUriToPdf({
    required String uri,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
  }) async {
    UnimplementedError('webUriToPdf');
    return null;
  }

  static Future<String?> contentToPDF({
    required String content,
    double duration: 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format: PaperFormat.a4,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    var div = html.document.createElement('div') as html.DivElement;
    div.setInnerHtml(content, validator: AllowAll());
    html.document.body?.children.add(div);

    /// final worker = Worker(src:div,
    ///     opt: {'filename': 'hellworld.pdf'}); //div, {'filename': 'hellworld.pdf'}
    /// allowInteropCaptureThis(html2pdf);
    var result = html2pdf(div, {'filename': 'hellworld.pdf'});

    print(result.callMethod('opt', [
      {'filename': 'hellworld.pdf'}
    ]));
    html.document.body?.children.remove(div);
    return null;
  }

  /// [WevView]
  static Widget webivew(String content, {double? width, double? height}) =>
      WebViewWidget(
        content,
        width: width,
        height: height,
      );
}

/// validator
class AllowAll implements html.NodeValidator {
  @override
  bool allowsAttribute(
      html.Element element, String attributeName, String value) {
    return true;
  }

  @override
  bool allowsElement(html.Element element) {
    return true;
  }
}
