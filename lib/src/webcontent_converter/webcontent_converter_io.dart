import 'dart:async';
import 'dart:io' as io;
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;

import '../../demo.dart';
import '../../page.dart';

/// instance of window browser
Uint8List preloadBytes = Uint8List.fromList([]);

/// [WebcontentConverter] will convert html, html file, web uri, into raw bytes image or pdf file
class WebcontentConverter {
  static const MethodChannel _channel =
      const MethodChannel('webcontent_converter');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<void> ensureInitialized({
    String? executablePath,
    String? content,
  }) async {
    if (preloadBytes.isEmpty) {
      await WebcontentConverter.initWebcontentConverter(
          executablePath: executablePath, content: content);
    }
  }

  static Future<void> initWebcontentConverter({
    String? executablePath,
    String? content,
  }) async {
    preloadBytes =
          await contentToImage(content: content ?? Demo.getReceiptContent());

    WebcontentConverter.logger.debug('webcontent converter initialized');
  }

  static Future<void> deinitWebcontentConverter({
    bool isClosePage = true,
    bool isCloseBrower = true,
  }) async {
    WebcontentConverter.logger
        .debug('webcontent converter deinitWebcontentConverter');
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
    printer: (Object object, {String? name, LevelMessages? level, StackTrace? stackTrace}) =>
        easyLogDefaultPrinter('[${DateTime.now()}] $object',
            name: name, level: level, stackTrace: stackTrace),
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
    double duration = 2000,
    String? executablePath,
    int scale = 3,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
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
        ppWaits: ppWaits,
        enableLogger: enableLogger,
      );
    } on Exception catch (e) {
      if (enableLogger) {
        WebcontentConverter.logger.error("[method:filePathToImage]: $e");
      }
      rethrow;
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
    double duration = 2000,
    String? executablePath,
    int scale = 3,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
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
        ppWaits: ppWaits,
        enableLogger: enableLogger,
      );
    } on Exception catch (e) {
      if (enableLogger) {
        WebcontentConverter.logger.error("[method:webUriToImage]: $e");
      }
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

  static Future<Uint8List> contentToImage({
    required String content,
    double duration = 2000,
    String? executablePath,
    int scale = 3,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
  }) async {
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration,
      'scale': scale,
    };

    ///
    if (args.isNotEmpty) {
      arguments.addAll(args);
    }
    Uint8List results = Uint8List.fromList([]);
    final stopwatch = Stopwatch()..start();

    if (enableLogger) {
      WebcontentConverter.logger.info(
          "[contentToImage] starting: content=${content.length} chars, duration=${duration}ms, scale=$scale, args=$args");
    }

    try {
      /// native method
      if (enableLogger) {
        WebcontentConverter.logger
            .info("[contentToImage] invoking native platform channel");
      }
      results = await (_channel.invokeMethod('contentToImage', arguments));
      if (enableLogger) {
        WebcontentConverter.logger.info(
            "[contentToImage] completed: ${results.length} bytes in ${stopwatch.elapsedMilliseconds}ms");
      }
    } on Exception catch (e, stackTrace) {
      if (enableLogger) {
        WebcontentConverter.logger.error(
            "[contentToImage] failed after ${stopwatch.elapsedMilliseconds}ms: $e");
        WebcontentConverter.logger.error("$stackTrace");
      }
      rethrow;
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
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
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
        args: args,
        ppWaits: ppWaits,
        enableLogger: enableLogger,
      );
    } on Exception catch (e, stackTrace) {
      if (enableLogger) {
        WebcontentConverter.logger.error("[method:filePathToPdf]: $e");
        WebcontentConverter.logger.error("$stackTrace");
      }
      rethrow;
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
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
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
        ppWaits: ppWaits,
        enableLogger: enableLogger,
      );
    } on Exception catch (e, stackTrace) {
      if (enableLogger) {
        WebcontentConverter.logger.error("[method:webUriToImage]: $e");
        WebcontentConverter.logger.error("$stackTrace");
      }
      rethrow;
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
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
  }) async {
    PdfMargins _margins = margins ?? PdfMargins.zero;
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration,
      'savedPath': savedPath,
      'margins': _margins.toMap(),
      'format': format.toMap(),
    };

    ///
    if (args.isNotEmpty) {
      arguments.addAll(args);
    }
    final stopwatch = Stopwatch()..start();
    if (enableLogger) {
      WebcontentConverter.logger.info(
          "[contentToPDF] starting: content=${content.length} chars, savedPath=${arguments['savedPath']}, margins=${arguments['margins']}, format=${arguments['format']}");
    }
    String? result;
    try {
      if (enableLogger) {
        WebcontentConverter.logger
            .info("[contentToPDF] invoking native platform channel");
      }
      result = await _channel.invokeMethod('contentToPDF', arguments);
      if (enableLogger) {
        WebcontentConverter.logger.info(
            "[contentToPDF] completed: $result in ${stopwatch.elapsedMilliseconds}ms");
      }
    } on Exception catch (e, stackTrace) {
      if (enableLogger) {
        WebcontentConverter.logger.error(
            "[contentToPDF] failed after ${stopwatch.elapsedMilliseconds}ms: $e");
        WebcontentConverter.logger.error("$stackTrace");
      }
      rethrow;
    }

    return result;
  }

  /// ## `WebcontentConverter.contentToPDFImage`
  /// `This method use html content directly to convert html to pdf then return path`
  /// #### Example:
  /// ```
  /// final content = Demo.getInvoiceContent();
  /// var dir = await getApplicationDocumentsDirectory();
  /// var savedPath = join(dir.path, "sample.pdf");
  /// var result = await WebcontentConverter.contentToPDFImage(
  ///     content: content,
  ///     savedPath: savedPath,
  ///     format: PaperFormat.a4,
  ///     margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
  /// );
  /// ```
  static Future<Uint8List?> contentToPDFImage({
    required String content,
    double duration = 2000,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
    bool enableLogger = true,
  }) async {
    PdfMargins _margins = margins ?? PdfMargins.zero;
    final Map<String, dynamic> arguments = {
      'content': content,
      'duration': duration,
      'margins': _margins.toMap(),
      'format': format.toMap(),
    };

    ///
    if (args.isNotEmpty) {
      arguments.addAll(args);
    }
    final stopwatch = Stopwatch()..start();
    if (enableLogger) {
      WebcontentConverter.logger.info(
          "[contentToPDFImage] starting: content=${content.length} chars, margins=${arguments['margins']}, format=${arguments['format']}");
    }
    Uint8List? result;
    try {
      if (io.Platform.isWindows || io.Platform.isMacOS) {
        // Uses this package's own native contentToPDF (WebView2 PrintToPdf)
        // rather than flutter_inappwebview's separate HeadlessInAppWebView
        // wrapper (a second, independent WebView2 integration) or the
        // Puppeteer fallback that used to sit behind it: contentToPDF's
        // native Windows implementation is the one hardened this package's
        // persistent-session, retry, and request-queueing work targets, so
        // routing through it here instead is both simpler and more
        // reliable. It only writes to a path, so this generates to a temp
        // file and reads it back as bytes.
        if (enableLogger) {
          WebcontentConverter.logger
              .info("[contentToPDFImage] Windows: using native contentToPDF");
        }
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path,
            "webcontent_converter_${DateTime.now().microsecondsSinceEpoch}.pdf");
        try {
          final savedPath = await contentToPDF(
            content: content,
            duration: duration,
            savedPath: tempPath,
            margins: _margins,
            format: format,
            executablePath: executablePath,
            args: args,
            ppWaits: ppWaits,
            enableLogger: enableLogger,
          );
          if (savedPath != null) {
            result = await io.File(savedPath).readAsBytes();
          }
        } finally {
          final tempFile = io.File(tempPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } else {
        if (enableLogger) {
          WebcontentConverter.logger
              .info("[contentToPDFImage] Mobile: using platform channel");
        }
        result = await _channel.invokeMethod('contentToPDFImage', arguments);
      }
      if (enableLogger) {
        WebcontentConverter.logger.info(
            "[contentToPDFImage] completed: ${result?.length ?? 0} bytes in ${stopwatch.elapsedMilliseconds}ms");
      }
    } on Exception catch (e, stackTrace) {
      if (enableLogger) {
        WebcontentConverter.logger.error(
            "[contentToPDFImage] failed after ${stopwatch.elapsedMilliseconds}ms: $e");
        WebcontentConverter.logger.error("$stackTrace");
      }
      rethrow;
    }

    return result;
  }

  /// [WevView]
  static Widget embedWebView({
    String? url,
    String? content,
    double? width,
    double? height,
    Map<String, dynamic> args = const {},
  }) {
    return Builder(builder: (context) {
      final String viewType = 'webview-view-type';
      // Pass parameters to the platform side.
      final Map<String, dynamic> creationParams = <String, dynamic>{};
      final _width = width ?? 1;
      final _height = height ?? 1;
      creationParams['width'] = _width;
      creationParams['height'] = _height;
      creationParams['content'] = content;
      creationParams['url'] = url;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return SafeArea(
            child: SizedBox(
              width: _width,
              height: height,
              child: PlatformViewLink(
                viewType: viewType,
                surfaceFactory:
                    (BuildContext context, PlatformViewController controller) {
                  return AndroidViewSurface(
                    controller: controller as AndroidViewController,
                    gestureRecognizers: const <Factory<
                        OneSequenceGestureRecognizer>>{},
                    hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  );
                },
                onCreatePlatformView: (PlatformViewCreationParams params) {
                  return PlatformViewsService.initSurfaceAndroidView(
                    id: params.id,
                    viewType: viewType,
                    layoutDirection: TextDirection.ltr,
                    creationParams: creationParams,
                    creationParamsCodec: StandardMessageCodec(),
                  )
                    ..addOnPlatformViewCreatedListener(
                        params.onPlatformViewCreated)
                    ..create();
                },
              ),
            ),
          );
        case TargetPlatform.iOS:
          return SafeArea(
            child: SizedBox(
              width: _width,
              height: _width,
              child: UiKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          );
        case TargetPlatform.macOS:
          return SafeArea(
            child: SizedBox(
              width: _width,
              height: _width,
              child: AppKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                creationParamsCodec: const StandardMessageCodec(),
                hitTestBehavior: PlatformViewHitTestBehavior
                    .opaque, // ✅ Important for gestures
              ),
            ),
          );
        default:
          throw UnsupportedError("Unsupported platform view");
      }
    });
  }

  static Future<bool> printPreview({
    String? url,
    String? content,
    bool autoClose = true,
    double? duration,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
    Map<String, dynamic> args = const {},
    List<String> ppWaits = const ["load", "domContentLoaded"],
  }) async {
    try {
      PdfMargins _margins = margins ?? PdfMargins.zero;
      final Map<String, dynamic> arguments = {
        'url': url,
        'content': content,
        'duration': duration,
        'autoClose': autoClose,
        'margins': _margins.toMap(),
        'format': format.toMap(),
      };

      ///
      if (args.isNotEmpty) {
        arguments.addAll(args);
      }
      WebcontentConverter.logger.info(arguments['margins']);
      WebcontentConverter.logger.info(arguments['format']);
      if (io.Platform.isWindows) {
        // flutter_inappwebview_windows (0.6.0) declares printCurrentPage on
        // its Dart controller but doesn't actually implement the native
        // method channel handler for it (MissingPluginException at
        // runtime), so Windows goes through this package's own native
        // WebView2 plugin (ShowPrintUI) instead, the same way contentToPDF/
        // contentToImage already do.
        WebcontentConverter.logger.info(
            "[printPreview] Windows: using native WebView2 print dialog");
        String? resolvedContent = content;
        if (resolvedContent == null && url != null) {
          final response = await Dio().get(url);
          resolvedContent = response.data.toString();
        }
        if (resolvedContent == null) {
          throw ArgumentError('printPreview requires either a url or content');
        }
        await _channel.invokeMethod('printPreview', {
          'content': resolvedContent,
          'duration': duration ?? 0,
        });
        return true;
      } else if (io.Platform.isMacOS) {
        // printCurrentPage IS officially implemented on macOS
        // (WKWebView.printOperation on 11.0+), so flutter_inappwebview
        // works fine here.
        WebcontentConverter.logger
            .info("[printPreview] macOS: using flutter_inappwebview");
        await _printPreviewViaInAppWebView(
          url: url,
          content: content,
          margins: _margins,
          format: format,
          duration: duration,
          autoClose: autoClose,
        );
        return true;
      } else {
        //mobile method
        WebcontentConverter.logger.info("Mobile support");
        await _channel.invokeMethod('printPreview', arguments);
        return true;
      }
    } on Exception catch (e, stackTrace) {
      WebcontentConverter.logger.error("[method:printPreview]: $e");
      WebcontentConverter.logger.error("$stackTrace");
      rethrow;
    }
  }

  static Future<void> _printPreviewViaInAppWebView({
    String? url,
    String? content,
    required PdfMargins margins,
    required PaperFormat format,
    double? duration,
    bool autoClose = true,
  }) async {
    if (url == null && content == null) {
      throw ArgumentError('printPreview requires either a url or content');
    }

    final marginCss = _buildMarginCss(margins);
    final loadCompleter = Completer<void>();

    final headlessWebView = iaw.HeadlessInAppWebView(
      initialSize: _buildInAppWebViewSize(format),
      initialUrlRequest:
          url != null ? iaw.URLRequest(url: iaw.WebUri(url)) : null,
      initialData: content != null
          ? iaw.InAppWebViewInitialData(
              data: '<style>$marginCss</style>\n$content')
          : null,
      onLoadStop: (controller, loadedUrl) async {
        if (!loadCompleter.isCompleted) loadCompleter.complete();
      },
      onReceivedError: (controller, request, error) {
        if (!loadCompleter.isCompleted) {
          loadCompleter.completeError(
            Exception('[printPreview] load error: ${error.description}'),
          );
        }
      },
    );

    try {
      await headlessWebView.run();
      await loadCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
            '[printPreview] page load timed out after 30s'),
      );

      final controller = headlessWebView.webViewController!;
      // Content already carries the margin CSS in its initial markup; a
      // navigated-to url doesn't, so it's injected after load instead.
      if (url != null) {
        await controller.injectCSSCode(source: marginCss);
      }
      if (duration != null && duration > 0) {
        await Future.delayed(Duration(milliseconds: duration.toInt()));
      }
      await controller.printCurrentPage();
    } finally {
      if (autoClose) {
        await headlessWebView.dispose();
      }
    }
  }
}

String _buildMarginCss(PdfMargins margins) {
  return '@page { margin: ${margins.top}in ${margins.right}in '
      '${margins.bottom}in ${margins.left}in; }';
}

Size _buildInAppWebViewSize(PaperFormat format) {
  return Size(format.width * 96, format.height * 96);
}

// Test-only exports — top-level functions wrapping private helpers for unit testing.
String buildMarginCssForTest(PdfMargins m) => _buildMarginCss(m);
Size buildInAppWebViewSizeForTest(PaperFormat f) => _buildInAppWebViewSize(f);
