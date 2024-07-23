import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webcontent_converter/logger.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:window_manager/window_manager.dart';
import 'route.dart';

void main() async {
  /// [make widget built before other configurations]
  WidgetsFlutterBinding.ensureInitialized();

  if (WebViewHelper.isDesktop) {
    await windowManager.ensureInitialized();

    /// ensure brower is initialized
    final executablePath =
        await ChromeDesktopDirectoryHelper.saveChromeFromAssetToApp();
    WebViewHelper.customBrowserPath = [executablePath];
    println('executablePath $executablePath');
    await WebcontentConverter.ensureInitialized(executablePath: executablePath);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

// ignore: prefer_mixin
class MyAppState extends State<MyApp> with WindowListener {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'webcontent converter',
        initialRoute: '/',
        routes: routes,
        onGenerateRoute: onGenerateRoute,
      );

  @override
  void initState() {
    if (WebViewHelper.isDesktop) {
      windowManager.addListener(this);
    }
    super.initState();
  }

  @override
  Future<void> onWindowClose() async {
    log('onWindowClose');

    /// auto close browser
    if (WebViewHelper.isDesktop && windowBrower != null) {
      await WebcontentConverter.deinitWebcontentConverter();
    }
    super.onWindowClose();
  }

  @override
  void dispose() {
    if (WebViewHelper.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
