import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("HOME SCREEN"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text("Image converter"),
            leading: Icon(Icons.image),
          ),
          ListTile(
            title: Text("content to image"),
            onTap: () =>
                Navigator.of(context).pushNamed("/content_image_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("weburi to image"),
            onTap: () =>
                Navigator.of(context).pushNamed("/weburi_image_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("File path to image"),
            onTap: () => Navigator.of(context).pushNamed("/path_image_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("Pdf converter"),
            leading: Icon(Icons.picture_as_pdf),
          ),
          ListTile(
            title: Text("content to pdf"),
            onTap: () => Navigator.of(context).pushNamed("/content_pdf_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("weburi to pdf"),
            onTap: () => Navigator.of(context).pushNamed("/weburi_pdf_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("file path to pdf"),
            onTap: () => Navigator.of(context).pushNamed("/path_pdf_screen"),
            trailing: Icon(Icons.arrow_right),
          ),
          ListTile(
            title: Text("bluetooth device screen"),
            onTap: () =>
                Navigator.of(context).pushNamed("/bluetooth_device_screen"),
            trailing: Icon(Icons.bluetooth_connected),
          ),
          ListTile(
            title: Text("webview screen"),
            onTap: () => Navigator.of(context).pushNamed("/webview_screen"),
            trailing: Icon(Icons.open_in_browser_outlined),
          ),
        ],
      ),
    );
  }
}
