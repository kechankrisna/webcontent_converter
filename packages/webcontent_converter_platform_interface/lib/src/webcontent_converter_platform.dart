import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import './pages.dart';
import '../method_channel_webcontent_converter.dart';

abstract class WebcontentConverterPlatform extends PlatformInterface {
  WebcontentConverterPlatform() : super(token: _token);

  static WebcontentConverterPlatform _instance =
      MethodChannelWebcontentConverter();

  static final Object _token = Object();

  static WebcontentConverterPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [WebcontentConverterPlatform] when they register themselves.
  static set instance(WebcontentConverterPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// [ensureInitialized]
  Future<void> ensureInitialized({
    String? executablePath,
    String? content,
  }) {
    throw UnimplementedError('ensureInitialized() has not been implemented.');
  }

  /// [filePathToImage]
  Future<Uint8List> filePathToImage({
    required String path,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    throw UnimplementedError('filePathToImage() has not been implemented.');
  }

  /// [webUriToImage]
  Future<Uint8List> webUriToImage({
    required String uri,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    throw UnimplementedError('webUriToImage() has not been implemented.');
  }

  /// [contentToImage]
  Future<Uint8List> contentToImage({
    required String content,
    double duration = 2000,
    String? executablePath,
    bool autoClosePage = true,
    int scale = 3,
  }) async {
    throw UnimplementedError('contentToImage() has not been implemented.');
  }

  /// [filePathToPdf]
  Future<String?> filePathToPdf({
    required String path,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) async {
    throw UnimplementedError('filePathToPdf() has not been implemented.');
  }

  /// [webUriToPdf]
  Future<String?> webUriToPdf({
    required String uri,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) async {
    throw UnimplementedError('webUriToPdf() has not been implemented.');
  }

  /// [contentToPDF]
  Future<String?> contentToPDF({
    required String content,
    double duration = 2000,
    required String savedPath,
    PdfMargins? margins,
    PaperFormat format = PaperFormat.a4,
    String? executablePath,
  }) async {
    throw UnimplementedError('contentToPDF() has not been implemented.');
  }

  /// [WevView]
  Widget embedWebView(
      {String? url, String? content, double? width, double? height}) {
    throw UnimplementedError('embedWebView() has not been implemented.');
  }

  /// [printPreview]
  Future<bool> printPreview(
      {String? url, String? content, bool autoClose = true, double? duration}) {
    throw UnimplementedError('printPreview() has not been implemented.');
  }
}
