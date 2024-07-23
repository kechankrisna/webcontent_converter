import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:easy_logger/easy_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:puppeteer/plugin.dart';
import 'package:puppeteer/puppeteer.dart' as pp;

import '../../demo.dart';
import '../../page.dart';
import '../../webview_helper.dart';

/// instance of window browser
pp.Browser? windowBrower;
Uint8List preloadBytes = Uint8List.fromList([]);

/// [WebcontentConverter] will convert html, html file, web uri, into raw bytes image or pdf file
class WebcontentConverter {
  static const MethodChannel _channel = MethodChannel('webcontent_converter');

  static Future<String?> get platformVersion async {
    final version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<void> ensureInitialized({
    String? executablePath,
    String? content,
  }) async {
    if (windowBrower == null || windowBrower?.isConnected != true) {
      await WebcontentConverter.initWebcontentConverter(
        executablePath: executablePath,
        content: content,
      );
    }
  }

  static Future<void> initWebcontentConverter({
    String? executablePath,
    String? content,
  }) async {
    if (io.Platform.isMacOS || io.Platform.isLinux || io.Platform.isWindows) {
      if (WebViewHelper.isChromeAvailable) {
        windowBrower ??= await pp.puppeteer.launch(
          executablePath: executablePath ?? WebViewHelper.executablePath(),
        );
      }
    } else if (io.Platform.isAndroid || io.Platform.isIOS) {
      preloadBytes =
          await contentToImage(content: content ?? Demo.getReceiptContent());
    }

    WebcontentConverter.logger.debug('webcontent converter initialized');
  }

  static Future<void> deinitWebcontentConverter({
    bool isClosePage = true,
    bool isCloseBrower = true,
  }) async {
    WebcontentConverter.logger
        .debug('webcontent converter deinitWebcontentConverter');
    if (isCloseBrower) {
      await windowBrower?.close();
    }
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
  }) async {
    final arguments = <String, dynamic>{
      'content': content,
      'duration': duration,
      'scale': scale,
    };
    var results = Uint8List.fromList([]);

    try {
      if (io.Platform.isMacOS || io.Platform.isLinux || io.Platform.isWindows) {
        if (WebViewHelper.isChromeAvailable) {
          pp.Page? windowBrowserPage;
          try {
            WebcontentConverter.logger.info('Desktop support');

            /// if window browser is null
            if (windowBrower == null || windowBrower?.isConnected != true) {
              windowBrower = await pp.puppeteer.launch(
                headless: true,
                executablePath:
                    executablePath ?? WebViewHelper.executablePath(),
              );
            }

            /// if window browser page is null
            windowBrowserPage = await windowBrower!.newPage();
            await windowBrowserPage.setContent(content, wait: pp.Until.load);
            await windowBrowserPage
                .setViewport(pp.DeviceViewport(deviceScaleFactor: scale));
            await windowBrowserPage.emulateMediaType(pp.MediaType.print);
            final offsetHeight =
                await windowBrowserPage.evaluate('document.body.offsetHeight');
            final offsetWidth =
                await windowBrowserPage.evaluate('document.body.offsetWidth');
            results = await windowBrowserPage.screenshot(
              format: pp.ScreenshotFormat.png,
              clip: pp.Rectangle.fromPoints(
                const pp.Point(0, 0),
                pp.Point(offsetWidth, offsetHeight),
              ),
              fullPage: false,
              omitBackground: true,
            );
          } finally {
            await windowBrowserPage!.close();
            windowBrowserPage = null;
          }
        }
      } else {
        /// mobile method
        WebcontentConverter.logger.info('Mobile support');
        results = await _channel.invokeMethod('contentToImage', arguments);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:contentToImage]: $e');
      throw Exception('Error: $e');
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
    required String savedPath,
    required PaperFormat format,
    double duration = 2000,
    PdfMargins? margins,
    String? executablePath,
  }) async {
    final margins0 = margins ?? PdfMargins.zero;
    final arguments = <String, dynamic>{
      'content': content,
      'duration': duration,
      'savedPath': savedPath,
      'margins': margins0.toMap(),
      'format': format.toMap(),
    };
    WebcontentConverter.logger.info(arguments['savedPath']);
    WebcontentConverter.logger.info(arguments['margins']);
    WebcontentConverter.logger.info(arguments['format']);
    String? result;
    try {
      if ((io.Platform.isMacOS ||
              io.Platform.isLinux ||
              io.Platform.isWindows) &&
          WebViewHelper.isChromeAvailable) {
        pp.Page? windowBrowserPage;
        try {
          WebcontentConverter.logger.info('Desktop support');

          /// if window browser is null
          windowBrower ??= await pp.puppeteer.launch(
            headless: true,
            executablePath: executablePath ?? WebViewHelper.executablePath(),
          );

          /// if window browser page is null
          windowBrowserPage = await windowBrower!.newPage();

          await windowBrowserPage
              .setViewport(const pp.DeviceViewport(width: 800, height: 1000));

          /// await windowBrowserPage.emulateMediaType(pp.MediaType.print);
          /// await windowBrowserPage.emulate(pp.puppeteer.devices.laptopWithMDPIScreen);
          ///
          await windowBrowserPage.setContent(
            content,
            wait: pp.Until.all([
              pp.Until.load,
              pp.Until.domContentLoaded,
              pp.Until.networkAlmostIdle,
              pp.Until.networkIdle,
            ]),
          );
          await windowBrowserPage.pdf(
            format: pp.PaperFormat.inches(
              width: format.width,
              height: format.height,
            ),
            margins: pp.PdfMargins.inches(
              top: margins0.top,
              bottom: margins0.bottom,
              left: margins0.left,
              right: margins0.right,
            ),
            printBackground: true,
            output: io.File(savedPath).openWrite(),
          );

          result = savedPath;
        } finally {
          await windowBrowserPage!.close();
          windowBrowserPage = null;
        }
      } else {
        //mobile method
        WebcontentConverter.logger.info('Mobile support');
        result = await _channel.invokeMethod('contentToPDF', arguments);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:contentToPDF]: $e');
      throw Exception('Error: $e');
    }

    return result;
  }

