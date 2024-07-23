import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:puppeteer/puppeteer.dart' as pp;

import '../../page.dart';

pp.Browser? windowBrower;
pp.Page? windowBrowserPage;

@anonymous
@JS('html2pdf')
external js.JsFunction html2pdf(html.Element element, opt);

@anonymous
@JS('html2canvas')
external js.JsFunction html2canvas(html.Element element, opt);

bool checkHtml2PdfInstallation() => js.context['html2pdf'] != null;

/// [WebcontentConverter] will convert html, html file, web uri, into raw bytes image or pdf file
class WebcontentConverter {
  static const MethodChannel _channel = MethodChannel('webcontent_converter');

  static Future<String?> get platformVersion async {
    final version = await _channel.invokeMethod('getPlatformVersion');
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
      LevelMessages.warning,
    ],
  );

  static Future<void> ensureInitialized({
    String? executablePath,
    String? content,
  }) async {
    if (!checkHtml2PdfInstallation()) {
      assert(
          checkHtml2PdfInstallation(),
          'html2pdf not added in web/index.html. '
          'Run «flutter pub run webcontent_converter:install_web» or add script manually');
    }
  }

  static Future<void> initWebcontentConverter({
    String? executablePath,
    String? content,
  }) async {
    if (!checkHtml2PdfInstallation()) {
      assert(
          checkHtml2PdfInstallation(),
          'html2pdf not added in web/index.html. '
          'Run «flutter pub run webcontent_converter:install_web» or add script manually');
    }
  }

  static Future<void> deinitWebcontentConverter({
    bool isClosePage = true,
    bool isCloseBrower = true,
  }) async {
    ///
  }

  static Future<Uint8List> filePathToImage({
    required String path,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    var result = Uint8List.fromList([]);
    try {
      final content = await rootBundle.loadString(path);

      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
        scale: scale,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:filePathToImage]: $e');
      throw Exception('Error: $e');
    }
    return result;
  }

  static Future<Uint8List> webUriToImage({
    required String uri,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    var result = Uint8List.fromList([]);
    try {
      final response = await Dio().get(uri);
      final content = response.data.toString();
      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
        scale: scale,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:webUriToImage]: $e');
      throw Exception('Error: $e');
    }
    return result;
  }

  static Future<Uint8List> contentToImage({
    required String content,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    final div = html.document.createElement('div') as html.DivElement;
    div.setInnerHtml(content, validator: AllowAll());
    div.style.color = 'black';
    div.style.background = 'white';
    html.document.body?.children.add(div);

    final opt = {'scale': scale, 'useCORS': true};

    var result = <int>[];
    final canvas = await promiseToFuture(html2canvas(div, jsify(opt)));
    if (canvas != null && canvas is html.CanvasElement) {
      await Future.delayed(const Duration(seconds: 1));
      final base64Image = canvas.toDataUrl();
      final sub = base64Image.replaceAll('data:image/png;base64,', '');
      result = base64Decode(sub);
    }

    html.document.body?.children.remove(div);

    return Uint8List.fromList(result);
  }

  static Future<String?> filePathToPdf({
    required String path,
    required String savedPath,
    required PaperFormat format,
    double duration = 2000,
    PdfMargins? margins,
    String? executablePath,
  }) async {
    String? result;
    try {
      final content = await rootBundle.loadString(path);
      result = await contentToPDF(
        content: content,
        duration: duration,
        savedPath: savedPath,
        margins: margins,
        format: format,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:filePathToPdf]: $e');
      throw Exception('Error: $e');
    }
    return result;
  }

  static Future<String?> webUriToPdf({
    required String uri,
    required String savedPath,
    required PaperFormat format,
    double duration = 2000,
    PdfMargins? margins,
    String? executablePath,
  }) async {
    String? result;
    try {
      final response = await Dio().get(uri);
      final content = response.data.toString();
      result = await contentToPDF(
        content: content,
        duration: duration,
        savedPath: savedPath,
        margins: margins,
        format: format,
        executablePath: executablePath,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:webUriToImage]: $e');
      throw Exception('Error: $e');
    }
    return result;
  }

  static Future<String?> contentToPDF({
    required String content,
    required String savedPath,
    required PaperFormat format,
    double duration = 2000,
    PdfMargins? margins,
    String? executablePath,
    bool autoClosePage = true,
  }) async {
    final div = html.document.createElement('div') as html.DivElement;
    div.setInnerHtml(content, validator: AllowAll());
    div.style.color = 'black';
    div.style.background = 'white';
    html.document.body?.children.add(div);

    final opt = {
      'margin': 0,
      'filename': savedPath,
      'image': {'type': 'jpeg', 'quality': 0.98},
      'html2canvas': {'scale': 5},
      'jsPDF': {'unit': 'in', 'format': 'a4', 'orientation': 'portrait'},
      'pagebreak': {
        'mode': ['avoid-all', 'css', 'legacy'],
      },
    };

    await promiseToFuture(html2pdf(div, jsify(opt)));

    html.document.body?.children.remove(div);
    return null;
  }

  /// [embedWebView]
  static Widget embedWebView({
    String? url,
    String? content,
    double? width,
    double? height,
  }) =>
      Builder(
        builder: (_) {
          final uniqueKey = Random.secure().nextInt(10000);
          final viewType = 'webview-view-type-$uniqueKey';
          // Pass parameters to the platform side.
          final creationParams = <String, dynamic>{};
          final width0 = width ?? 1;
          final height0 = height ?? 1;
          creationParams['width'] = width0;
          creationParams['height'] = height0;
          creationParams['content'] = content;
          creationParams['url'] = url;

          // ignore: undefined_prefixed_name
          ui.platformViewRegistry.registerViewFactory(
            viewType,
            (_) => html.IFrameElement()
              ..src = url
              ..srcdoc = content
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.border = 'none'
              ..allowFullscreen = true,
          );

          return SafeArea(
            child: SizedBox(
              width: width0,
              height: height,
              child: HtmlElementView(viewType: viewType),
            ),
          );
        },
      );

  static Future<bool> printPreview({
    String? url,
    String? content,
    bool autoClose = true,
    double? duration,
  }) async {
    try {
      const windowFeatures =
          'left=100,top=100,width=800,height=800,popup=yes,_self';
      final js.JsObject printWindow = js.context
          .callMethod('open', [url ?? '', 'mozillaWindow', windowFeatures]);
      final js.JsObject? document =
          printWindow.hasProperty('document') ? printWindow['document'] : null;
      // ref: https://developer.mozilla.org/en-US/docs/Web/API/Document

      final js.JsObject? window =
          printWindow.hasProperty('window') ? printWindow['window'] : null;
      // ref: https://developer.mozilla.org/en-US/docs/Web/API/Window

      if (content != null) {
        document?.callMethod('write', [content]);
      }
      window?.callMethod('print');

      /// if (delay == null) {
      ///   window?.callMethod('print');
      /// } else {
      ///   final milliseconds = delay.inMilliseconds;
      ///   window?.callMethod(
      ///       'setTimeout', ['fn() => { window.print(); }', milliseconds]);
      /// }

      if (autoClose) {
        window?.callMethod('close');
      }

      return Future.value(true);
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:printPreview]: $e');
      return Future.value(false);
    }
  }
}

/// validator
class AllowAll implements html.NodeValidator {
  @override
  bool allowsAttribute(
    html.Element element,
    String attributeName,
    String value,
  ) =>
      true;

  @override
  bool allowsElement(html.Element element) => true;
}
