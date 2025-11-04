import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'screens/content_image_screen.dart';
import 'screens/content_pdf_screen.dart';
import 'screens/content_pdf_image_screen.dart';
import 'screens/error_screen.dart';

import 'screens/filepath_image_screen.dart';
import 'screens/filepath_pdf_screen.dart';
import 'screens/home_screen.dart';
import 'screens/webcontent_screen.dart';
import 'screens/weburi_image_screen.dart';
import 'screens/weburi_pdf_screen.dart';
import 'screens/webview_screen.dart';

Map<String, Widget Function(BuildContext)> routes = {
  '/': (_) => HomeScreen(),
};

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = settings.name;
  final arguments = settings.arguments;
  WebcontentConverter.logger.info("name: $name || arguments: $arguments");

  switch (name) {

    /// `Image converter`
    case "/content_image_screen":
      return MaterialPageRoute(
        builder: (context) => ContentToImageScreen(),
        settings: settings,
      );
    case "/weburi_image_screen":
      return MaterialPageRoute(
        builder: (context) => WebUriToImageScreen(),
        settings: settings,
      );
    case "/path_image_screen":
      return MaterialPageRoute(
        builder: (context) => FilePathToImageScreen(),
        settings: settings,
      );

    /// `PDF converter`
    case "/content_pdf_screen":
      return MaterialPageRoute(
        builder: (context) => ContentToPDFScreen(),
        settings: settings,
      );
      
    /// `PDF converter`
    case "/content_pdf_image_screen":
      return MaterialPageRoute(
        builder: (context) => ContentToPDFImageScreen(),
        settings: settings,
      );

    case "/weburi_pdf_screen":
      return MaterialPageRoute(
        builder: (context) => WebUriToPDFScreen(),
        settings: settings,
      );

    case "/path_pdf_screen":
      return MaterialPageRoute(
        builder: (context) => FilePathToPDFScreen(),
        settings: settings,
      );
    case "/webview_screen":
      return MaterialPageRoute(
        builder: (context) => WebViewScreen(),
        settings: settings,
      );
    case "/webcontent_screen":
      return MaterialPageRoute(
        builder: (context) => WebcontentScreen(),
        settings: settings,
      );
    default:
      return MaterialPageRoute(
        builder: (context) => ErrorScreen(
          name: name!,
          arguments: arguments,
        ),
        settings: settings,
      );
  }
}