  /// [WevView]
  static Widget embedWebView({
    String? url,
    String? content,
    double? width,
    double? height,
  }) =>
      Builder(
        builder: (context) {
          const viewType = 'webview-view-type';
          // Pass parameters to the platform side.
          final creationParams = <String, dynamic>{};
          final width0 = width ?? 1;
          final height0 = height ?? 1;
          creationParams['width'] = width0;
          creationParams['height'] = height0;
          creationParams['content'] = content;
          creationParams['url'] = url;
          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
              return SafeArea(
                child: SizedBox(
                  width: width0,
                  height: height,
                  child: PlatformViewLink(
                    viewType: viewType,
                    surfaceFactory: (context, controller) => AndroidViewSurface(
                      controller: controller as AndroidViewController,
                      gestureRecognizers: const <Factory<
                          OneSequenceGestureRecognizer>>{},
                      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                    ),
                    onCreatePlatformView: (params) =>
                        PlatformViewsService.initSurfaceAndroidView(
                      id: params.id,
                      viewType: viewType,
                      layoutDirection: TextDirection.ltr,
                      creationParams: creationParams,
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                          ..addOnPlatformViewCreatedListener(
                            params.onPlatformViewCreated,
                          )
                          ..create(),
                  ),
                ),
              );
            case TargetPlatform.iOS:
              return SafeArea(
                child: SizedBox(
                  width: width0,
                  height: width0,
                  child: UiKitView(
                    viewType: viewType,
                    layoutDirection: TextDirection.ltr,
                    creationParams: creationParams,
                    creationParamsCodec: const StandardMessageCodec(),
                  ),
                ),
              );
            default:
              throw UnsupportedError('Unsupported platform view');
          }
        },
      );

  static Future<bool> printPreview({
    String? url,
    String? content,
    bool autoClose = true,
    double? duration,
  }) async {
    try {
      final arguments = <String, dynamic>{
        'url': url,
        'content': content,
        'duration': duration,
        'autoClose': autoClose,
      };
      if ((io.Platform.isMacOS ||
              io.Platform.isLinux ||
              io.Platform.isWindows) &&
          WebViewHelper.isChromeAvailable) {
        final browser = await pp.puppeteer.launch(
          executablePath: WebViewHelper.executablePath(),
          headless: false,
          devTools: false,
          noSandboxFlag: false,
          args: [
            '--no-default-browser-check',
            // "-disable-print-preview",
          ],
          defaultViewport: LaunchOptions.viewportNotSpecified,
          ignoreDefaultArgs: ['--enable-automation'],
        );
        final page = (await browser.pages).first;
        await page
            .setViewport(const pp.DeviceViewport(width: 800, height: 1000));

        /// await page.emulateMediaType(pp.MediaType.print);
        /// await page.emulate(pp.puppeteer.devices.laptopWithMDPIScreen);
        if (url != null) {
          await page.goto(
            url,
            wait: pp.Until.all([
              pp.Until.load,
              pp.Until.domContentLoaded,
              pp.Until.networkAlmostIdle,
              pp.Until.networkIdle,
            ]),
          );
        }

        if (content != null) {
          await page.setContent(
            content,
            wait: pp.Until.all([
              pp.Until.load,
              pp.Until.domContentLoaded,
              pp.Until.networkAlmostIdle,
              pp.Until.networkIdle,
            ]),
          );
        }
        if (duration != null) {
          await Future.delayed(Duration(milliseconds: duration.toInt()));
        }

        if (browser.isConnected && !page.isClosed) {
          try {
            await page.evaluate('''window.print()''');
            if (autoClose) {
              await page.close();
            }
          } on Exception catch (e) {
            WebcontentConverter.logger.error('[method:printPreview]: $e');
          }
        }
        await page.onClose.then((value) {
          browser.close();
        });
        return Future.value(true);
      } else {
        //mobile method
        WebcontentConverter.logger.info('Mobile support');
        await _channel.invokeMethod('printPreview', arguments);
        return Future.value(true);
      }
    } on Exception catch (e) {
      WebcontentConverter.logger.error('[method:printPreview]: $e');
      return Future.value(false);
    }
  }
}
