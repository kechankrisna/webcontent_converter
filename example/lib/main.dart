import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'route.dart';

void main() {
  /// [make widget built before other configurations]
  WidgetsFlutterBinding.ensureInitialized();

  /// ensure brower is initialized
  WebcontentConverter.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "webcontent converter",
      initialRoute: "/",
      routes: routes,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
