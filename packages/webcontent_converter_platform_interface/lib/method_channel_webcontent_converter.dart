import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:webcontent_converter_interface/src/pages.dart';

import 'webcontent_converter_platform_interface.dart';

const MethodChannel _channel =
    MethodChannel('plugins.mylekha.app/webcontent_converter');

class MethodChannelWebcontentConverter extends WebcontentConverterPlatform {
  @override
  Future<void> ensureInitialized({String? executablePath, String? content}) {
    return _channel.invokeMethod(
      'ensureInitialized',
      <String, Object?>{'executablePath': executablePath, 'content': content},
    );
  }

  @override
  Future<Uint8List> filePathToImage({
    required String path,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) {
    return _channel.invokeMethod<Uint8List>(
      'filePathToImage',
      <String, Object?>{
        'path': path,
        'duration': duration,
        'executablePath': executablePath,
        'autoClosePage': autoClosePage,
        'scale': scale,
      },
    ).then((Uint8List? v) => v == null ? Uint8List.fromList([]) : v);
  }

  @override
  Future<Uint8List> webUriToImage({
    required String uri,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) {
    return _channel.invokeMethod<Uint8List>(
      'webUriToImage',
      <String, Object?>{
        'uri': uri,
        'duration': duration,
        'executablePath': executablePath,
        'autoClosePage': autoClosePage,
        'scale': scale,
      },
    ).then((Uint8List? v) => v == null ? Uint8List.fromList([]) : v);
  }

  @override
  Future<Uint8List> contentToImage(
      {required String content,
      double duration = 2000,
      String? executablePath,
      bool autoClosePage = true,
      int scale = 3}) {
    return _channel.invokeMethod<Uint8List>(
      'contentToImage',
      <String, Object?>{
        'content': content,
        'duration': duration,
        'executablePath': executablePath,
        'autoClosePage': autoClosePage,
        'scale': scale,
      },
    ).then((Uint8List? v) => v == null ? Uint8List.fromList([]) : v);
  }

  @override
  Future<String?> filePathToPdf({
    required String path,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) {
    return _channel.invokeMethod<String?>(
      'filePathToPdf',
      <String, Object?>{
        'path': path,
        'duration': duration,
        'savedPath': savedPath,
        'margins': margins?.toMap(),
        'format': format.toMap(),
        'executablePath': executablePath,
      },
    ).then((String? v) => v);
  }

  @override
  Future<String?> webUriToPdf({
    required String uri,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) {
    return _channel.invokeMethod<String?>(
      'webUriToPdf',
      <String, Object?>{
        'uri': uri,
        'duration': duration,
        'savedPath': savedPath,
        'margins': margins?.toMap(),
        'format': format.toMap(),
        'executablePath': executablePath,
      },
    ).then((String? v) => v);
  }

  @override
  Future<String?> contentToPDF({
    required String content,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) {
    return _channel.invokeMethod<String?>(
      'contentToPDF',
      <String, Object?>{
        'content': content,
        'duration': duration,
        'savedPath': savedPath,
        'margins': margins?.toMap(),
        'format': format.toMap(),
        'executablePath': executablePath,
      },
    ).then((String? v) => v);
  }

  @override
  Future<bool> printPreview({
    String? url,
    String? content,
    bool autoClose = true,
    double? duration,
  }) {
    return _channel.invokeMethod<bool>(
      'printPreview',
      <String, Object?>{
        'url': url,
        'content': content,
        'duration': duration,
        'autoClose': autoClose,
      },
    ).then((v) => v == true);
  }

  @override
  Widget embedWebView(
      {String? url, String? content, double? width, double? height}) {
    return super
        .embedWebView(url: url, content: content, width: width, height: height);
  }
}
