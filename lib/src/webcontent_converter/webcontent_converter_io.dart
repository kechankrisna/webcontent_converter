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

  /// ## `WebcontentConverter.isWebviewAvailable`
  /// `Checks whether this platform's native webview is actually usable`
  /// `right now: WebView2 Runtime on Windows, WKWebView on macOS/iOS,`
  /// `android.webkit.WebView on Android.`
  static Future<bool> isWebviewAvailable() async {
    final bool? available =
        await _channel.invokeMethod('isWebviewAvailable');
    return available ?? false;
  }

  static Future<void> ensureInitialized({
    String? content,
  }) async {
    if (preloadBytes.isEmpty) {
      await WebcontentConverter.initWebcontentConverter(content: content);
    }
  }

  static Future<void> initWebcontentConverter({
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
    int scale = 3,
    Map<String, dynamic> args = const {},
    int? maximumContentSize,
    bool enableLogger = true,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      String content = await rootBundle.loadString(path);

      result = await contentToImage(
        content: content,
        duration: duration,
        scale: scale,
        args: args,
        maximumContentSize: maximumContentSize,
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
    int scale = 3,
    Map<String, dynamic> args = const {},
    int? maximumContentSize,
    bool enableLogger = true,
  }) async {
    Uint8List result = Uint8List.fromList([]);
    try {
      var response = await Dio().get(uri);
      final String content = response.data.toString();
      result = await contentToImage(
        content: content,
        duration: duration,
        scale: scale,
        args: args,
        maximumContentSize: maximumContentSize,
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
    int scale = 3,
    Map<String, dynamic> args = const {},
    // Overrides the native side's default max content size (in MB) for
    // this call only -- see CONTENT_TOO_LARGE handling in the Windows/
    // Android plugins (`maximumContentSize` in their arguments map).
    int? maximumContentSize,
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
    if (maximumContentSize != null) {
      arguments['maximumContentSize'] = maximumContentSize;
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
    Map<String, dynamic> args = const {},
    int? maximumContentSize,
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
        args: args,
        maximumContentSize: maximumContentSize,
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
    Map<String, dynamic> args = const {},
    int? maximumContentSize,
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
        args: args,
        maximumContentSize: maximumContentSize,
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
    Map<String, dynamic> args = const {},
    // Overrides the native side's default max content size (in MB) for
    // this call only -- see CONTENT_TOO_LARGE handling in the Windows/
    // Android plugins (`maximumContentSize` in their arguments map).
    int? maximumContentSize,
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
    if (maximumContentSize != null) {
      arguments['maximumContentSize'] = maximumContentSize;
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
    Map<String, dynamic> args = const {},
    int? maximumContentSize,
    bool enableLogger = true,
  }) async {
    PdfMargins _margins = margins ?? PdfMargins.zero;
    final stopwatch = Stopwatch()..start();
    if (enableLogger) {
      WebcontentConverter.logger.info(
          "[contentToPDFImage] starting: content=${content.length} chars, margins=${_margins.toMap()}, format=${format.toMap()}");
    }
    Uint8List? result;
    try {
      // Uses this package's own native contentToPDF (e.g. WebView2
      // PrintToPdf on Windows) rather than flutter_inappwebview's separate
      // HeadlessInAppWebView wrapper (a second, independent WebView2
      // integration) or the Puppeteer fallback that used to sit behind it:
      // contentToPDF's native implementation on every platform is the one
      // hardened this package's persistent-session, retry, and
      // request-queueing work targets, so routing through it here instead
      // is both simpler and more reliable. There is no dedicated native
      // "contentToPDFImage" handler on any platform, so this generates to a
      // temp file via contentToPDF and reads it back as bytes.
      if (enableLogger) {
        WebcontentConverter.logger
            .info("[contentToPDFImage] using native contentToPDF");
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
          args: args,
          maximumContentSize: maximumContentSize,
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
    Map<String, dynamic> args = const {},
    // Overrides the native side's default max content size (in MB) for
    // this call only -- see CONTENT_TOO_LARGE handling in the Windows/
    // Android plugins (`maximumContentSize` in their arguments map).
    int? maximumContentSize,
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
      if (maximumContentSize != null) {
        arguments['maximumContentSize'] = maximumContentSize;
      }
      WebcontentConverter.logger.info(arguments['margins']);
      WebcontentConverter.logger.info(arguments['format']);

      // Preview window size (native popup window on Windows/macOS, ignored
      // elsewhere); overridable via args: {'width': ..., 'height': ...}.
      // 0 means "not specified" -- the native side then sizes the window
      // to fit the screen instead of using a flat fallback size.
      final double windowWidth =
          (arguments['width'] as num?)?.toDouble() ?? 0.0;
      final double windowHeight =
          (arguments['height'] as num?)?.toDouble() ?? 0.0;

      if (io.Platform.isWindows || io.Platform.isMacOS) {
        WebcontentConverter.logger
            .info("[printPreview] Windows/macOS: using native WebView2/WKWebView print dialog");
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
          'margins': _margins.toMap(),
          'format': format.toMap(),
          'width': windowWidth,
          'height': windowHeight,
          if (maximumContentSize != null)
            'maximumContentSize': maximumContentSize,
        });
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

}
