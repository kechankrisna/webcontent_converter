import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
// import 'dart:js' as js;
// import 'package:js/js.dart';
// import 'package:js/js_util.dart';
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;
import 'package:web/web.dart' as web;
import 'dart:js_interop_unsafe';
// import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:ui_web' as ui;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter/widgets.dart';
import 'dart:js_interop';
import 'package:puppeteer/puppeteer.dart' as pp;
import '../../page.dart';

pp.Browser? windowBrower;
pp.Page? windowBrowserPage;

@anonymous
@JS('html2pdf')
external JSPromise<JSObject> html2pdf(web.Element element, JSAny? opt);

@anonymous
@JS('html2canvas')
external JSPromise<JSObject> html2canvas(web.Element element, JSAny? opt);

bool checkHtml2PdfInstallation() =>
    globalContext.has('html2pdf') && globalContext['html2pdf'] != null;

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
    Map<String, dynamic> args = const {},
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      String content = await rootBundle.loadString(path);

      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
        scale: scale,
        args: args,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:filePathToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  static Future<Uint8List> webUriToImage({
    required String uri,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
    Map<String, dynamic> args = const {},
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      var response = await Dio().get(uri);
      final String content = response.data.toString();
      result = await contentToImage(
        content: content,
        duration: duration,
        executablePath: executablePath,
        scale: scale,
        args: args,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  static Future<Uint8List> contentToImage({
    required String content,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
    Map<String, dynamic> args = const {},
  }) async {
    var div = web.document.createElement('div') as web.HTMLDivElement;
    // div.setInnerHtml(content, validator: AllowAll());
    div.innerHTML = content.toJS;
    // div.setAttribute('validator', 'AllowAll');
    div.style.color = 'black';
    div.style.background = 'white';
    web.document.body?.children.add(div);

    var opt = {
        "scale": scale,
        "allowTaint": true,
        "logging": true,
        "useCORS": true,
        "filename": "savedPath",
        "image": {"type": 'png', "quality": 0.98},
        "html2canvas": {"scale": 5},
      };

    logger.debug("[contentToImage]: opt: $opt");
    List<int> result = [];
    web.HTMLCanvasElement? canvas =
        (await html2canvas(div, opt.jsify()).toDart) as web.HTMLCanvasElement?;
    logger.debug("[contentToImage]: canvas: $canvas");

    if (canvas != null) {
      await Future.delayed(const Duration(seconds: 1));
      final base64Image = canvas.toDataUrl('image/png');
      final sub = base64Image.replaceAll("data:image/png;base64,", "");
      result = base64Decode(sub);
    }

    web.document.body?.children.delete(div);

    return Uint8List.fromList(result);
  }

  static Future<String?> filePathToPdf({
    required String path,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
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

  static Future<String?> webUriToPdf({
    required String uri,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
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
        args: args,
      );
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      throw Exception("Error: $e");
    }
    return result;
  }

  static Future<String?> contentToPDF({
    required String content,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    bool autoClosePage = true,
    Map<String, dynamic> args = const {},
  }) async {
    var div = web.document.createElement('div') as web.HTMLDivElement;
    // div.setInnerHtml(content, validator: AllowAll());
    div.innerHTML = content.toJS;
    // div.setAttribute('validator', 'AllowAll');
    div.style.color = 'black';
    div.style.background = 'white';
    web.document.body?.children.add(div);
    
    var opt = {
      "margin": 0,
      "filename": savedPath,
      "image": {"type": 'jpeg', "quality": 0.98},
      "html2canvas": {"scale": 5},
      "jsPDF": {
        "unit": 'in',
        "format": [format.width, format.height],
        "orientation": 'portrait',
        "dpi": "300",
        "useCORS": "true"
      },
      "pagebreak": {
        "mode": ['avoid-all', 'css', 'legacy']
      }
    };

    await (html2pdf(div, opt.jsify()).toDart);

    web.document.body?.children.delete(div);
    return null;
  }

  static Future<Uint8List?> contentToPDFImage({
    required String content,
    double duration = 2000,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    bool autoClosePage = true,
    Map<String, dynamic> args = const {},
  }) async {
    var div = web.document.createElement('div') as web.HTMLDivElement;
    // div.setInnerHtml(content, validator: AllowAll());
    div.innerHTML = content.toJS;
    // div.setAttribute('validator', 'AllowAll');
    div.style.color = 'black';
    div.style.background = 'white';
    web.document.body?.children.add(div);

    var opt = {
      "margin": 0,
      "image": {"type": 'jpeg', "quality": 0.98},
      "html2canvas": {"scale": 5},
      "jsPDF": {
        "unit": 'in',
        "format": [format.width, format.height],
        "orientation": 'portrait',
        "dpi": "300",
        "useCORS": "true"
      },
      "pagebreak": {
        "mode": ['avoid-all', 'css', 'legacy']
      }
    };

    List<int> result = [];
    // TODO: reehck html2canvas usage here
    web.HTMLCanvasElement? canvas =
        (await html2canvas(div, opt.jsify()).toDart) as web.HTMLCanvasElement?;
    if (canvas != null) {
      await Future.delayed(const Duration(seconds: 1));
      final base64Image = canvas.toDataUrl('image/png');
      final sub = base64Image.replaceAll("data:image/png;base64,", "");
      result = base64Decode(sub);
    }

    web.document.body?.children.delete(div);

    return Uint8List.fromList(result);
  }

  /// [embedWebView]
  static Widget embedWebView({
    String? url,
    String? content,
    double? width,
    double? height,
    Map<String, dynamic> args = const {},
  }) =>
      Builder(builder: (_) {
        final uniqueKey = Random.secure().nextInt(10000);
        final String viewType = 'webview-view-type-$uniqueKey';
        // Pass parameters to the platform side.
        final Map<String, dynamic> creationParams = <String, dynamic>{};
        final _width = width ?? 1;
        final _height = height ?? 1;
        creationParams['width'] = _width;
        creationParams['height'] = _height;
        creationParams['content'] = content;
        creationParams['url'] = url;
        logger.debug(
            "[embedWebView]: width: $_width, height: $_height, url: $url content length: ${content?.length}");

        final iframe = web.HTMLIFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..allowFullscreen = true;

        // Prefer inline content when available
        if (content != null && content.isNotEmpty) {
          iframe.srcdoc = content.toJS; // String expected; avoid toJS
          iframe.src = 'about:blank';
        } else {
          iframe.src = url ?? 'about:blank';
        }
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int _) => iframe,
        );

        return SafeArea(
          child: SizedBox(
            width: _width,
            height: height,
            child: HtmlElementView(viewType: viewType),
          ),
        );
      });

  static Future<bool> printPreview({
    String? url,
    String? content,
    bool autoClose = true,
    double? duration,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
  }) async {
    try {
      const windowFeatures =
          "left=100,top=100,width=800,height=800,popup=yes,_self";
      (globalContext['open'] as JSObject);
      JSObject printWindow = globalContext.callMethod(
          'open'.toJS, [url ?? '', "mozillaWindow", windowFeatures].toJSBox);
      JSObject? document = printWindow.has("document")
          ? printWindow['document'] as JSObject
          : null;
      // ref: https://developer.mozilla.org/en-US/docs/Web/API/Document

      JSObject? window =
          printWindow.has('window') ? printWindow['window'] as JSObject : null;
      // ref: https://developer.mozilla.org/en-US/docs/Web/API/Window

      if (content != null) {
        document?.callMethod('write'.toJS, [content].toJSBox);
      }
      window?.callMethod('print'.toJS);

      /// if (delay == null) {
      ///   window?.callMethod('print');
      /// } else {
      ///   final milliseconds = delay.inMilliseconds;
      ///   window?.callMethod(
      ///       'setTimeout', ['fn() => { window.print(); }', milliseconds]);
      /// }

      if (autoClose) {
        window?.callMethod('close'.toJS);
      }

      return Future.value(true);
    } on Exception catch (e) {
      WebcontentConverter.logger.error("[method:printPreview]: $e");
      return Future.value(false);
    }
  }
}

/// validator
// class AllowAll implements web.NodeValidator {
//   @override
//   bool allowsAttribute(
//       web.Element element, String attributeName, String value) {
//     return true;
//   }

//   @override
//   bool allowsElement(web.Element element) {
//     return true;
//   }
// }
