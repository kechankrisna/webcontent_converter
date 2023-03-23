import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

class WebViewScreen extends StatefulWidget {
  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("WebView Screen"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 400,
              child: LayoutBuilder(builder: (ctn, constains) {
                return WebcontentConverter.embedWebView(
                  width: constains.maxWidth,
                  height: constains.maxHeight,

                  content: Demo.getInvoiceContent(),

                  /// url: "https://example.com/",
                );
              }),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.replay_outlined),
        onPressed: _onPressed,
      ),
    );
  }

  _onPressed() {}
}
