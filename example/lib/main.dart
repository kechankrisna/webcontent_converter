import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:window_manager/window_manager.dart';
import 'route.dart';

void main() async {
  /// [make widget built before other configurations]
  WidgetsFlutterBinding.ensureInitialized();

  /// ensure brower is initialized
  await WebcontentConverter.ensureInitialized();

  if (WebViewHelper.isDesktop) {
    await windowManager.ensureInitialized();
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
