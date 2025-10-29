import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:window_manager/window_manager.dart';
import 'route.dart';

void main() async {
  /// [make widget built before other configurations]
  WidgetsFlutterBinding.ensureInitialized();

  if (WebViewHelper.isDesktop) {
    await windowManager.ensureInitialized();

    /// ensure brower is initialized
    final started = DateTime.now();
    WebcontentConverter.logger.info("${started.toIso8601String()} Initializing webcontent converter...");
    var executablePath =
        await ChromeDesktopDirectoryHelper.ensureChromeExecutable();
    WebViewHelper.customBrowserPath = [executablePath];
    final finised = DateTime.now();
    WebcontentConverter.logger.info("${finised.toIso8601String()} executablePath $executablePath");
    WebcontentConverter.logger.info(
        "Webcontent converter initialized in ${finised.difference(started).inMilliseconds} ms");
    await WebcontentConverter.ensureInitialized(executablePath: executablePath);
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "webcontent converter",
      initialRoute: "/",
      routes: routes,
      onGenerateRoute: onGenerateRoute,
    );
  }

  @override
  void initState() {
    if (WebViewHelper.isDesktop) {
      windowManager.addListener(this);
    }
    super.initState();
  }

  @override
  void onWindowClose() {
    log("onWindowClose");

    /// auto close browser
    if (WebViewHelper.isDesktop && windowBrower != null) {
      WebcontentConverter.deinitWebcontentConverter();
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
